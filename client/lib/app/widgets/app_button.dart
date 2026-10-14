import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isSecondary;
  final IconData? icon;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isSecondary = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final button = ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isSecondary
            ? AppTheme.secondarySurface
            : Colors.transparent,
        foregroundColor: AppTheme.ivory,
        disabledForegroundColor: AppTheme.mutedText,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: isSecondary
              ? const BorderSide(color: AppTheme.outline)
              : BorderSide.none,
        ),
        disabledBackgroundColor: isSecondary
            ? AppTheme.secondarySurface
            : Colors.transparent,
      ),
      child: isLoading
          ? SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: isSecondary ? AppTheme.gold : AppTheme.primaryBackground,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(text),
              ],
            ),
    );

    if (isSecondary) return button;

    return Container(
      decoration: BoxDecoration(
        gradient: enabled
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFB900), Color(0xFFFF6900)],
              )
            : null,
        color: enabled ? null : AppTheme.raisedSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: enabled ? const Color(0xFFFFA000) : AppTheme.outline,
        ),
      ),
      child: button,
    );
  }
}
