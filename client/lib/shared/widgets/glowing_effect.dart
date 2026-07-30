import 'package:flutter/material.dart';

class GlowingEffect extends StatefulWidget {
  final Widget child;
  final bool isGlowing;
  final Color color;

  const GlowingEffect({
    super.key,
    required this.child,
    this.isGlowing = true,
    this.color = Colors.blue,
  });

  @override
  State<GlowingEffect> createState() => _GlowingEffectState();
}

class _GlowingEffectState extends State<GlowingEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.isGlowing) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(GlowingEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isGlowing != oldWidget.isGlowing) {
      if (widget.isGlowing) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isGlowing) return widget.child;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.6 * (1.0 - _animation.value)),
                blurRadius: 20 * _animation.value,
                spreadRadius: 10 * _animation.value,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
