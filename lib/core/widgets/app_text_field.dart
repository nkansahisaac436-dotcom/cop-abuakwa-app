import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';

/// Standard AppTextField with always-visible bold label and consistent styling
class AppTextField extends StatefulWidget {
  final String label;
  final String? hintText;
  final TextEditingController? controller;
  final String? initialValue;
  final bool isPassword;
  final TextInputType keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool enabled;
  final bool hasError;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final int maxLines;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final FocusNode? focusNode;

  const AppTextField({
    super.key,
    required this.label,
    this.hintText,
    this.controller,
    this.initialValue,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
    this.hasError = false,
    this.errorText,
    this.onChanged,
    this.validator,
    this.maxLines = 1,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.focusNode,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Always-visible bold label
        Text(
          widget.label,
          style: GoogleFonts.nunitoSans(
            fontSize: AppDimensions.fontSizeLabel,
            fontWeight: FontWeight.bold,
            color: widget.enabled ? AppColors.text : AppColors.softGrey,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(minHeight: AppDimensions.minTouchTarget),
          child: TextFormField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            initialValue: widget.initialValue,
            enabled: widget.enabled,
            obscureText: widget.isPassword ? _obscureText : false,
            keyboardType: widget.keyboardType,
            textCapitalization: widget.textCapitalization,
            inputFormatters: widget.inputFormatters,
            maxLines: widget.isPassword ? 1 : widget.maxLines,
            onChanged: widget.onChanged,
            validator: widget.validator,
            style: GoogleFonts.nunitoSans(
              fontSize: AppDimensions.fontSizeInput,
              color: widget.enabled ? AppColors.text : AppColors.disabledText,
            ),
            decoration: InputDecoration(
              hintText: widget.hintText,
              filled: true,
              fillColor: widget.enabled ? AppColors.white : AppColors.disabled,
              prefixIcon: widget.prefixIcon != null
                  ? IconTheme(
                      data: IconThemeData(
                        color: widget.enabled ? AppColors.softGrey : AppColors.disabledText,
                        size: 20,
                      ),
                      child: widget.prefixIcon!,
                    )
                  : null,
              suffixIcon: widget.isPassword
                  ? IconButton(
                      icon: Icon(
                        _obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: AppColors.softGrey,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureText = !_obscureText;
                        });
                      },
                    )
                  : widget.suffixIcon,
              border: OutlineInputBorder(
                borderRadius: AppDimensions.inputBorderRadius,
                borderSide: BorderSide(
                  color: widget.hasError ? AppColors.error : AppColors.border,
                  width: widget.hasError ? 1.8 : 1.2,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppDimensions.inputBorderRadius,
                borderSide: BorderSide(
                  color: widget.hasError ? AppColors.error : AppColors.border,
                  width: widget.hasError ? 1.8 : 1.2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppDimensions.inputBorderRadius,
                borderSide: BorderSide(
                  color: widget.hasError ? AppColors.error : AppColors.navy,
                  width: 1.8,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: AppDimensions.inputBorderRadius,
                borderSide: BorderSide(
                  color: widget.hasError ? AppColors.error : AppColors.border.withValues(alpha: 0.6),
                  width: 1.0,
                ),
              ),
            ),
          ),
        ),
        if (widget.errorText != null && widget.errorText!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            widget.errorText!,
            style: GoogleFonts.nunitoSans(
              fontSize: AppDimensions.fontSizeSubtext,
              color: AppColors.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
