import 'package:flutter/material.dart';
import '../../config/app_colors.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final double borderRadius;
  final VoidCallback? onTap;
  final Gradient? gradient;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderRadius = 16,
    this.onTap,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: margin,
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: gradient,
          color: gradient == null ? (backgroundColor ?? AppColors.card) : null,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: child,
      ),
    );
  }
}
