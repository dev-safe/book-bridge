import 'package:flutter/material.dart';
import 'package:book_bridge/features/auth/domain/entities/user.dart';
import 'package:book_bridge/features/reviews/domain/entities/review_entity.dart';
import 'package:google_fonts/google_fonts.dart';

/// A premium, interactive widget displaying the seller's trust score,
/// gamified trust level badge, milestone progress, and ratings distribution.
class SellerTrustCard extends StatefulWidget {
  final User seller;
  final List<ReviewEntity> reviews;

  const SellerTrustCard({
    super.key,
    required this.seller,
    required this.reviews,
  });

  @override
  State<SellerTrustCard> createState() => _SellerTrustCardState();
}

class _SellerTrustCardState extends State<SellerTrustCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scoreAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _scoreAnimation =
        Tween<double>(
          begin: 0.0,
          end: widget.seller.trustScore.toDouble(),
        ).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );

    _animController.forward();
  }

  @override
  void didUpdateWidget(covariant SellerTrustCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seller.trustScore != widget.seller.trustScore) {
      _scoreAnimation =
          Tween<double>(
            begin: _scoreAnimation.value,
            end: widget.seller.trustScore.toDouble(),
          ).animate(
            CurvedAnimation(
              parent: _animController,
              curve: Curves.easeOutCubic,
            ),
          );
      _animController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // Helper to map trust level to display styling
  _TierStyle _getTierStyle(String level) {
    switch (level) {
      case 'Master':
        return _TierStyle(
          name: 'Master (Philanthropist)',
          badgeIcon: '👑',
          color: const Color(0xFFF2994A), // Sunset Golden-Orange
          bgColor: const Color(0xFFF2994A).withValues(alpha: 0.1),
        );
      case 'Elite':
        return _TierStyle(
          name: 'Elite (Bridge Builder)',
          badgeIcon: '⚡',
          color: const Color(0xFF27AE60), // Emerald Green
          bgColor: const Color(0xFF27AE60).withValues(alpha: 0.1),
        );
      case 'Scholar':
        return _TierStyle(
          name: 'Scholar (Verified Bookworm)',
          badgeIcon: '📘',
          color: const Color(0xFF1A4D8C), // Scholar Blue
          bgColor: const Color(0xFF1A4D8C).withValues(alpha: 0.1),
        );
      default:
        return _TierStyle(
          name: 'Seedling (Debutant)',
          badgeIcon: '🌱',
          color: Colors.grey[600]!,
          bgColor: Colors.grey[200]!,
        );
    }
  }

  String _getNextMilestoneText(int deals, double avgRating, String level) {
    if (level == 'Master') {
      return 'Ultimate trust tier achieved! 👑';
    } else if (level == 'Elite') {
      final List<String> requirements = [];
      if (deals < 15) {
        requirements.add('${15 - deals} more deal${15 - deals > 1 ? "s" : ""}');
      }
      if (avgRating < 4.7) {
        requirements.add('avg rating >= 4.7');
      }
      return 'Next: Master (Needs ${requirements.join(" & ")})';
    } else if (level == 'Scholar') {
      final List<String> requirements = [];
      if (deals < 8) {
        requirements.add('${8 - deals} more deal${8 - deals > 1 ? "s" : ""}');
      }
      if (avgRating < 4.5) {
        requirements.add('avg rating >= 4.5');
      }
      return 'Next: Elite (Needs ${requirements.join(" & ")})';
    } else {
      final List<String> requirements = [];
      if (deals < 3) {
        requirements.add('${3 - deals} more deal${3 - deals > 1 ? "s" : ""}');
      }
      if (avgRating < 4.2) {
        requirements.add('avg rating >= 4.2');
      }
      return 'Next: Scholar (Needs ${requirements.join(" & ")})';
    }
  }

  Map<int, int> _calculateDistribution(List<ReviewEntity> reviews) {
    final Map<int, int> distribution = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final r in reviews) {
      if (distribution.containsKey(r.rating)) {
        distribution[r.rating] = distribution[r.rating]! + 1;
      }
    }
    return distribution;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final style = _getTierStyle(widget.seller.trustLevel);
    final nextMilestone = _getNextMilestoneText(
      widget.seller.completedDealsCount,
      widget.seller.rating ?? 0.0,
      widget.seller.trustLevel,
    );

    final distribution = _calculateDistribution(widget.reviews);
    final totalReviews = widget.reviews.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 4,
      shadowColor: style.color.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: style.color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Trust Badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: style.bgColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: style.color.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        style.badgeIcon,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        style.name,
                        style: GoogleFonts.montserrat(
                          color: isDark ? Colors.white : style.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  '${widget.seller.completedDealsCount} deal${widget.seller.completedDealsCount != 1 ? 's' : ''}',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Circle Score Meter and Stats Summary
            Row(
              children: [
                // Score Meter with Animation
                AnimatedBuilder(
                  animation: _scoreAnimation,
                  builder: (context, child) {
                    final currentScore = _scoreAnimation.value;
                    return SizedBox(
                      width: 90,
                      height: 90,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(90, 90),
                            painter: _TrustScorePainter(
                              score: currentScore / 100.0,
                              color: style.color,
                              trackColor: isDark
                                  ? Colors.grey[800]!
                                  : Colors.grey[200]!,
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                currentScore.toInt().toString(),
                                style: GoogleFonts.montserrat(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                '/100',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 20),

                // Trust Level Info and Level Progress
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trust Score',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Calculated based on deals completed, buyer reviews, and rating consistency.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Milestone progress banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.flag_rounded, size: 16, color: style.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      nextMilestone,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Expandable rating breakdown trigger
            InkWell(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 8.0,
                  horizontal: 4.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Rating Distribution',
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),

            // Expanded content (Bar chart)
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _isExpanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
                      child: Column(
                        children: [
                          for (int rating = 5; rating >= 1; rating--) ...[
                            _buildDistributionRow(
                              context,
                              rating,
                              distribution[rating] ?? 0,
                              totalReviews,
                              style.color,
                            ),
                            if (rating > 1) const SizedBox(height: 8),
                          ],
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionRow(
    BuildContext context,
    int stars,
    int count,
    int total,
    Color activeColor,
  ) {
    final theme = Theme.of(context);
    final percentage = total > 0 ? (count / total) : 0.0;

    return Row(
      children: [
        SizedBox(
          width: 30,
          child: Text(
            '$stars ★',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: theme.brightness == Brightness.dark
                  ? Colors.grey[850]
                  : Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(activeColor),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 30,
          child: Text(
            count.toString(),
            textAlign: Alignment.centerRight.x > 0
                ? TextAlign.right
                : TextAlign.left,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _TierStyle {
  final String name;
  final String badgeIcon;
  final Color color;
  final Color bgColor;

  _TierStyle({
    required this.name,
    required this.badgeIcon,
    required this.color,
    required this.bgColor,
  });
}

class _TrustScorePainter extends CustomPainter {
  final double score; // 0.0 to 1.0
  final Color color;
  final Color trackColor;

  _TrustScorePainter({
    required this.score,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 8.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Draw track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    // Draw progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708, // start from top
      6.28318 * score,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TrustScorePainter oldDelegate) {
    return oldDelegate.score != score ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor;
  }
}
