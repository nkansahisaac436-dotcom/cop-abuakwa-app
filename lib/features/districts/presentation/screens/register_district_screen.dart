import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/districts_provider.dart';

class RegisterDistrictScreen extends ConsumerStatefulWidget {
  final String? initialDistrictId;
  final String? initialName;
  final List<String>? initialAssemblies;

  const RegisterDistrictScreen({
    super.key,
    this.initialDistrictId,
    this.initialName,
    this.initialAssemblies,
  });

  @override
  ConsumerState<RegisterDistrictScreen> createState() => _RegisterDistrictScreenState();
}

class _RegisterDistrictScreenState extends ConsumerState<RegisterDistrictScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _districtNameController;
  final List<TextEditingController> _assemblyControllers = [];
  DateTime _startDate = DateTime.now();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _districtNameController = TextEditingController(text: widget.initialName ?? '');
    if (widget.initialAssemblies != null && widget.initialAssemblies!.isNotEmpty) {
      for (final name in widget.initialAssemblies!) {
        _assemblyControllers.add(TextEditingController(text: name));
      }
    } else {
      _assemblyControllers.add(TextEditingController(text: 'Central Assembly'));
    }
  }

  @override
  void dispose() {
    _districtNameController.dispose();
    for (final c in _assemblyControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addAssemblyField() {
    setState(() {
      _assemblyControllers.add(TextEditingController());
    });
  }

  void _removeAssemblyField(int index) {
    if (_assemblyControllers.length > 1) {
      setState(() {
        _assemblyControllers.removeAt(index).dispose();
      });
    }
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.navy,
              onPrimary: AppColors.white,
              onSurface: AppColors.text,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    final assemblies = _assemblyControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (assemblies.isEmpty) {
      setState(() {
        _errorMessage = 'Please add at least one assembly.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(districtsRepositoryProvider);
      if (widget.initialDistrictId != null) {
        // Resubmission
        await repo.resubmitDistrict(
          districtId: widget.initialDistrictId!,
          name: _districtNameController.text.trim(),
          assemblies: assemblies,
          startDate: _startDate,
        );
      } else {
        // New Registration
        await repo.registerDistrict(
          name: _districtNameController.text.trim(),
          assemblies: assemblies,
          startDate: _startDate,
        );
      }

      await ref.read(districtsListProvider.notifier).refresh();
      if (mounted) {
        context.go('/pastor/waiting-approval');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isResubmitting = widget.initialDistrictId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isResubmitting ? 'Edit & Resubmit District' : 'Register your district'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authStateProvider.notifier).signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.paddingLarge),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.navy.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.navy.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.church, color: AppColors.navy, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isResubmitting
                              ? 'Update your district details and resubmit for Area Head approval.'
                              : 'Welcome Pastor! Please register your district to begin collaborating with the Area Head.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.navyDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // District Name
                AppTextField(
                  label: 'District Name',
                  hintText: 'e.g. Abuakwa Central',
                  prefixIcon: const Icon(Icons.location_city),
                  controller: _districtNameController,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter the district name';
                    }
                    if (val.trim().length < 2) {
                      return 'District name is too short';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Assemblies
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Local Assemblies',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _addAssemblyField,
                      icon: const Icon(Icons.add, size: 18, color: AppColors.navy),
                      label: const Text('Add Assembly', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                ...List.generate(_assemblyControllers.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'Assembly ${index + 1}',
                            hintText: 'e.g. Central Assembly',
                            prefixIcon: const Icon(Icons.home_work_outlined),
                            controller: _assemblyControllers[index],
                            validator: (val) {
                              if (index == 0 && (val == null || val.trim().isEmpty)) {
                                return 'Please enter at least one assembly';
                              }
                              return null;
                            },
                          ),
                        ),
                        if (_assemblyControllers.length > 1)
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: AppColors.error),
                            onPressed: () => _removeAssemblyField(index),
                          ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 14),

                // Start Date
                const Text(
                  'Tenure Start Date',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _selectStartDate,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month, color: AppColors.navy, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          DateFormat.yMMMMd().format(_startDate),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text),
                        ),
                        const Spacer(),
                        const Text('Change', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Submit Button
                PrimaryButton(
                  text: isResubmitting ? 'Resubmit for Approval' : 'Submit District Registration',
                  isLoading: _isLoading,
                  onPressed: _submitRegistration,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
