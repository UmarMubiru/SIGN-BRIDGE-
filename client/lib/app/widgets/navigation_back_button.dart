import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Visible navigation for desktop screens where routes may have no history.
class NavigationBackButton extends StatelessWidget {
  final bool enabled;

  const NavigationBackButton({super.key, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.canPop() ? 'Back' : 'Back to dashboard',
      onPressed: enabled
          ? () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/dashboard');
              }
            }
          : null,
      icon: const Icon(Icons.arrow_back),
    );
  }
}
