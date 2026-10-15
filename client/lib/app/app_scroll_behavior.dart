import 'package:flutter/material.dart';

/// Keep a visible vertical scrollbar so desktop users can reach page actions
/// that sit below the window's current viewport.
class SignBridgeScrollBehavior extends MaterialScrollBehavior {
  const SignBridgeScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    if ((details.direction == AxisDirection.down ||
            details.direction == AxisDirection.up) &&
        details.controller != null) {
      return Scrollbar(
        controller: details.controller,
        thumbVisibility: true,
        child: child,
      );
    }
    return super.buildScrollbar(context, child, details);
  }
}
