-- ============================================================================
-- Migration: 20260930000003_audit_and_triggers.sql
-- Description: Audit logging triggers, profile sync, and Transfer Approval Transaction
-- ============================================================================

-- 1. GENERIC AUDIT LOG TRIGGER FUNCTION
CREATE OR REPLACE FUNCTION process_audit_log()
RETURNS TRIGGER AS $$
DECLARE
  v_actor_id UUID;
  v_entity_id UUID;
  v_payload JSONB;
BEGIN
  v_actor_id := auth.uid();

  IF TG_OP = 'DELETE' THEN
    v_entity_id := OLD.id;
    v_payload := to_jsonb(OLD);
  ELSE
    v_entity_id := NEW.id;
    v_payload := to_jsonb(NEW);
  END IF;

  INSERT INTO audit_log (actor_id, action, entity, entity_id, payload)
  VALUES (v_actor_id, TG_OP, TG_TABLE_NAME, v_entity_id, v_payload);

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  ELSE
    RETURN NEW;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Attach Audit Log Triggers to key tables
DROP TRIGGER IF EXISTS audit_districts_trigger ON districts;
CREATE TRIGGER audit_districts_trigger
AFTER INSERT OR UPDATE OR DELETE ON districts
FOR EACH ROW EXECUTE FUNCTION process_audit_log();

DROP TRIGGER IF EXISTS audit_projects_trigger ON projects;
CREATE TRIGGER audit_projects_trigger
AFTER INSERT OR UPDATE OR DELETE ON projects
FOR EACH ROW EXECUTE FUNCTION process_audit_log();

DROP TRIGGER IF EXISTS audit_project_updates_trigger ON project_updates;
CREATE TRIGGER audit_project_updates_trigger
AFTER INSERT OR UPDATE OR DELETE ON project_updates
FOR EACH ROW EXECUTE FUNCTION process_audit_log();

DROP TRIGGER IF EXISTS audit_transfer_requests_trigger ON transfer_requests;
CREATE TRIGGER audit_transfer_requests_trigger
AFTER INSERT OR UPDATE OR DELETE ON transfer_requests
FOR EACH ROW EXECUTE FUNCTION process_audit_log();

DROP TRIGGER IF EXISTS audit_pastor_tenures_trigger ON pastor_tenures;
CREATE TRIGGER audit_pastor_tenures_trigger
AFTER INSERT OR UPDATE OR DELETE ON pastor_tenures
FOR EACH ROW EXECUTE FUNCTION process_audit_log();

DROP TRIGGER IF EXISTS audit_posts_trigger ON posts;
CREATE TRIGGER audit_posts_trigger
AFTER INSERT OR UPDATE OR DELETE ON posts
FOR EACH ROW EXECUTE FUNCTION process_audit_log();

DROP TRIGGER IF EXISTS audit_visits_trigger ON visits;
CREATE TRIGGER audit_visits_trigger
AFTER INSERT OR UPDATE OR DELETE ON visits
FOR EACH ROW EXECUTE FUNCTION process_audit_log();

-- ============================================================================
-- 2. NEW AUTH USER TO PROFILE SYNC TRIGGER
-- ============================================================================
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  v_role user_role := 'member';
  v_full_name TEXT;
  v_district_id UUID;
  v_assembly_id UUID;
  v_district_status district_status;
