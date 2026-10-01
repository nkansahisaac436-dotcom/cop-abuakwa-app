import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../districts/domain/models/district_model.dart';
import '../../../districts/presentation/providers/districts_provider.dart';
import '../../../ministries/domain/models/ministry_model.dart';
import '../../../ministries/presentation/providers/ministries_provider.dart';
import '../../domain/models/invite_model.dart';
import '../../domain/models/profile_model.dart';
import '../providers/auth_provider.dart';

class InvitePastorScreen extends ConsumerStatefulWidget {
  const InvitePastorScreen({super.key});

  @override
  ConsumerState<InvitePastorScreen> createState() => _InvitePastorScreenState();
}

class _InvitePastorScreenState extends ConsumerState<InvitePastorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  UserRole _selectedRole = UserRole.pastor;
  DistrictModel? _selectedDistrict;
  MinistryModel? _selectedMinistry;

  bool _isLoading = false;
  InviteModel? _latestGeneratedInvite;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleGenerateInvite() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedRole == UserRole.pastor && _selectedDistrict == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a district for this pastor.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedRole == UserRole.ministryLeader && _selectedMinistry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a ministry for this leader.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final invite = await ref.read(invitesListProvider.notifier).createInvite(
            role: _selectedRole,
            targetName: _nameController.text.trim(),
            districtId: _selectedDistrict?.id,
            districtName: _selectedDistrict?.name,
            ministryId: _selectedMinistry?.id,
            ministryName: _selectedMinistry?.name,
          );

      setState(() {
        _latestGeneratedInvite = invite;
        _nameController.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invite code ${invite.code} generated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _shareViaWhatsApp(InviteModel invite) async {
    final message = Uri.encodeComponent(
      'Abuakwa Area Connect Invitation\n'
      'Hello ${invite.targetName},\n'
      'You have been invited as ${invite.roleDisplay}.\n'
      'Your single-use invite code is: ${invite.code}\n'
      'Download or open the Abuakwa Area Connect app and activate your account using this code.\n'
      'This code expires in 7 days.',
    );
    final url = Uri.parse('whatsapp://send?text=$message');
    final webUrl = Uri.parse('https://wa.me/?text=$message');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else if (await canLaunchUrl(webUrl)) {
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    } else {
      _copyInviteToClipboard(invite);
    }
  }

  void _shareViaSms(InviteModel invite) async {
    final message = Uri.encodeComponent(
      'Abuakwa Area Connect: Hello ${invite.targetName}, your invite code as ${invite.roleDisplay} is: ${invite.code} (Expires in 7 days).',
    );
    final url = Uri.parse('sms:?body=$message');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      _copyInviteToClipboard(invite);
    }
  }

  void _copyInviteToClipboard(InviteModel invite) {
    Clipboard.setData(ClipboardData(text: invite.code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Invite code "${invite.code}" copied to clipboard!'),
        backgroundColor: AppColors.navy,
      ),
    );
  }

  void _confirmCancelInvite(InviteModel invite) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Cancel Invitation?',
          style: GoogleFonts.sourceSerif4(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to cancel the invitation code ${invite.code} for ${invite.targetName}? This code will no longer be redeemable.',
          style: GoogleFonts.nunitoSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Keep Invite', style: GoogleFonts.nunitoSans(color: AppColors.softGrey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
              shape: const StadiumBorder(),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(invitesListProvider.notifier).cancelInvite(invite.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invitation cancelled.')),
                );
              }
            },
            child: const Text('Cancel Invite'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final districtsAsync = ref.watch(districtsListProvider);
    final ministriesAsync = ref.watch(ministriesListProvider);
    final invitesAsync = ref.watch(invitesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Area Head • Invites'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Generation Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: AppDimensions.cardBorderRadius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create New Official Invitation',
                      style: GoogleFonts.sourceSerif4(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Generate a single-use code for incoming pastors and ministry leaders.',
                      style: GoogleFonts.nunitoSans(
                        fontSize: 13,
                        color: AppColors.softGrey,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Role Picker (Pastor or Leader)
                    Text(
                      'Select Role',
                      style: GoogleFonts.nunitoSans(
                        fontSize: AppDimensions.fontSizeLabel,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            avatar: const Icon(Icons.account_circle_outlined, size: 18),
                            label: const Text('District Pastor'),
                            selected: _selectedRole == UserRole.pastor,
                            selectedColor: AppColors.navy,
                            labelStyle: GoogleFonts.nunitoSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: _selectedRole == UserRole.pastor ? AppColors.white : AppColors.text,
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedRole = UserRole.pastor;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            avatar: const Icon(Icons.groups_outlined, size: 18),
                            label: const Text('Ministry Leader'),
                            selected: _selectedRole == UserRole.ministryLeader,
                            selectedColor: AppColors.navy,
                            labelStyle: GoogleFonts.nunitoSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: _selectedRole == UserRole.ministryLeader ? AppColors.white : AppColors.text,
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedRole = UserRole.ministryLeader;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Target Name
                    AppTextField(
                      label: 'Person\'s Full Name',
                      hintText: _selectedRole == UserRole.pastor ? 'e.g. Pastor Samuel Darko' : 'e.g. Sister Grace Osei',
                      controller: _nameController,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter full name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // District or Ministry Picker
                    if (_selectedRole == UserRole.pastor) ...[
                      Text(
                        'Assigned District',
                        style: GoogleFonts.nunitoSans(
                          fontSize: AppDimensions.fontSizeLabel,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      districtsAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, _) => Text('Error: $err'),
                        data: (districts) {
                          return DropdownButtonFormField<DistrictModel>(
                            initialValue: _selectedDistrict,
                            hint: const Text('Select Abuakwa Area District'),
                            items: districts.map((d) {
                              return DropdownMenuItem(
                                value: d,
                                child: Text('${d.name} (${d.isActive ? "Active" : "Inactive"})'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedDistrict = val;
                              });
                            },
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          );
                        },
                      ),
                    ] else ...[
                      Text(
                        'Assigned Ministry',
                        style: GoogleFonts.nunitoSans(
                          fontSize: AppDimensions.fontSizeLabel,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ministriesAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, _) => Text('Error: $err'),
                        data: (ministries) {
                          return DropdownButtonFormField<MinistryModel>(
                            initialValue: _selectedMinistry,
                            hint: const Text('Select Ministry'),
                            items: ministries.map((m) {
                              return DropdownMenuItem(
                                value: m,
                                child: Text(m.name),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedMinistry = val;
                              });
                            },
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 20),

                    // Generate Button
                    PrimaryButton(
                      text: 'Generate Invite Code',
                      isLoading: _isLoading,
                      onPressed: _handleGenerateInvite,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Latest Generated Code Display Banner
            if (_latestGeneratedInvite != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9E6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.gold, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.vpn_key_outlined, color: AppColors.warningText, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Invitation Code Ready',
                          style: GoogleFonts.sourceSerif4(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.warningText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'For: ${_latestGeneratedInvite!.targetName} (${_latestGeneratedInvite!.roleDisplay})',
                      style: GoogleFonts.nunitoSans(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: SelectableText(
                        _latestGeneratedInvite!.code,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunitoSans(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Valid for 7 days • Single use',
                      style: GoogleFonts.nunitoSans(fontSize: 11, color: AppColors.softGrey),
                    ),
                    const SizedBox(height: 14),

                    // Share Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: AppColors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: const Icon(Icons.chat_bubble_outline, size: 16),
                            label: const Text('WhatsApp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            onPressed: () => _shareViaWhatsApp(_latestGeneratedInvite!),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.navy,
                              foregroundColor: AppColors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: const Icon(Icons.sms_outlined, size: 16),
                            label: const Text('SMS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            onPressed: () => _shareViaSms(_latestGeneratedInvite!),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.copy, size: 18),
                          tooltip: 'Copy Code',
                          onPressed: () => _copyInviteToClipboard(_latestGeneratedInvite!),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Active & Past Invites List
            Text(
              'Active & Past Invitations',
              style: GoogleFonts.sourceSerif4(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 10),

            invitesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error loading invites: $err')),
              data: (invites) {
                if (invites.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'No invitations created yet.',
                      style: GoogleFonts.nunitoSans(color: AppColors.softGrey),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: invites.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final inv = invites[index];
                    return _buildInviteCard(inv);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteCard(InviteModel invite) {
    Color statusBg;
    Color statusTextColor;
    String statusLabel;

    if (invite.isRedeemed) {
      statusBg = const Color(0xFFEAF7EE);
      statusTextColor = const Color(0xFF2E7D32);
      statusLabel = 'Redeemed';
    } else if (invite.isCancelled) {
      statusBg = const Color(0xFFF1F3F5);
      statusTextColor = AppColors.softGrey;
      statusLabel = 'Cancelled';
    } else if (invite.isExpired) {
      statusBg = const Color(0xFFFDE8E8);
      statusTextColor = AppColors.error;
      statusLabel = 'Expired';
    } else {
      statusBg = const Color(0xFFFFF4E0);
      statusTextColor = const Color(0xFF7A4A00);
      statusLabel = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  invite.targetName,
                  style: GoogleFonts.nunitoSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.text,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.nunitoSans(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            invite.roleDisplay,
            style: GoogleFonts.nunitoSans(
              fontSize: 13,
              color: AppColors.softGrey,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.vpn_key, size: 16, color: AppColors.navy),
                  const SizedBox(width: 6),
                  Text(
                    invite.code,
                    style: GoogleFonts.nunitoSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: AppColors.navy,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16, color: AppColors.softGrey),
                    tooltip: 'Copy Code',
                    onPressed: () => _copyInviteToClipboard(invite),
                  ),
                  if (invite.isPending) ...[
                    IconButton(
                      icon: const Icon(Icons.share, size: 16, color: AppColors.navy),
                      tooltip: 'Share via WhatsApp',
                      onPressed: () => _shareViaWhatsApp(invite),
                    ),
                    TextButton(
                      onPressed: () => _confirmCancelInvite(invite),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Created: ${DateFormat('dd MMM yyyy, HH:mm').format(invite.createdAt)} • Expires: ${DateFormat('dd MMM yyyy').format(invite.expiresAt)}',
            style: GoogleFonts.nunitoSans(fontSize: 10, color: AppColors.softGrey),
          ),
        ],
      ),
    );
  }
}
