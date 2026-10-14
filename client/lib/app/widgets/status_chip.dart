import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

enum StatusType { success, warning, error, info, pending }

class StatusChip extends StatelessWidget {
  final String label;
  final StatusType type;

  const StatusChip({super.key, required this.label, required this.type});

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;

    switch (type) {
      case StatusType.success:
        backgroundColor = AppTheme.teal.withValues(alpha: 0.16);
        textColor = AppTheme.success;
        break;
      case StatusType.warning:
        backgroundColor = AppTheme.warning.withValues(alpha: 0.16);
        textColor = AppTheme.warning;
        break;
      case StatusType.error:
        backgroundColor = AppTheme.error.withValues(alpha: 0.15);
        textColor = AppTheme.error;
        break;
      case StatusType.info:
        backgroundColor = AppTheme.supportingCyan.withValues(alpha: 0.15);
        textColor = AppTheme.supportingCyan;
        break;
      case StatusType.pending:
        backgroundColor = AppTheme.mutedText.withValues(alpha: 0.12);
        textColor = AppTheme.mutedText;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          letterSpacing: 0.1,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
