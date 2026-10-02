import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/warning_banner.dart';
import '../../../districts/domain/models/assembly_model.dart';
import '../../../districts/domain/models/district_model.dart';
import '../../../districts/presentation/providers/districts_provider.dart';
import '../providers/auth_provider.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  DistrictModel? _selectedDistrict;
  AssemblyModel? _selectedAssembly;
  bool _agreedToConsent = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _isDistrictPendingOrInactive =>
      _selectedDistrict != null && (_selectedDistrict!.isPending || _selectedDistrict!.isInactive);

  bool get _isFormInteractable =>
      _selectedDistrict != null && _selectedDistrict!.isActive;

  Future<void> _handleSignUp() async {
    setState(() {
      _errorMessage = null;
    });

    if (_selectedDistrict == null) {
      setState(() {
        _errorMessage = 'Please select your district.';
      });
      return;
    }

    if (_isDistrictPendingOrInactive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your district has not been approved yet. Please try again later.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedAssembly == null) {
      setState(() {
        _errorMessage = 'Please choose your local assembly.';
      });
      return;
    }

    if (!_agreedToConsent) {
      setState(() {
        _errorMessage = 'Please agree to how your details are used.';
      });
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ref.read(authStateProvider.notifier).signUpMember(
            fullName: _fullNameController.text,
            email: _emailController.text,
            password: _passwordController.text,
            districtId: _selectedDistrict!.id,
            assemblyId: _selectedAssembly!.id,
          );
      if (mounted) {
        Navigator.of(context).pop();
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
    final districtsAsync = ref.watch(districtsListProvider);
    final assembliesAsync = (_selectedDistrict != null && _selectedDistrict!.isActive)
        ? ref.watch(assembliesForDistrictProvider(_selectedDistrict!.id))
        : const AsyncValue.data(<AssemblyModel>[]);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Navy Header with Back Button and Title
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 40, bottom: 28, left: 16, right: 16),
              decoration: const BoxDecoration(
                gradient: AppColors.navyGradient,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: AppColors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Image.asset(
                        'assets/images/abuakwa_logo.png',
                        width: 56,
                        height: 56,
                        filterQuality: FilterQuality.high,
                        semanticLabel: 'Church of Pentecost logo',
                      ),
                      const SizedBox(width: 48), // balances the back button
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    AppStrings.createYourAccount,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.sourceSerif4(
                      fontSize: AppDimensions.fontSizeScreenTitle,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                  ),
                ],
              ),
            ),

            // 2. White Form Card
            Transform.translate(
              offset: const Offset(0, -14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 480),
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: AppDimensions.cardBorderRadius,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Error message if any
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDE8E8),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: GoogleFonts.nunitoSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Full Name Field
                        AppTextField(
                          label: AppStrings.fullName,
                          hintText: AppStrings.fullNamePlaceholder,
                          controller: _fullNameController,
                          prefixIcon: const Icon(Icons.person_outline),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your full name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Email Field
                        AppTextField(
                          label: AppStrings.email,
                          hintText: AppStrings.emailPlaceholder,
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: const Icon(Icons.mail_outline),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!value.contains('@')) {
                              return 'Please enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // District Dropdown
                        Text(
                          AppStrings.district,
                          style: GoogleFonts.nunitoSans(
                            fontSize: AppDimensions.fontSizeLabel,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 6),
                        districtsAsync.when(
                          loading: () => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(12.0),
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          error: (err, _) => Text(
                            'Error loading districts: $err',
                            style: const TextStyle(color: AppColors.error),
                          ),
                          data: (allDistricts) {
                            // Filter out rejected districts
                            final visibleDistricts = allDistricts.where((d) => !d.isRejected).toList();

                            if (visibleDistricts.isEmpty) {
                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.disabled,
                                  borderRadius: AppDimensions.inputBorderRadius,
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: const Text(
                                  'No districts are available yet. Please check again soon.',
                                  style: TextStyle(color: AppColors.softGrey, fontSize: 13),
                                ),
                              );
                            }

                            return Container(
                              constraints: const BoxConstraints(minHeight: AppDimensions.minTouchTarget),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: AppDimensions.inputBorderRadius,
                                border: Border.all(
                                  color: _isDistrictPendingOrInactive ? AppColors.error : AppColors.border,
                                  width: _isDistrictPendingOrInactive ? 1.8 : 1.2,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<DistrictModel>(
                                  isExpanded: true,
                                  value: _selectedDistrict,
                                  hint: Row(
                                    children: [
                                      const Icon(Icons.location_on_outlined, color: AppColors.softGrey, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        AppStrings.chooseDistrict,
                                        style: GoogleFonts.nunitoSans(
                                          fontSize: AppDimensions.fontSizeInput,
                                          color: AppColors.softGrey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.navy),
                                  items: visibleDistricts.map((district) {
                                    final isPending = district.isPending || district.isInactive;
                                    return DropdownMenuItem<DistrictModel>(
                                      value: district,
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.location_on_outlined,
                                            color: isPending ? AppColors.softGrey : AppColors.navy,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              district.name,
                                              style: GoogleFonts.nunitoSans(
                                                fontSize: AppDimensions.fontSizeInput,
                                                color: isPending ? AppColors.softGrey : AppColors.text,
                                              ),
                                            ),
                                          ),
                                          if (isPending)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.warningFill,
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: AppColors.warningBorder),
                                              ),
                                              child: const Text(
                                                'Awaiting approval',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.warningText,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedDistrict = value;
                                      _selectedAssembly = null;
                                      _errorMessage = null;
                                    });

                                    if (value != null && (value.isPending || value.isInactive)) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Your district has not been approved yet. Please try again later.'),
                                          backgroundColor: AppColors.warningText,
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                            );
                          },
                        ),

                        // Inactive/Pending District Warning Banner
                        if (_isDistrictPendingOrInactive) ...[
                          const SizedBox(height: 14),
                          const WarningBanner(
                            title: 'District not approved yet',
                            message: 'Your district has not been approved yet. Please try again later.',
                          ),
                        ],

                        const SizedBox(height: 16),

                        // Assembly Dropdown (Disabled if District is Inactive/Pending or Unselected)
                        Text(
                          AppStrings.assembly,
                          style: GoogleFonts.nunitoSans(
                            fontSize: AppDimensions.fontSizeLabel,
                            fontWeight: FontWeight.bold,
                            color: _isFormInteractable ? AppColors.text : AppColors.softGrey,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          constraints: const BoxConstraints(minHeight: AppDimensions.minTouchTarget),
                          decoration: BoxDecoration(
                            color: _isFormInteractable ? AppColors.white : AppColors.disabled,
                            borderRadius: AppDimensions.inputBorderRadius,
                            border: Border.all(
                              color: AppColors.border,
                              width: 1.0,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<AssemblyModel>(
                              isExpanded: true,
                              value: _selectedAssembly,
                              hint: Row(
                                children: [
                                  Icon(
                                    Icons.place_outlined,
                                    color: _isFormInteractable ? AppColors.softGrey : AppColors.disabledText,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    AppStrings.chooseAssembly,
                                    style: GoogleFonts.nunitoSans(
                                      fontSize: AppDimensions.fontSizeInput,
                                      color: _isFormInteractable ? AppColors.softGrey : AppColors.disabledText,
                                    ),
                                  ),
                                ],
                              ),
                              icon: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: _isFormInteractable ? AppColors.navy : AppColors.disabledText,
                              ),
                              items: _isFormInteractable
                                  ? assembliesAsync.maybeWhen(
                                      data: (assemblies) => assemblies.map((assembly) {
                                        return DropdownMenuItem<AssemblyModel>(
                                          value: assembly,
                                          child: Text(
                                            assembly.name,
                                            style: GoogleFonts.nunitoSans(
                                              fontSize: AppDimensions.fontSizeInput,
                                              color: AppColors.text,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      orElse: () => [],
                                    )
                                  : null,
                              onChanged: _isFormInteractable
                                  ? (value) {
                                      setState(() {
                                        _selectedAssembly = value;
                                      });
                                    }
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Password Field (Disabled if Inactive)
                        AppTextField(
                          label: AppStrings.password,
                          hintText: AppStrings.createPassword,
                          controller: _passwordController,
                          isPassword: true,
                          enabled: _isFormInteractable,
                          prefixIcon: const Icon(Icons.lock_outline),
                          validator: (value) {
                            if (_isFormInteractable && (value == null || value.length < 6)) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Consent Checkbox (Disabled if Inactive)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Checkbox(
                              value: _agreedToConsent,
                              activeColor: AppColors.navy,
                              onChanged: _isFormInteractable
                                  ? (val) {
                                      setState(() {
                                        _agreedToConsent = val ?? false;
                                      });
                                    }
                                  : null,
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: _isFormInteractable
                                    ? () {
                                        setState(() {
                                          _agreedToConsent = !_agreedToConsent;
                                        });
                                      }
                                    : null,
                                child: Text(
                                  AppStrings.dataConsent,
                                  style: GoogleFonts.nunitoSans(
                                    fontSize: 13,
                                    color: _isFormInteractable ? AppColors.text : AppColors.disabledText,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Create Account Button
                        PrimaryButton(
                          text: AppStrings.createAccount,
                          isLoading: _isLoading,
                          backgroundColor: _isFormInteractable ? AppColors.navy : const Color(0xFFC4CBD4),
                          textColor: _isFormInteractable ? AppColors.white : const Color(0xFF8C98A8),
                          onPressed: _isFormInteractable ? _handleSignUp : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
