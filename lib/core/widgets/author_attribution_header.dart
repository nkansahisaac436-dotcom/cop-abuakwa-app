import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';

class AuthorAttributionHeader extends StatelessWidget {
  final String? authorName;
  final dynamic authorRole;
  final String? authorAvatarUrl;
  final String? districtName;
  final String? ministryName;
  final DateTime? timestamp;
  final DateTime? createdAt;

  const AuthorAttributionHeader({
    super.key,
    this.authorName,
    this.authorRole,
    this.authorAvatarUrl,
    this.districtName,
    this.ministryName,
    this.timestamp,
    this.createdAt,
  });

  DateTime? get _effectiveTime => createdAt ?? timestamp;

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length > 1 && parts.first.isNotEmpty && parts.last.isNotEmpty) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts.first.isNotEmpty) {
      return parts.first.substring(0, parts.first.length.clamp(1, 2)).toUpperCase();
    }
    return 'CO';
  }

  String _formatRole(dynamic role) {
    if (role == null) return 'Member';
    final str = role.toString().split('.').last.toLowerCase();
    switch (str) {
      case 'area_head':
      case 'areahead':
        return 'Area Head';
      case 'pastor':
        return 'Pastor';
      case 'ministry_leader':
      case 'ministryleader':
        return 'Ministry Leader';
      case 'member':
      default:
        return 'Member';
    }
  }

  Color _getRoleBadgeColor(dynamic role) {
    if (role == null) return AppColors.softGrey;
    final str = role.toString().split('.').last.toLowerCase();
    switch (str) {
      case 'area_head':
      case 'areahead':
        return AppColors.navy;
      case 'pastor':
        return AppColors.gold;
      case 'ministry_leader':
      case 'ministryleader':
        return const Color(0xFF2E7D32);
      default:
        return AppColors.softGrey;
    }
  }

  void _showAuthorProfileCard(BuildContext context) {
    final name = authorName ?? 'Church Minister';
    final roleLabel = _formatRole(authorRole);
    final badgeColor = _getRoleBadgeColor(authorRole);
    final affiliation = ministryName ?? districtName ?? 'Abuakwa Area';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar
              CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.navy,
                backgroundImage: authorAvatarUrl != null && authorAvatarUrl!.isNotEmpty
                    ? CachedNetworkImageProvider(authorAvatarUrl!)
                    : null,
                child: (authorAvatarUrl == null || authorAvatarUrl!.isEmpty)
                    ? Text(
                        _getInitials(name),
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 16),
              // Name
              Text(
                name,
                style: const TextStyle(
                  fontFamily: 'Source Serif 4',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              // Role Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  roleLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Affiliation
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.church_outlined, size: 16, color: AppColors.softGrey),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      affiliation,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.softGrey,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Close Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = authorName ?? 'Church Author';
    final roleLabel = _formatRole(authorRole);
    final badgeColor = _getRoleBadgeColor(authorRole);
    final subtitleInfo = [
      if (ministryName != null && ministryName!.isNotEmpty) ministryName!,
      if (districtName != null && districtName!.isNotEmpty) districtName!,
      if (_effectiveTime != null) DateFormat.MMMd().format(_effectiveTime!),
    ].join(' • ');

    return InkWell(
      onTap: () => _showAuthorProfileCard(context),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.navy,
              backgroundImage: authorAvatarUrl != null && authorAvatarUrl!.isNotEmpty
                  ? CachedNetworkImageProvider(authorAvatarUrl!)
                  : null,
              child: (authorAvatarUrl == null || authorAvatarUrl!.isEmpty)
                  ? Text(
                      _getInitials(name),
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          roleLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (subtitleInfo.isNotEmpty)
                    Text(
                      subtitleInfo,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.softGrey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
