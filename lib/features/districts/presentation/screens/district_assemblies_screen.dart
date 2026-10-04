import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/assembly_model.dart';
import '../providers/districts_provider.dart';

class DistrictAssembliesScreen extends ConsumerStatefulWidget {
  final String? districtId;
  final String? districtName;

  const DistrictAssembliesScreen({
    super.key,
    this.districtId,
    this.districtName,
  });

  @override
  ConsumerState<DistrictAssembliesScreen> createState() => _DistrictAssembliesScreenState();
}

class _DistrictAssembliesScreenState extends ConsumerState<DistrictAssembliesScreen> {
  String _searchQuery = '';
  bool _showHidden = false;

  void _showAddAssemblyModal(String districtId) {
    final nameController = TextEditingController();
    String? errorText;
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Add Local Assembly',
                    style: GoogleFonts.sourceSerif4(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (errorText != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(errorText!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Assembly Name',
                  hintText: 'e.g. Central Assembly',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  prefixIcon: const Icon(Icons.home_work_outlined),
                ),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                text: 'Save Assembly',
                isLoading: isSaving,
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.length < 2) {
                    setModalState(() => errorText = 'Please enter a valid assembly name.');
                    return;
                  }

                  setModalState(() {
                    isSaving = true;
                    errorText = null;
                  });

                  try {
                    await ref.read(districtsListProvider.notifier).addAssembly(districtId, name);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Assembly "$name" added successfully.'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  } catch (e) {
                    setModalState(() {
                      errorText = e.toString().replaceAll('Exception: ', '');
                      isSaving = false;
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRenameModal(AssemblyModel assembly) {
    final nameController = TextEditingController(text: assembly.name);
    String? errorText;
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Rename Assembly',
                    style: GoogleFonts.sourceSerif4(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (errorText != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(errorText!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'New Assembly Name',
                  hintText: 'e.g. Grace Assembly',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  prefixIcon: const Icon(Icons.edit_outlined),
                ),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                text: 'Update Name',
                isLoading: isSaving,
                onPressed: () async {
                  final newName = nameController.text.trim();
                  if (newName.length < 2) {
                    setModalState(() => errorText = 'Please enter a valid assembly name.');
                    return;
                  }

                  setModalState(() {
                    isSaving = true;
                    errorText = null;
                  });

                  try {
                    await ref
                        .read(districtsListProvider.notifier)
                        .renameAssembly(assembly.districtId, assembly.id, newName);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Assembly renamed to "$newName".'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  } catch (e) {
                    setModalState(() {
                      errorText = e.toString().replaceAll('Exception: ', '');
                      isSaving = false;
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmToggleHide(AssemblyModel assembly) {
    final willHide = assembly.isActive;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          willHide ? 'Hide "${assembly.name}"?' : 'Unhide "${assembly.name}"?',
          style: GoogleFonts.sourceSerif4(fontWeight: FontWeight.bold),
        ),
        content: Text(
          willHide
              ? 'Hiding this assembly prevents new members or projects from selecting it. Existing linked projects, posts, and member histories remain preserved.'
              : 'Unhiding this assembly will make it active and selectable for new members and activities.',
          style: GoogleFonts.nunitoSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: willHide ? AppColors.error : AppColors.navy,
              foregroundColor: AppColors.white,
              shape: const StadiumBorder(),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(districtsListProvider.notifier)
                    .toggleAssemblyStatus(assembly.districtId, assembly.id, !willHide);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        willHide
                            ? 'Assembly "${assembly.name}" is now hidden.'
                            : 'Assembly "${assembly.name}" is now active.',
                      ),
                      backgroundColor: willHide ? AppColors.softGrey : AppColors.success,
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
            },
            child: Text(willHide ? 'Hide Assembly' : 'Unhide Assembly'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final resolvedDistrictId = widget.districtId ?? user?.districtId ?? '';
    final resolvedDistrictName = widget.districtName ?? user?.districtName ?? 'My District';
    final assembliesAsync = ref.watch(assembliesForDistrictProvider(resolvedDistrictId));
    final canManage = user == null || user.isPastor || user.isAreaHead;

    return Scaffold(
      appBar: AppBar(
        title: Text('$resolvedDistrictName Assemblies'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(assembliesForDistrictProvider(resolvedDistrictId)),
          ),
        ],
      ),
      floatingActionButton: canManage && resolvedDistrictId.isNotEmpty
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.navy,
              foregroundColor: AppColors.white,
              icon: const Icon(Icons.add),
              label: Text(
                'Add assembly',
                style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold),
              ),
              onPressed: () => _showAddAssemblyModal(resolvedDistrictId),
            )
          : null,
      body: assembliesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Error loading assemblies: $err', style: const TextStyle(color: AppColors.error)),
        ),
        data: (assemblies) {
          final activeAssemblies = assemblies.where((a) => a.isActive).toList();
          final hiddenAssemblies = assemblies.where((a) => !a.isActive).toList();

          if (assemblies.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.navy.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.home_work_outlined, size: 64, color: AppColors.navy),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No Assemblies Added Yet',
                      style: GoogleFonts.sourceSerif4(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.navyDark),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Add your local church assemblies to your district so members can register and connect with local activities.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: AppColors.softGrey, height: 1.4),
                    ),
                    const SizedBox(height: 28),
                    if (canManage && resolvedDistrictId.isNotEmpty)
                      PrimaryButton(
                        text: 'Add your first assembly',
                        onPressed: () => _showAddAssemblyModal(resolvedDistrictId),
                      ),
                  ],
                ),
              ),
            );
          }

          final listToDisplay = _showHidden ? assemblies : activeAssemblies;
          final filtered = listToDisplay
              .where((a) => a.name.toLowerCase().contains(_searchQuery.toLowerCase()))
              .toList();

          return Column(
            children: [
              // Search & Filter header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: AppColors.white,
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search assemblies...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                    if (hiddenAssemblies.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Active: ${activeAssemblies.length} • Hidden: ${hiddenAssemblies.length}',
                            style: const TextStyle(fontSize: 12, color: AppColors.softGrey, fontWeight: FontWeight.w600),
                          ),
                          InkWell(
                            onTap: () => setState(() => _showHidden = !_showHidden),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                              child: Text(
                                _showHidden ? 'Show Active Only' : 'Show Hidden (${hiddenAssemblies.length})',
                                style: const TextStyle(fontSize: 12, color: AppColors.navy, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),

              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final assembly = filtered[index];
                    final isActive = assembly.isActive;

                    return Material(
                      color: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isActive ? AppColors.border : AppColors.warningBorder.withValues(alpha: 0.6),
                          width: 1.2,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        leading: CircleAvatar(
                          backgroundColor: isActive ? AppColors.navy.withValues(alpha: 0.08) : AppColors.warningFill,
                          child: Icon(
                            Icons.home_work_outlined,
                            size: 20,
                            color: isActive ? AppColors.navy : AppColors.warningText,
                          ),
                        ),
                        title: Text(
                          assembly.name,
                          style: GoogleFonts.nunitoSans(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isActive ? AppColors.text : AppColors.softGrey,
                          ),
                        ),
                        subtitle: Text(
                          isActive ? 'Active Assembly' : 'Hidden (Deactivated)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isActive ? AppColors.success : AppColors.warningText,
                          ),
                        ),
                        trailing: canManage
                            ? PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: AppColors.softGrey),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                onSelected: (action) {
                                  if (action == 'rename') {
                                    _showRenameModal(assembly);
                                  } else if (action == 'toggle') {
                                    _confirmToggleHide(assembly);
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'rename',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined, size: 18, color: AppColors.navy),
                                        SizedBox(width: 8),
                                        Text('Rename assembly'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'toggle',
                                    child: Row(
                                      children: [
                                        Icon(
                                          isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                          size: 18,
                                          color: isActive ? AppColors.error : AppColors.success,
                                        ),
                                        SizedBox(width: 8),
                                        Text(isActive ? 'Hide assembly' : 'Unhide assembly'),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : null,
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
}
