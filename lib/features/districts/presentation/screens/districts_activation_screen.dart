import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/district_model.dart';
import '../providers/districts_provider.dart';

class DistrictsActivationScreen extends ConsumerStatefulWidget {
  const DistrictsActivationScreen({super.key});

  @override
  ConsumerState<DistrictsActivationScreen> createState() => _DistrictsActivationScreenState();
}

class _DistrictsActivationScreenState extends ConsumerState<DistrictsActivationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddDistrictModal() {
    final nameController = TextEditingController();
    final assemblyControllers = [TextEditingController(text: 'Central Assembly')];
    String? modalError;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Add New District',
                      style: GoogleFonts.sourceSerif4(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (modalError != null) ...[
                  Text(modalError!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                  const SizedBox(height: 8),
                ],
                AppTextField(
                  label: 'District Name',
                  hintText: 'e.g. Abuakwa South',
                  prefixIcon: const Icon(Icons.location_city),
                  controller: nameController,
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Assemblies', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    TextButton.icon(
                      onPressed: () {
                        setModalState(() {
                          assemblyControllers.add(TextEditingController());
                        });
                      },
                      icon: const Icon(Icons.add, size: 16, color: AppColors.navy),
                      label: const Text('Add', style: TextStyle(color: AppColors.navy, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                ...List.generate(assemblyControllers.length, (idx) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'Assembly ${idx + 1}',
                            hintText: 'e.g. Bethel Assembly',
                            controller: assemblyControllers[idx],
                          ),
                        ),
                        if (assemblyControllers.length > 1)
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: AppColors.error, size: 20),
                            onPressed: () {
                              setModalState(() {
                                assemblyControllers.removeAt(idx).dispose();
                              });
                            },
                          ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 20),
                PrimaryButton(
                  text: 'Create District (Active)',
                  isLoading: isSaving,
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      setModalState(() => modalError = 'Please enter a district name.');
                      return;
                    }
                    final assemblies = assemblyControllers
                        .map((c) => c.text.trim())
                        .where((t) => t.isNotEmpty)
                        .toList();

                    setModalState(() {
                      isSaving = true;
                      modalError = null;
                    });

                    try {
                      final repo = ref.read(districtsRepositoryProvider);
                      await repo.addDistrictDirectly(name: name, assemblies: assemblies);
                      await ref.read(districtsListProvider.notifier).refresh();
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('District "$name" created successfully.')),
                        );
                      }
                    } catch (e) {
                      setModalState(() {
                        modalError = e.toString().replaceAll('Exception: ', '');
                        isSaving = false;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _promptRejectDialog(DistrictModel district) {
    final noteController = TextEditingController();
    String? dialogError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Reject "${district.name}"?',
            style: GoogleFonts.sourceSerif4(fontWeight: FontWeight.bold, color: AppColors.error),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please provide a note explaining why this district registration is rejected so the pastor can make corrections and resubmit.',
                style: TextStyle(fontSize: 13, color: AppColors.text),
              ),
              const SizedBox(height: 12),
              if (dialogError != null) ...[
                Text(dialogError!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                const SizedBox(height: 6),
              ],
              TextField(
                controller: noteController,
                autofocus: true,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'e.g. Please correct assembly names or verify tenure start date...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.white,
                shape: const StadiumBorder(),
              ),
              onPressed: () async {
                final note = noteController.text.trim();
                if (note.isEmpty) {
                  setDialogState(() => dialogError = 'A rejection note is required.');
                  return;
                }

                Navigator.pop(ctx);
                try {
                  final repo = ref.read(districtsRepositoryProvider);
                  await repo.rejectDistrict(district.id, note: note);
                  await ref.read(districtsListProvider.notifier).refresh();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Registration for "${district.name}" rejected.')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              child: const Text('Confirm Rejection'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approveDistrict(DistrictModel district) async {
    try {
      final repo = ref.read(districtsRepositoryProvider);
      await repo.approveDistrict(district.id);
      await ref.read(districtsListProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${district.name}" is now Approved & Active!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _confirmToggleDeactivate(DistrictModel district, String currentUserId) {
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
                          ? '"${district.name}" is now Active.'
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
            icon: const Icon(Icons.add),
            tooltip: 'Add District',
            onPressed: _showAddDistrictModal,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(districtsListProvider.notifier).refresh(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppColors.gold,
          indicatorWeight: 3,
          tabs: [
            districtsAsync.when(
              data: (list) {
                final count = list.where((d) => d.isPending).length;
                return Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Pending'),
                      if (count > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.navyDark),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
              loading: () => const Tab(text: 'Pending'),
              error: (error, stack) => const Tab(text: 'Pending'),
            ),
            districtsAsync.when(
              data: (list) {
                final count = list.where((d) => d.isActive).length;
                return Tab(text: 'Active ($count)');
              },
              loading: () => const Tab(text: 'Active'),
              error: (error, stack) => const Tab(text: 'Active'),
            ),
            districtsAsync.when(
              data: (list) {
                final count = list.where((d) => d.isRejected).length;
                return Tab(text: 'Rejected ($count)');
              },
              loading: () => const Tab(text: 'Rejected'),
              error: (error, stack) => const Tab(text: 'Rejected'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDistrictModal,
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.white,
        icon: const Icon(Icons.add_business),
        label: const Text('Add District'),
      ),
      body: districtsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Error: $err', style: const TextStyle(color: AppColors.error)),
        ),
        data: (districts) {
          final pendingDistricts = districts.where((d) => d.isPending).toList();
          final activeDistricts = districts.where((d) => d.isActive || d.isInactive).toList();
          final rejectedDistricts = districts.where((d) => d.isRejected).toList();

          return Column(
            children: [
              // Search input
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search districts...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    filled: true,
                    fillColor: AppColors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),

              // Tab views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // 1. Pending Tab
                    _buildPendingTab(pendingDistricts),
                    // 2. Active Tab
                    _buildActiveTab(activeDistricts, currentUserId),
                    // 3. Rejected Tab
                    _buildRejectedTab(rejectedDistricts),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPendingTab(List<DistrictModel> list) {
    final filtered = list.where((d) => d.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 54, color: AppColors.softGrey),
            const SizedBox(height: 12),
            Text(
              'No Pending Registrations',
              style: GoogleFonts.sourceSerif4(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.softGrey),
            ),
            const SizedBox(height: 4),
            const Text(
              'All district registrations have been reviewed.',
              style: TextStyle(fontSize: 13, color: AppColors.softGrey),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final district = filtered[index];
        final pastorName = district.pastorName ?? 'Assigned Pastor';
        final pastorPhoto = district.pastorPhotoUrl;

        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.navy,
                      backgroundImage: pastorPhoto != null && pastorPhoto.isNotEmpty
                          ? CachedNetworkImageProvider(pastorPhoto)
                          : null,
                      child: (pastorPhoto == null || pastorPhoto.isEmpty)
                          ? const Icon(Icons.person, color: AppColors.white, size: 22)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            district.name,
                            style: GoogleFonts.sourceSerif4(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.navyDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Registered by: $pastorName',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.text),
                          ),
                          if (district.submittedAt != null)
                            Text(
                              'Submitted on ${DateFormat.yMMMd().format(district.submittedAt!)}',
                              style: const TextStyle(fontSize: 11, color: AppColors.softGrey),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (district.assemblyNames != null && district.assemblyNames!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Assemblies:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.softGrey)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: district.assemblyNames!.map((a) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(a, style: const TextStyle(fontSize: 11, color: AppColors.text)),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () => _promptRejectDialog(district),
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: AppColors.white,
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () => _approveDistrict(district),
                        child: const Text('Approve'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveTab(List<DistrictModel> list, String currentUserId) {
    final filtered = list.where((d) => d.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text('No active districts found.', style: GoogleFonts.nunitoSans(color: AppColors.softGrey)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final district = filtered[index];
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
            leading: CircleAvatar(
              backgroundColor: isActive ? AppColors.navy.withValues(alpha: 0.08) : AppColors.warningFill,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isActive ? AppColors.navy : AppColors.warningText,
                ),
              ),
            ),
            title: Text(
              district.name,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.text),
            ),
            subtitle: Text(
              isActive ? 'Active (Members can sign up)' : 'Deactivated',
              style: TextStyle(
                fontSize: 12,
                color: isActive ? AppColors.success : AppColors.warningText,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isActive ? AppColors.disabled : AppColors.navy,
                foregroundColor: isActive ? AppColors.text : AppColors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                minimumSize: const Size(80, 36),
              ),
              onPressed: () => _confirmToggleDeactivate(district, currentUserId),
              child: Text(isActive ? 'Deactivate' : 'Activate', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRejectedTab(List<DistrictModel> list) {
    final filtered = list.where((d) => d.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text('No rejected districts.', style: GoogleFonts.nunitoSans(color: AppColors.softGrey)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final district = filtered[index];
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      district.name,
                      style: GoogleFonts.sourceSerif4(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.text),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Rejected',
                        style: TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                if (district.pastorName != null) ...[
                  const SizedBox(height: 4),
                  Text('Pastor: ${district.pastorName}', style: const TextStyle(fontSize: 13, color: AppColors.softGrey)),
                ],
                if (district.decisionNote != null && district.decisionNote!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      'Rejection reason: "${district.decisionNote}"',
                      style: const TextStyle(fontSize: 12, color: AppColors.text, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
