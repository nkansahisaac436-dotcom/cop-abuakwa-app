import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/ministries_provider.dart';
import 'ministry_detail_screen.dart';

class MinistriesListScreen extends ConsumerWidget {
  const MinistriesListScreen({super.key});

  IconData _getMinistryIcon(String code) {
    switch (code) {
      case 'youth':
        return Icons.people_alt_outlined;
      case 'evangelism':
        return Icons.campaign_outlined;
      case 'childrens':
        return Icons.child_care_outlined;
      case 'pemem':
        return Icons.shield_outlined;
      case 'womens':
        return Icons.favorite_border_rounded;
      default:
        return Icons.groups_outlined;
    }
  }

  Color _getMinistryColor(String code) {
    switch (code) {
      case 'youth':
        return const Color(0xFF0284C7);
      case 'evangelism':
        return const Color(0xFFEA580C);
      case 'childrens':
        return const Color(0xFF16A34A);
      case 'pemem':
        return AppColors.navy;
      case 'womens':
        return const Color(0xFFDB2777);
      default:
        return AppColors.gold;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ministriesAsync = ref.watch(ministriesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Five Core Ministries'),
      ),
      body: ministriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (ministries) {
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: ministries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final ministry = ministries[index];
              final brandColor = _getMinistryColor(ministry.code);

              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MinistryDetailScreen(ministry: ministry),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: brandColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          _getMinistryIcon(ministry.code),
                          color: brandColor,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ministry.name,
                              style: GoogleFonts.sourceSerif4(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.navy,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              ministry.description ?? '',
                              maxLines: 2,
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
                      // Follow/Following Button
                      TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: ministry.isFollowed
                              ? AppColors.disabled
                              : AppColors.navy.withValues(alpha: 0.08),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () {
                          ref.read(ministriesListProvider.notifier).toggleFollow(ministry.id);
                        },
                        child: Text(
                          ministry.isFollowed ? 'Following' : 'Follow',
                          style: GoogleFonts.nunitoSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: ministry.isFollowed ? AppColors.softGrey : AppColors.navy,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
