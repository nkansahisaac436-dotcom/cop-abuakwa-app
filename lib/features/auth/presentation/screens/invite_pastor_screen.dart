import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../districts/domain/models/district_model.dart';
import '../../../districts/presentation/providers/districts_provider.dart';
import '../providers/auth_provider.dart';

class InvitePastorScreen extends ConsumerStatefulWidget {
  const InvitePastorScreen({super.key});

  @override
  ConsumerState<InvitePastorScreen> createState() => _InvitePastorScreenState();
}

class _InvitePastorScreenState extends ConsumerState<InvitePastorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  DistrictModel? _selectedDistrict;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleInvite() async {
    if (_selectedDistrict == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a district for this pastor.')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await ref.read(authRepositoryProvider).invitePastor(
            fullName: _nameController.text,
            email: _emailController.text,
            districtId: _selectedDistrict!.id,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Invitation sent to Pastor ${_nameController.text} for ${_selectedDistrict!.name}. Tenure initiated.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invite District Pastor'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: AppDimensions.cardBorderRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pastor Appointment & Tenure',
                  style: GoogleFonts.sourceSerif4(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'The invited pastor will receive login credentials and become the active district minister with a new tenure record.',
                  style: GoogleFonts.nunitoSans(fontSize: 13, color: AppColors.softGrey),
                ),
                const SizedBox(height: 20),

                // Pastor Full Name
                AppTextField(
                  label: "Pastor's Full Name",
                  hintText: 'Pastor Enoch Agyemang',
                  controller: _nameController,
                  prefixIcon: const Icon(Icons.person_outline),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Enter full name';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Pastor Email
                AppTextField(
                  label: "Pastor's Official Email",
                  hintText: 'pastor.agyemang@copabuakwa.org',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: const Icon(Icons.mail_outline),
                  validator: (val) {
                    if (val == null || !val.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // District Dropdown
                Text(
                  'Assigned District',
                  style: GoogleFonts.nunitoSans(
                    fontSize: AppDimensions.fontSizeLabel,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 6),
                districtsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Error loading districts: $e'),
                  data: (districts) {
                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: AppDimensions.inputBorderRadius,
                        border: Border.all(color: AppColors.border, width: 1.2),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<DistrictModel>(
                          isExpanded: true,
                          value: _selectedDistrict,
                          hint: Text(
                            'Select District',
                            style: GoogleFonts.nunitoSans(
                              fontSize: AppDimensions.fontSizeInput,
                              color: AppColors.softGrey,
                            ),
                          ),
                          items: districts.map((d) {
                            return DropdownMenuItem<DistrictModel>(
                              value: d,
                              child: Row(
                                children: [
                                  Text(
                                    d.name,
                                    style: GoogleFonts.nunitoSans(
                                      fontSize: AppDimensions.fontSizeInput,
                                      color: AppColors.text,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (d.isInactive)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.warningFill,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Inactive',
                                        style: GoogleFonts.nunitoSans(
                                          fontSize: 10,
                                          color: AppColors.warningText,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedDistrict = val;
                            });
                          },
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 28),

                PrimaryButton(
                  text: 'Send Pastor Invitation',
                  isLoading: _isLoading,
                  onPressed: _handleInvite,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
