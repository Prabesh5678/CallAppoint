import 'package:flutter/material.dart';

/// A widget that keeps content centered and limits its maximum width on wide screens.
/// Ideal for forms and detail screens on Web/Desktop.
class CenteredConstrainedBox extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const CenteredConstrainedBox({
    super.key,
    required this.child,
    this.maxWidth = 800,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? EdgeInsets.zero,
          child: child,
        ),
      ),
    );
  }
}
