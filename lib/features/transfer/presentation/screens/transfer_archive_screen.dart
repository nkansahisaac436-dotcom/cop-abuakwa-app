import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cop_abuakwa_app/core/constants/app_colors.dart';
import 'package:cop_abuakwa_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:cop_abuakwa_app/features/transfer/domain/models/tenure_archive_model.dart';
import 'package:cop_abuakwa_app/features/transfer/domain/models/transfer_request_model.dart';
import 'package:cop_abuakwa_app/features/transfer/presentation/providers/transfer_provider.dart';
import 'archive_detail_screen.dart';

class TransferArchiveScreen extends ConsumerStatefulWidget {
  const TransferArchiveScreen({super.key});

  @override
  ConsumerState<TransferArchiveScreen> createState() => _TransferArchiveScreenState();
}

class _TransferArchiveScreenState extends ConsumerState<TransferArchiveScreen> {
  String _searchQuery = '';

  void _handleApprove(TransferRequestModel req) {
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Approve Transfer?', style: GoogleFonts.sourceSerif4(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Approving this transfer will permanently archive ${req.pastorName ?? "this pastor"}\'s ministry tenure and create a permanent read-only archive file. All district projects will remain intact in the district.',
              style: GoogleFonts.nunitoSans(fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                hintText: 'Optional approval note / instructions...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy, foregroundColor: AppColors.white),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(transferNotifierProvider.notifier).approveTransfer(
                    req.id,
                    note: noteController.text,
                  );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Transfer approved. Tenure archive created successfully.'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            child: const Text('Approve & Archive'),
          ),
        ],
      ),
    );
  }

  void _handleReject(TransferRequestModel req) {
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reject Transfer Request', style: GoogleFonts.sourceSerif4(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Provide reason for not approving transfer request for ${req.pastorName}:',
              style: GoogleFonts.nunitoSans(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                hintText: 'Reason for rejection...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: AppColors.white),
            onPressed: () async {
              if (noteController.text.trim().isEmpty) return;
              Navigator.of(ctx).pop();
              await ref.read(transferNotifierProvider.notifier).rejectTransfer(
                    req.id,
                    noteController.text,
                  );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Transfer request rejected.')),
                );
              }
            },
            child: const Text('Reject Request'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final isAreaHead = user?.isAreaHead ?? false;
    final pendingRequestsAsync = ref.watch(pendingTransferRequestsProvider);
    final archivesAsync = ref.watch(tenureArchivesProvider(_searchQuery));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tenure Archives & Transfers'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Pending Transfer Requests Section (Area Head only)
            if (isAreaHead) ...[
              Text(
                'Pending Transfer Requests',
                style: GoogleFonts.sourceSerif4(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 8),
              pendingRequestsAsync.when(
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())),
                error: (e, _) => Text('Error: $e'),
                data: (List<TransferRequestModel> requests) {
                  if (requests.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        'No pending pastor transfer requests.',
                        style: GoogleFonts.nunitoSans(color: AppColors.softGrey, fontSize: 13),
                      ),
                    );
                  }

                  return Column(
                    children: requests.map((TransferRequestModel req) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.warningBorder),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  req.pastorName ?? 'Pastor',
                                  style: GoogleFonts.sourceSerif4(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.warningFill,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'PENDING APPROVAL',
                                    style: GoogleFonts.nunitoSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.warningText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'District: ${req.districtName ?? "Active District"}',
                              style: GoogleFonts.nunitoSans(fontSize: 13, color: AppColors.softGrey),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.navy,
                                      foregroundColor: AppColors.white,
                                      shape: const StadiumBorder(),
                                    ),
                                    onPressed: () => _handleApprove(req),
                                    child: const Text('Approve Transfer'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.error,
                                    side: const BorderSide(color: AppColors.error),
                                    shape: const StadiumBorder(),
                                  ),
                                  onPressed: () => _handleReject(req),
                                  child: const Text('Reject'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],

            // 2. Searchable Archives Section
            Text(
              'Pastoral Tenure Archives',
              style: GoogleFonts.sourceSerif4(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Search permanent read-only records by minister name, district, or years.',
              style: GoogleFonts.nunitoSans(fontSize: 12, color: AppColors.softGrey),
            ),
            const SizedBox(height: 12),

            // Search input
            TextField(
              decoration: InputDecoration(
                hintText: 'Search archives (e.g. Enoch, Abuakwa, 2021)...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: AppColors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
            ),
            const SizedBox(height: 16),

            archivesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error loading archives: $e')),
              data: (List<TenureArchiveModel> archives) {
                if (archives.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        'No tenure archives matching "$_searchQuery".',
                        style: GoogleFonts.nunitoSans(color: AppColors.softGrey),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: archives.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final arch = archives[index];

                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ArchiveDetailScreen(archive: arch),
                          ),
                        );
                      },
                      child: Container(
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
                              child: const Icon(Icons.history_edu, color: AppColors.navy, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    arch.title,
                                    style: GoogleFonts.sourceSerif4(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${arch.totalProjects} Projects • ${arch.totalEvents} Events • ${arch.totalThoughts} Thoughts',
                                    style: GoogleFonts.nunitoSans(
                                      fontSize: 12,
                                      color: AppColors.softGrey,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: AppColors.softGrey),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
