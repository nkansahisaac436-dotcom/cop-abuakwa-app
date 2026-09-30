import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/models/tenure_archive_model.dart';
import '../../utils/archive_pdf_generator.dart';

class ArchiveDetailScreen extends StatefulWidget {
  final TenureArchiveModel archive;

  const ArchiveDetailScreen({super.key, required this.archive});

  @override
  State<ArchiveDetailScreen> createState() => _ArchiveDetailScreenState();
}

class _ArchiveDetailScreenState extends State<ArchiveDetailScreen> {
  bool _isExporting = false;

  Future<void> _exportPdf() async {
    setState(() => _isExporting = true);
    try {
      await ArchivePdfGenerator.printOrShareArchivePdf(widget.archive);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF Export notice: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final arch = widget.archive;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pastoral Archive Record'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Export PDF',
            onPressed: _exportPdf,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Certificate Banner
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'PERMANENT READ-ONLY ARCHIVE',
                      style: GoogleFonts.nunitoSans(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.navyDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    arch.title,
                    style: GoogleFonts.sourceSerif4(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'District: ${arch.districtName.isNotEmpty ? arch.districtName : "Abuakwa Area"}',
                    style: GoogleFonts.nunitoSans(
                      fontSize: 14,
                      color: AppColors.lightGold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Metrics Summary Grid
            Text(
              'Tenure Overview & Summary',
              style: GoogleFonts.sourceSerif4(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                _buildStatTile('Projects', '${arch.totalProjects}', AppColors.navy),
                const SizedBox(width: 10),
                _buildStatTile('Events', '${arch.totalEvents}', AppColors.gold),
                const SizedBox(width: 10),
                _buildStatTile('Updates', '${arch.totalUpdates}', const Color(0xFF0D9488)),
                const SizedBox(width: 10),
                _buildStatTile('Thoughts', '${arch.totalThoughts}', const Color(0xFF6366F1)),
              ],
            ),
            const SizedBox(height: 20),

            // District Continuity Notice
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warningFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warningBorder.withValues(alpha: 0.6)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, color: AppColors.warningText, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This record is permanent and immutable. All projects remain in the district for incoming pastors.',
                      style: GoogleFonts.nunitoSans(
                        fontSize: 12,
                        color: AppColors.warningText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // PDF Export Action Button
            PrimaryButton(
              text: 'Export Official PDF Archive',
              icon: const Icon(Icons.picture_as_pdf, color: AppColors.white, size: 20),
              isLoading: _isExporting,
              onPressed: _exportPdf,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.sourceSerif4(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.nunitoSans(
                fontSize: 11,
                color: AppColors.softGrey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
