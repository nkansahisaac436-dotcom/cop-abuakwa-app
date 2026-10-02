import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/district_model.dart';
import '../providers/districts_provider.dart';

class DistrictsActivationScreen extends ConsumerStatefulWidget {
  const DistrictsActivationScreen({super.key});

  @override
  ConsumerState<DistrictsActivationScreen> createState() => _DistrictsActivationScreenState();
}

class _DistrictsActivationScreenState extends ConsumerState<DistrictsActivationScreen> {
  String _searchQuery = '';
  String _filter = 'all'; // 'all', 'active', 'inactive'

  void _confirmToggleDistrict(DistrictModel district, String currentUserId) {
    final willActivate = district.isInactive;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          willActivate ? 'Activate District?' : 'Deactivate District?',
          style: GoogleFonts.sourceSerif4(fontWeight: FontWeight.bold),
        ),
        content: Text(
          willActivate
              ? 'Activating "${district.name}" will immediately allow church members in this district to create accounts and join.'
              : 'Deactivating "${district.name}" will prevent new member sign-ups for this district.',
          style: GoogleFonts.nunitoSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: GoogleFonts.nunitoSans(color: AppColors.softGrey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: willActivate ? AppColors.success : AppColors.error,
              foregroundColor: AppColors.white,
              shape: const StadiumBorder(),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref
                  .read(districtsListProvider.notifier)
                  .toggleDistrictActivation(district.id, currentUserId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      willActivate
                          ? '"${district.name}" is now Active & Approved.'
                          : '"${district.name}" has been Deactivated.',
                    ),
                    backgroundColor: willActivate ? AppColors.success : AppColors.softGrey,
                  ),
                );
              }
            },
            child: Text(willActivate ? 'Activate' : 'Deactivate'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final districtsAsync = ref.watch(districtsListProvider);
    final userProfile = ref.watch(authStateProvider).value;
    final currentUserId = userProfile?.id ?? 'area-head-user';

    return Scaffold(
      appBar: AppBar(
        title: const Text('District Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(districtsListProvider.notifier).refresh(),
          ),
        ],
      ),
      body: districtsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Error: $err', style: const TextStyle(color: AppColors.error)),
        ),
        data: (districts) {
          final totalCount = districts.length;
          final activeCount = districts.where((d) => d.isActive).length;
          final inactiveCount = districts.where((d) => d.isInactive).length;

          final filteredDistricts = districts.where((d) {
            final matchesSearch = d.name.toLowerCase().contains(_searchQuery.toLowerCase());
            if (!matchesSearch) return false;
            if (_filter == 'active') return d.isActive;
            if (_filter == 'inactive') return d.isInactive;
            return true;
          }).toList();

          return Column(
            children: [
              // Header Summary Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: AppColors.white,
                child: Column(
                  children: [
                    Row(
                      children: [
                        _buildSummaryBadge('Total Districts', '$totalCount', AppColors.navy),
                        const SizedBox(width: 12),
                        _buildSummaryBadge('Active (Approved)', '$activeCount', AppColors.success),
                        const SizedBox(width: 12),
                        _buildSummaryBadge('Inactive', '$inactiveCount', AppColors.warningBorder),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Search input
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search 33 districts...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    // Filter chips
                    Row(
                      children: [
                        _buildFilterChip('All ($totalCount)', 'all'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Active ($activeCount)', 'active'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Inactive ($inactiveCount)', 'inactive'),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),

              // District List
              Expanded(
                child: filteredDistricts.isEmpty
                    ? Center(
                        child: Text(
                          'No districts match your search.',
                          style: GoogleFonts.nunitoSans(color: AppColors.softGrey),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: filteredDistricts.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final district = filteredDistricts[index];
                          final isActive = district.isActive;

                          return Material(
                            color: AppColors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: isActive ? AppColors.border : AppColors.warningBorder.withValues(alpha: 0.6),
                                width: 1.2,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? AppColors.navy.withValues(alpha: 0.08)
                                      : AppColors.warningFill,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: GoogleFonts.nunitoSans(
                                      fontWeight: FontWeight.bold,
                                      color: isActive ? AppColors.navy : AppColors.warningText,
                                    ),
                                  ),
                                ),
                              ),
                              title: Text(
                                district.name,
                                style: GoogleFonts.nunitoSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.text,
                                ),
                              ),
                              subtitle: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: isActive ? AppColors.success : AppColors.warningBorder,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isActive ? 'Active (Members can sign up)' : 'Inactive (Blocked)',
                                    style: GoogleFonts.nunitoSans(
                                      fontSize: 12,
                                      color: isActive ? AppColors.success : AppColors.warningText,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isActive ? AppColors.disabled : AppColors.navy,
                                  foregroundColor: isActive ? AppColors.text : AppColors.white,
                                  shape: const StadiumBorder(),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  minimumSize: const Size(80, 36),
                                ),
                                onPressed: () => _confirmToggleDistrict(district, currentUserId),
                                child: Text(
                                  isActive ? 'Deactivate' : 'Activate',
                                  style: GoogleFonts.nunitoSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryBadge(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.sourceSerif4(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filter = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.navy : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.navy : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.nunitoSans(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? AppColors.white : AppColors.softGrey,
          ),
        ),
      ),
    );
  }
}
