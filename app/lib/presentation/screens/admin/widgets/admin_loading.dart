import 'package:flutter/material.dart';
import '../../../../config/app_colors.dart';

class AdminLoading extends StatelessWidget {
  final String? message;

  const AdminLoading({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}
