import 'package:flutter/material.dart';

class AdminStatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool small;

  const AdminStatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 10,
        vertical: small ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: small ? 10 : 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
