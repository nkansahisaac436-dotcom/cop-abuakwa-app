import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cop_abuakwa_app/core/constants/app_colors.dart';
import 'package:cop_abuakwa_app/core/constants/app_dimensions.dart';
import 'package:cop_abuakwa_app/core/widgets/app_text_field.dart';
import 'package:cop_abuakwa_app/features/meetings/presentation/providers/meetings_provider.dart';

class MeetingsScreen extends ConsumerStatefulWidget {
  const MeetingsScreen({super.key});

  @override
  ConsumerState<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends ConsumerState<MeetingsScreen> {
  void _startInstantMeeting() {
    final titleController = TextEditingController(text: 'Abuakwa Pastoral Call');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Start Group Meeting', style: GoogleFonts.sourceSerif4(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A unique Jitsi Meet room link will be generated. Audio-only mode is enabled by default to save mobile data.',
              style: GoogleFonts.nunitoSans(fontSize: 13, color: AppColors.softGrey),
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Meeting Topic',
              controller: titleController,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy, foregroundColor: AppColors.white),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(meetingsListProvider.notifier).startInstantMeeting(titleController.text);
            },
            child: const Text('Start & Join Call'),
          ),
        ],
      ),
    );
  }

  void _scheduleMeeting() {
    final titleController = TextEditingController();
    DateTime scheduledDate = DateTime.now().add(const Duration(days: 1));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Schedule Meeting', style: GoogleFonts.sourceSerif4(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              label: 'Meeting Title',
              hintText: 'e.g. Prayer & Fasting Briefing',
              controller: titleController,
            ),
            const SizedBox(height: 12),
            Text(
              'Date: ${DateFormat("EEEE, MMM d, yyyy").format(scheduledDate)}',
              style: GoogleFonts.nunitoSans(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy, foregroundColor: AppColors.white),
            onPressed: () async {
              if (titleController.text.trim().isEmpty) return;
              Navigator.of(ctx).pop();
              await ref.read(meetingsListProvider.notifier).scheduleMeeting(titleController.text, scheduledDate);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Meeting scheduled successfully.')),
                );
              }
            },
            child: const Text('Schedule'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final meetingsAsync = ref.watch(meetingsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pastoral Group Meetings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick Action Buttons Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.navyGradient,
                borderRadius: AppDimensions.cardBorderRadius,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Virtual Ministry Calls',
                    style: GoogleFonts.sourceSerif4(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Meet with fellow district pastors and Area leadership via Jitsi Meet.',
                    style: GoogleFonts.nunitoSans(fontSize: 13, color: AppColors.lightGold),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: AppColors.navyDark,
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          ),
                          onPressed: _startInstantMeeting,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.video_call, size: 18),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Start Call',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.white,
                            side: const BorderSide(color: AppColors.white, width: 1.5),
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          ),
                          onPressed: _scheduleMeeting,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_month, size: 16),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Schedule',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Scheduled Pastoral Meetings',
              style: GoogleFonts.sourceSerif4(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 12),

            meetingsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (meetings) {
                if (meetings.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        'No upcoming group meetings scheduled.',
                        style: GoogleFonts.nunitoSans(color: AppColors.softGrey),
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    for (int index = 0; index < meetings.length; index++) ...[
                      if (index > 0) const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.navy.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.headset_mic_outlined, color: AppColors.navy, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    meetings[index].title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.sourceSerif4(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('EEEE, MMM d • h:mm a').format(meetings[index].scheduledAt),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.nunitoSans(
                                      fontSize: 12,
                                      color: AppColors.softGrey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.navy,
                                foregroundColor: AppColors.white,
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              ),
                              onPressed: () {
                                ref.read(meetingsRepositoryProvider).launchMeetingUrl(meetings[index].roomLink);
                              },
                              child: const Text('Join'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
