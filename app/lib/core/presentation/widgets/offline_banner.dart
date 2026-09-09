import 'package:flutter/material.dart';

/// A non-intrusive amber banner displayed at the top of the home feed
/// when listings are being served from the local SQLite cache.
///
/// Slides into view with an [AnimatedSize] transition so the layout
/// adjusts smoothly without jarring jumps.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          color: Color(0xFFFFF3CD),
          border: Border(
            bottom: BorderSide(color: Color(0xFFF2994A), width: 1.5),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 18,
              color: Color(0xFFB7791F),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "You're offline — showing saved results",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF92400E),
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
