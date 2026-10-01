import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/district_ring_logo.dart';
import '../../../../core/widgets/outline_button.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/models/invite_model.dart';
import '../../domain/models/profile_model.dart';
import '../providers/auth_provider.dart';
import 'signup_screen.dart';

enum PastorLeaderAuthMode { login, inviteCode }

class InviteCodeInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (text.length > 9) {
      text = text.substring(0, 9);
    }

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i == 3 || i == 7) {
        buffer.write('-');
      }
      buffer.write(text[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Invite code controllers
  final _inviteCodeController = TextEditingController();
  final _fullNameController = TextEditingController();

  UserRole _selectedRole = UserRole.member;
  PastorLeaderAuthMode _pastorLeaderMode = PastorLeaderAuthMode.login;

  bool _isLoading = false;
  bool _isVerifyingInvite = false;
  String? _errorMessage;
  String? _inviteErrorMessage;
  bool _submitted = false;

  InviteModel? _verifiedInvite;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _inviteCodeController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  void _onRoleChanged(UserRole role) {
    if (_selectedRole == role) return;
    setState(() {
      _selectedRole = role;
      _pastorLeaderMode = PastorLeaderAuthMode.login;
      _errorMessage = null;
      _inviteErrorMessage = null;
      _verifiedInvite = null;
      _submitted = false;
      _emailController.clear();
      _passwordController.clear();
      _inviteCodeController.clear();
      _fullNameController.clear();
    });
  }

  void _onModeChanged(PastorLeaderAuthMode mode) {
    if (_pastorLeaderMode == mode) return;
    setState(() {
      _pastorLeaderMode = mode;
      _errorMessage = null;
      _inviteErrorMessage = null;
      _submitted = false;
      _emailController.clear();
      _passwordController.clear();
      _inviteCodeController.clear();
      _fullNameController.clear();
      _verifiedInvite = null;
    });
  }

  Future<void> _handleLogin() async {
    setState(() {
      _submitted = true;
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ref.read(authStateProvider.notifier).signIn(
            email: _emailController.text,
            password: _passwordController.text,
            selectedRole: _selectedRole,
          );
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

  Future<void> _handlePasteCode() async {
    final data = await Clipboard.getData('text/plain');
    if (data != null && data.text != null && data.text!.isNotEmpty) {
      final formatter = InviteCodeInputFormatter();
      final formatted = formatter.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(text: data.text!),
      );
      setState(() {
        _inviteCodeController.text = formatted.text;
        _inviteErrorMessage = null;
      });

      if (formatted.text.length == 11) {
        _handleVerifyInvite();
      }
    }
  }

  Future<void> _handleVerifyInvite() async {
    final code = _inviteCodeController.text.trim().toUpperCase();
    if (code.isEmpty || code.length < 11) {
      setState(() {
        _inviteErrorMessage = 'Please enter a complete invite code (ABK-XXXX-XX).';
        _verifiedInvite = null;
      });
      return;
    }

    setState(() {
      _isVerifyingInvite = true;
      _inviteErrorMessage = null;
      _errorMessage = null;
    });

    try {
      final invite = await ref.read(authRepositoryProvider).verifyInviteCode(code);
      if (invite.role != _selectedRole) {
        throw Exception('This code is for a ${invite.role.label} account. Select ${invite.role.label} above.');
      }
      setState(() {
        _verifiedInvite = invite;
        if (invite.targetName.isNotEmpty && _fullNameController.text.isEmpty) {
          _fullNameController.text = invite.targetName;
        }
      });
    } catch (e) {
      setState(() {
        _verifiedInvite = null;
        _inviteErrorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isVerifyingInvite = false;
        });
      }
    }
  }

  void _resetInviteVerification() {
    setState(() {
      _verifiedInvite = null;
      _inviteCodeController.clear();
      _inviteErrorMessage = null;
      _errorMessage = null;
      _emailController.clear();
      _passwordController.clear();
    });
  }

  Future<void> _handleActivateAccount() async {
    setState(() {
      _submitted = true;
      _errorMessage = null;
    });

    if (_verifiedInvite == null) {
      await _handleVerifyInvite();
      if (_verifiedInvite == null) return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ref.read(authStateProvider.notifier).redeemInvite(
            code: _verifiedInvite!.code,
            email: _emailController.text,
            password: _passwordController.text,
            fullName: _fullNameController.text.isNotEmpty ? _fullNameController.text : _verifiedInvite!.targetName,
          );
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

  void _navigateToSignUp() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SignUpScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // 1. Navy Header with Logo & Brand Titles
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 48, bottom: 36, left: 20, right: 20),
                decoration: const BoxDecoration(
                  gradient: AppColors.navyGradient,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    const DistrictRingLogo(size: 88),
                    const SizedBox(height: 14),
                    Text(
                      AppStrings.appName,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.sourceSerif4(
                        fontSize: AppDimensions.fontSizeAppName,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppStrings.churchAreaName,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunitoSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.lightGold,
                      ),
                    ),
                  ],
                ),
              ),

              // 2. White Form Card
              Transform.translate(
                offset: const Offset(0, -18),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 480),
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: AppDimensions.cardBorderRadius,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      autovalidateMode: _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Selector: "I am logging in as"
                          Text(
                            'I am logging in as',
                            style: GoogleFonts.nunitoSans(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // 4 Role Chips (Responsive on 360px)
                          _buildRoleChips(),
                          const SizedBox(height: 16),

                          // General Error Banner if present
                          if (_errorMessage != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDE8E8),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                                  const SizedBox(width: 10),
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
                            const SizedBox(height: 14),
                          ],

                          // Render Form Based on Selected Role
                          if (_selectedRole == UserRole.member)
                            _buildMemberForm()
                          else if (_selectedRole == UserRole.pastor || _selectedRole == UserRole.ministryLeader)
                            _buildPastorLeaderForm()
                          else if (_selectedRole == UserRole.areaHead)
                            _buildAreaHeadForm(),
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
      ),
    );
  }

  /// 4 Role Selector Chips fitted on one single row for 360px phones
  Widget _buildRoleChips() {
    return Row(
      children: [
        _buildRoleChip(
          role: UserRole.member,
          label: 'Member',
          icon: Icons.person_outline,
        ),
        const SizedBox(width: 6),
        _buildRoleChip(
          role: UserRole.pastor,
          label: 'Pastor',
          icon: Icons.account_circle_outlined,
        ),
        const SizedBox(width: 6),
        _buildRoleChip(
          role: UserRole.ministryLeader,
          label: 'Leader',
          icon: Icons.groups_outlined,
        ),
        const SizedBox(width: 6),
        _buildRoleChip(
          role: UserRole.areaHead,
          label: 'Area Head',
          icon: Icons.shield_outlined,
        ),
      ],
    );
  }

  Widget _buildRoleChip({
    required UserRole role,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedRole == role;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onRoleChanged(role),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.navy : AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.navy : AppColors.border,
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? AppColors.white : AppColors.softGrey,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunitoSans(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? AppColors.white : AppColors.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 1. Member Form
  Widget _buildMemberForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Email Field
        AppTextField(
          label: AppStrings.email,
          hintText: AppStrings.emailPlaceholder,
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          prefixIcon: const Icon(Icons.email_outlined),
          validator: (value) {
            if (!_submitted) return null;
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your email address';
            }
            if (!value.contains('@') || !value.contains('.')) {
              return 'Please enter a valid email address';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),

        // Password Field
        AppTextField(
          label: AppStrings.password,
          hintText: AppStrings.passwordPlaceholder,
          controller: _passwordController,
          isPassword: true,
          prefixIcon: const Icon(Icons.lock_outline),
          validator: (value) {
            if (!_submitted) return null;
            if (value == null || value.isEmpty) {
              return 'Please enter your password';
            }
            return null;
          },
        ),
        const SizedBox(height: 6),

        // Forgot Password Link
        _buildForgotPasswordButton(),
        const SizedBox(height: 14),

        // Log In Button
        PrimaryButton(
          text: AppStrings.logIn,
          isLoading: _isLoading,
          onPressed: _handleLogin,
        ),
        const SizedBox(height: 18),

        // Divider with "New here?"
        Row(
          children: [
            const Expanded(child: Divider(color: AppColors.border, thickness: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Text(
                AppStrings.newHere,
                style: GoogleFonts.nunitoSans(
                  fontSize: 13,
                  color: AppColors.softGrey,
                ),
              ),
            ),
            const Expanded(child: Divider(color: AppColors.border, thickness: 1)),
          ],
        ),
        const SizedBox(height: 18),

        // Create Member Account Button (Gold Outlined)
        AppOutlineButton(
          text: AppStrings.createMemberAccount,
          onPressed: _navigateToSignUp,
        ),
      ],
    );
  }

  /// 2. Pastor & Ministry Leader Form with Toggle: Log in | I have an invite code
  Widget _buildPastorLeaderForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Two-Option Toggle Pill
        Container(
          width: double.infinity,
          height: 44,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2F6),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _onModeChanged(PastorLeaderAuthMode.login),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _pastorLeaderMode == PastorLeaderAuthMode.login ? AppColors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: _pastorLeaderMode == PastorLeaderAuthMode.login
                          ? Border.all(color: AppColors.gold, width: 1.2)
                          : null,
                      boxShadow: _pastorLeaderMode == PastorLeaderAuthMode.login
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Log in',
                      style: GoogleFonts.nunitoSans(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _pastorLeaderMode == PastorLeaderAuthMode.login ? AppColors.navy : AppColors.softGrey,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => _onModeChanged(PastorLeaderAuthMode.inviteCode),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _pastorLeaderMode == PastorLeaderAuthMode.inviteCode ? AppColors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: _pastorLeaderMode == PastorLeaderAuthMode.inviteCode
                          ? Border.all(color: AppColors.gold, width: 1.2)
                          : null,
                      boxShadow: _pastorLeaderMode == PastorLeaderAuthMode.inviteCode
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'I have an invite code',
                      style: GoogleFonts.nunitoSans(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _pastorLeaderMode == PastorLeaderAuthMode.inviteCode ? AppColors.navy : AppColors.softGrey,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (_pastorLeaderMode == PastorLeaderAuthMode.login) ...[
          // Option A: Log In Form
          AppTextField(
            label: AppStrings.email,
            hintText: AppStrings.emailPlaceholder,
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: const Icon(Icons.email_outlined),
            validator: (value) {
              if (!_submitted) return null;
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          AppTextField(
            label: AppStrings.password,
            hintText: AppStrings.passwordPlaceholder,
            controller: _passwordController,
            isPassword: true,
            prefixIcon: const Icon(Icons.lock_outline),
            validator: (value) {
              if (!_submitted) return null;
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              return null;
            },
          ),
          const SizedBox(height: 6),

          _buildForgotPasswordButton(),
          const SizedBox(height: 16),

          PrimaryButton(
            text: AppStrings.logIn,
            isLoading: _isLoading,
            onPressed: _handleLogin,
          ),
          const SizedBox(height: 18),

          // Note container: No account yet? Ask your Area Head
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F7FB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              'No account yet? Ask your Area Head to send you an invite code.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.softGrey,
              ),
            ),
          ),
        ] else ...[
          // Option B: Two-Step Invite Code Flow
          if (_verifiedInvite == null)
            _buildInviteStepOne()
          else
            _buildInviteStepTwo(),
        ],
      ],
    );
  }

  /// STEP 1: Code Entry & Verification
  Widget _buildInviteStepOne() {
    final codeText = _inviteCodeController.text.trim();
    final isCodeComplete = codeText.length == 11;
    final hasError = _inviteErrorMessage != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Full-width Invite Code Field
        AppTextField(
          label: 'Invite code',
          hintText: 'ABK-XXXX-XX',
          controller: _inviteCodeController,
          prefixIcon: const Icon(Icons.vpn_key_outlined),
          inputFormatters: [InviteCodeInputFormatter()],
          textCapitalization: TextCapitalization.characters,
          hasError: hasError,
          errorText: _inviteErrorMessage,
          suffixIcon: IconButton(
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.content_paste_outlined, size: 16, color: AppColors.navy),
                const SizedBox(width: 4),
                Text(
                  'Paste',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navy,
                  ),
                ),
              ],
            ),
            tooltip: 'Paste from Clipboard',
            onPressed: _handlePasteCode,
          ),
          onChanged: (val) {
            setState(() {
              _inviteErrorMessage = null;
            });
            // Auto-verify as soon as the code is complete (11 chars)
            if (val.length == 11) {
              _handleVerifyInvite();
            }
          },
        ),
        const SizedBox(height: 16),

        // Full-width Navy Verify Code Button
        PrimaryButton(
          text: 'Verify code',
          isLoading: _isVerifyingInvite,
          onPressed: (isCodeComplete && !_isVerifyingInvite) ? _handleVerifyInvite : null,
        ),
        const SizedBox(height: 16),

        // Help note
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F7FB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            'Invite codes are single-use and provided directly by the Area Head office.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunitoSans(
              fontSize: 12,
              color: AppColors.softGrey,
            ),
          ),
        ),
      ],
    );
  }

  /// STEP 2: Locked Code, Green Verification Card, & Account Activation Form
  Widget _buildInviteStepTwo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Locked Invite Code Display with "Change code" link
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.vpn_key, size: 18, color: AppColors.navy),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _verifiedInvite!.code,
                  style: GoogleFonts.nunitoSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: AppColors.navy,
                  ),
                ),
              ),
              const Icon(Icons.check_circle, color: AppColors.success, size: 20),
              const SizedBox(width: 8),
              TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: _resetInviteVerification,
                child: Text(
                  'Change code',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.gold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Green Card: Invitation Verified
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF7EE),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF34A853), width: 1.2),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invitation verified',
                      style: GoogleFonts.nunitoSans(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E4620),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _verifiedInvite!.roleDisplay,
                      style: GoogleFonts.nunitoSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Email Field
        AppTextField(
          label: AppStrings.email,
          hintText: 'kofi@example.com',
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          prefixIcon: const Icon(Icons.email_outlined),
          validator: (value) {
            if (!_submitted) return null;
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your email address';
            }
            if (!value.contains('@') || !value.contains('.')) {
              return 'Please enter a valid email address';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),

        // Create a Password Field
        AppTextField(
          label: 'Create a password',
          hintText: 'Choose a password',
          controller: _passwordController,
          isPassword: true,
          prefixIcon: const Icon(Icons.lock_outline),
          validator: (value) {
            if (!_submitted) return null;
            if (value == null || value.length < 6) {
              return 'Password must be at least 6 characters';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),

        // Activate My Account Button
        PrimaryButton(
          text: 'Activate my account',
          isLoading: _isLoading,
          onPressed: _handleActivateAccount,
        ),
      ],
    );
  }

  /// 3. Area Head Form
  Widget _buildAreaHeadForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Email Field
        AppTextField(
          label: AppStrings.email,
          hintText: AppStrings.emailPlaceholder,
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          prefixIcon: const Icon(Icons.email_outlined),
          validator: (value) {
            if (!_submitted) return null;
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your email address';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),

        // Password Field
        AppTextField(
          label: AppStrings.password,
          hintText: AppStrings.passwordPlaceholder,
          controller: _passwordController,
          isPassword: true,
          prefixIcon: const Icon(Icons.lock_outline),
          validator: (value) {
            if (!_submitted) return null;
            if (value == null || value.isEmpty) {
              return 'Please enter your password';
            }
            return null;
          },
        ),
        const SizedBox(height: 6),

        // Forgot Password Link
        _buildForgotPasswordButton(),
        const SizedBox(height: 16),

        // Log In Button
        PrimaryButton(
          text: AppStrings.logIn,
          isLoading: _isLoading,
          onPressed: _handleLogin,
        ),
      ],
    );
  }

  Widget _buildForgotPasswordButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please contact your Area Administrator to reset your password.'),
            ),
          );
        },
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(50, 30),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          AppStrings.forgotPassword,
          style: GoogleFonts.nunitoSans(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.gold,
          ),
        ),
      ),
    );
  }
}
