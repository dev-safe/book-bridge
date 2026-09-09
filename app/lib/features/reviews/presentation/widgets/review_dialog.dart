import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:book_bridge/features/reviews/presentation/viewmodels/review_viewmodel.dart';
import 'package:book_bridge/l10n/app_localizations.dart';

class ReviewDialog extends StatefulWidget {
  final String reviewerId;
  final String revieweeId;
  final String listingId;
  final String transactionId;
  final String listingTitle;

  const ReviewDialog({
    super.key,
    required this.reviewerId,
    required this.revieweeId,
    required this.listingId,
    required this.transactionId,
    required this.listingTitle,
  });

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Consumer<ReviewViewModel>(
          builder: (context, viewModel, child) {
            if (viewModel.state == ReviewState.success) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    l10n.reviewSubmitted,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      l10n.cancel,
                    ), // Reusing 'cancel' as 'close' if 'close' is missing
                  ),
                ],
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.rateYourExperience,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${l10n.howWasTransaction} "${widget.listingTitle}"?',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final starIndex = index + 1;
                    return IconButton(
                      icon: Icon(
                        viewModel.rating >= starIndex
                            ? Icons.star
                            : Icons.star_border,
                        color: Colors.amber,
                        size: 32,
                      ),
                      onPressed: () => viewModel.setRating(starIndex),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _commentController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: l10n.leaveAComment,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                if (viewModel.error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    viewModel.error!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.close),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: viewModel.state == ReviewState.submitting
                          ? null
                          : () {
                              viewModel.submitReview(
                                reviewerId: widget.reviewerId,
                                revieweeId: widget.revieweeId,
                                listingId: widget.listingId,
                                transactionId: widget.transactionId,
                                comment: _commentController.text,
                              );
                            },
                      child: viewModel.state == ReviewState.submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.reviewSubmit),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
