import 'package:flutter/material.dart';
import '../../../../config/app_colors.dart';

class AdminSectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  const AdminSectionTitle({
    super.key,
    required this.title,
    this.trailing,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
