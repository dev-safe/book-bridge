import 'package:flutter/material.dart';
import 'package:book_bridge/core/theme/app_theme.dart';

class PulseHeartIcon extends StatefulWidget {
  const PulseHeartIcon({super.key});

  @override
  State<PulseHeartIcon> createState() => _PulseHeartIconState();
}

class _PulseHeartIconState extends State<PulseHeartIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.bridgeOrange.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.bridgeOrange.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
          ),
          const Icon(Icons.favorite, size: 48, color: AppTheme.bridgeOrange),
        ],
      ),
    );
  }
}