BEGIN
  v_full_name := COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email);
  
  -- If district_id is passed in metadata
  IF NEW.raw_user_meta_data->>'district_id' IS NOT NULL THEN
    v_district_id := (NEW.raw_user_meta_data->>'district_id')::UUID;
    
    -- Verify district is active before allowing member sign up
    SELECT status INTO v_district_status FROM districts WHERE id = v_district_id;
    IF v_district_status IS NULL OR v_district_status = 'inactive' THEN
      RAISE EXCEPTION 'Your district has not been approved yet. Please try to sign up again later, once your district is approved.';
    END IF;
  END IF;

  IF NEW.raw_user_meta_data->>'assembly_id' IS NOT NULL THEN
    v_assembly_id := (NEW.raw_user_meta_data->>'assembly_id')::UUID;
  END IF;

  IF NEW.raw_user_meta_data->>'role' IS NOT NULL THEN
    v_role := (NEW.raw_user_meta_data->>'role')::user_role;
  END IF;

  INSERT INTO public.profiles (
    id,
    full_name,
    email,
    role,
    status,
    district_id,
    assembly_id,
    data_consent_accepted
  )
  VALUES (
    NEW.id,
    v_full_name,
    NEW.email,
    v_role,
    'active',
    v_district_id,
    v_assembly_id,
    TRUE
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================================================
-- 3. ATOMIC TRANSFER APPROVAL TRANSACTION FUNCTION (Section 5.5)
-- ============================================================================
CREATE OR REPLACE FUNCTION approve_pastor_transfer(
  p_request_id UUID,
  p_decided_by UUID,
  p_note TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_request RECORD;
  v_pastor RECORD;
  v_tenure RECORD;
  v_start_year TEXT;
  v_end_year TEXT;
  v_archive_title TEXT;
  v_summary JSONB;
  v_archive_id UUID;
  v_project_count INT;
  v_event_count INT;
  v_thought_count INT;
  v_update_count INT;
BEGIN
  -- 1. Fetch Transfer Request
  SELECT * INTO v_request FROM transfer_requests WHERE id = p_request_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Transfer request not found with ID %', p_request_id;
  END IF;

  IF v_request.status != 'pending' THEN
    RAISE EXCEPTION 'Transfer request has already been processed.';
  END IF;

  -- 2. Fetch Pastor and Tenure
  SELECT * INTO v_pastor FROM profiles WHERE id = v_request.pastor_id;
  SELECT * INTO v_tenure FROM pastor_tenures WHERE id = v_request.tenure_id;

  v_start_year := TO_CHAR(v_tenure.start_date, 'YYYY');
  v_end_year := TO_CHAR(CURRENT_DATE, 'YYYY');
  v_archive_title := 'Pastor ' || v_pastor.full_name || ', ' || v_start_year || '-' || v_end_year;

  -- 3. Calculate Tenure Stats and Summary
  SELECT COUNT(*) INTO v_project_count FROM projects WHERE tenure_id = v_tenure.id AND type = 'project';
  SELECT COUNT(*) INTO v_event_count FROM projects WHERE tenure_id = v_tenure.id AND type = 'event';
  SELECT COUNT(*) INTO v_update_count FROM project_updates WHERE created_by = v_pastor.id;
  SELECT COUNT(*) INTO v_thought_count FROM posts WHERE tenure_id = v_tenure.id AND type = 'thought';

  v_summary := jsonb_build_object(
    'pastor_name', v_pastor.full_name,
    'pastor_email', v_pastor.email,
    'district_id', v_tenure.district_id,
    'start_date', v_tenure.start_date,
    'end_date', CURRENT_DATE,
    'total_projects', v_project_count,
    'total_events', v_event_count,
    'total_updates', v_update_count,
    'total_thoughts', v_thought_count,
    'projects_summary', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', p.id,
        'title', p.title,
        'type', p.type,
        'status', p.status,
        'progress_pct', p.progress_pct
      )), '[]'::jsonb)
      FROM projects p
      WHERE p.tenure_id = v_tenure.id
    ),
    'thoughts_summary', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', po.id,
        'title', po.title,
        'created_at', po.created_at
      )), '[]'::jsonb)
      FROM posts po
      WHERE po.tenure_id = v_tenure.id AND po.type = 'thought'
    )
  );

  -- 4. Update Pastor Tenure: set end_date and status archived
  UPDATE pastor_tenures
  SET end_date = CURRENT_DATE,
      status = 'archived',
      updated_at = NOW()
  WHERE id = v_tenure.id;

  -- 5. Insert Tenure Archive Row
  INSERT INTO tenure_archives (
    tenure_id,
    title,
    summary_json,
    pdf_url
  )
  VALUES (
    v_tenure.id,
    v_archive_title,
    v_summary,
    NULL
  )
  RETURNING id INTO v_archive_id;

  -- 6. Update Pastor Profile status to 'transferred'
  UPDATE profiles
  SET status = 'transferred',
      updated_at = NOW()
  WHERE id = v_pastor.id;

  -- 7. Update Transfer Request to 'approved'
  UPDATE transfer_requests
  SET status = 'approved',
      decided_by = p_decided_by,
      decided_at = NOW(),
      note = p_note
  WHERE id = p_request_id;

  -- 8. Log Audit Action
  INSERT INTO audit_log (actor_id, action, entity, entity_id, payload)
  VALUES (
    p_decided_by,
    'APPROVE_TRANSFER',
    'tenure_archives',
    v_archive_id,
    jsonb_build_object(
      'pastor_id', v_pastor.id,
      'tenure_id', v_tenure.id,
      'archive_title', v_archive_title
    )
  );

  -- 9. Insert Notification to the Pastor
  INSERT INTO notifications (user_id, title, body, payload)
  VALUES (
    v_pastor.id,
    'Transfer Request Approved',
    'Your transfer request has been approved. Your tenure archive "' || v_archive_title || '" is now safely preserved.',
    jsonb_build_object('archive_id', v_archive_id, 'type', 'transfer_decision')
  );

  RETURN v_archive_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
