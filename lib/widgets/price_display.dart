import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PriceDisplay extends StatelessWidget {
  final double amount;
  final String currency;
  final bool showCents;
  final TextStyle? textStyle;

  const PriceDisplay({
    super.key,
    required this.amount,
    this.currency = '\$',
    this.showCents = false,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: currency,
            style: (textStyle ?? AppTheme.priceTextStyle).copyWith(
              fontSize: (textStyle?.fontSize ?? 17) * 0.8,
              color: AppTheme.textSecondary,
            ),
          ),
          TextSpan(
            text: _formatAmount(amount),
            style: textStyle ?? AppTheme.priceTextStyle,
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    if (showCents) {
      return amount.toStringAsFixed(2).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
    } else {
      return amount.toInt().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
    }
  }
}
