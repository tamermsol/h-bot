import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SmartInputField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final String? label;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;
  final String? Function(String?)? validator;
  final IconData? iconData;       // legacy: named parameter
  final Widget? prefixIcon;       // new: widget-based prefix
  final Widget? suffixIcon;
  final VoidCallback? onSuffixIconPressed;
  final bool obscureText;
  final TextInputType keyboardType;
  final int maxLines;
  final TextCapitalization textCapitalization;
  final bool enabled;

  const SmartInputField({
    super.key,
    required this.controller,
    String? hintText,
    this.label,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.iconData,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixIconPressed,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
    this.enabled = true,
  }) : hintText = hintText ?? label ?? '';

  @override
  State<SmartInputField> createState() => _SmartInputFieldState();
}

class _SmartInputFieldState extends State<SmartInputField> {
  bool _isFocused = false;

  Widget? get _resolvedPrefixIcon {
    if (widget.prefixIcon != null) return widget.prefixIcon;
    if (widget.iconData != null) {
      return Icon(
        widget.iconData,
        color: _isFocused ? HBotColors.primary : HBotColors.iconDefault,
        size: 20,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label above input
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: HBotColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: HBotSpacing.space1),
        ],

        // Input container
        Container(
          decoration: BoxDecoration(
            color: HBotColors.surfaceLight,
            borderRadius: HBotRadius.smallRadius,
            border: Border.all(
              color: _isFocused
                  ? HBotColors.primary
                  : HBotColors.borderLight,
              width: _isFocused ? 2 : 1.5,
            ),
            boxShadow: _isFocused ? HBotShadows.glow : null,
          ),
          child: Focus(
            onFocusChange: (hasFocus) {
              setState(() => _isFocused = hasFocus);
            },
            child: TextFormField(
              controller: widget.controller,
              onChanged: widget.onChanged,
              onFieldSubmitted: widget.onSubmitted,
              validator: widget.validator,
              obscureText: widget.obscureText,
              keyboardType: widget.keyboardType,
              maxLines: widget.maxLines,
              textCapitalization: widget.textCapitalization,
              enabled: widget.enabled,
              style: const TextStyle(
                fontFamily: 'Inter',
                color: HBotColors.textPrimaryLight,
                fontSize: 16,
                fontWeight: FontWeight.w400,
                letterSpacing: 0,
              ),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: const TextStyle(
                  fontFamily: 'Inter',
                  color: HBotColors.textTertiaryLight,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: HBotSpacing.space4,
                  vertical: 14,
                ),
                prefixIcon: _resolvedPrefixIcon,
                prefixIconColor: _isFocused ? HBotColors.primary : HBotColors.iconDefault,
                suffixIcon: widget.suffixIcon,
                suffixIconColor: HBotColors.iconDefault,
                errorStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: HBotColors.error,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
