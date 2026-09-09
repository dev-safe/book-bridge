import 'package:book_bridge/core/theme/app_theme.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/sell_viewmodel.dart';
import 'package:book_bridge/features/listings/domain/entities/listing.dart';
import 'package:book_bridge/features/listings/domain/entities/book_condition.dart';
import 'package:book_bridge/core/constants/categories.dart';

/// Screen for creating and selling a new book listing.
///
/// This screen provides a form for users to input book details,
/// select a condition, upload an image, and create a new listing.
class SellScreen extends StatefulWidget {
  final Listing? listing;

  const SellScreen({super.key, this.listing});

  @override
  State<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends State<SellScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Save reference to avoid accessing context in dispose()
  late SellViewModel _sellViewModel;

  @override
  void initState() {
    super.initState();
    // Add a listener to handle UI feedback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sellViewModel = context.read<SellViewModel>();
      _sellViewModel.addListener(_onSellStateChanged);

      // If we're editing a listing, populate the view model and controllers
      if (widget.listing != null) {
        _sellViewModel.setEditingListing(widget.listing!);
        _titleController.text = widget.listing!.title;
        _authorController.text = widget.listing!.author;
        _priceController.text = widget.listing!.priceFcfa.toString();
        _descriptionController.text = widget.listing!.description;
      } else {
        // Otherwise reset the form to start fresh
        _sellViewModel.resetForm();
      }
    });
  }

  @override
  void dispose() {
    // Remove the listener before disposing using saved reference
    _sellViewModel.removeListener(_onSellStateChanged);
    _titleController.dispose();
    _authorController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onSellStateChanged() {
    // Check if the widget is still mounted before accessing context
    if (!mounted) return;

    final sellViewModel = context.read<SellViewModel>();
    if (sellViewModel.sellState == SellState.success) {
      final message = sellViewModel.isEditing
          ? AppLocalizations.of(context)!.sellSuccessUpdate
          : AppLocalizations.of(context)!.sellSuccessCreate;

      // Show the snackbar first
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      // Reset form fields and state
      sellViewModel.resetForm();
      // Navigate away after a short delay to ensure UI updates
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Check again if still mounted before navigating
          context.go('/home'); // Navigate away after success
        }
      });
    } else if (sellViewModel.sellState == SellState.error &&
        sellViewModel.errorMessage != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(sellViewModel.errorMessage!),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      sellViewModel.clearState(); // Clear error after showing
    }
  }

  /// Shows a dialog for selecting image source (gallery or camera).
  void _showImageSelectionDialog(
    BuildContext context,
    SellViewModel viewModel,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.selectImageSource),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(AppLocalizations.of(context)!.gallery),
                onTap: () async {
                  Navigator.of(context).pop(); // Close dialog
                  await viewModel.pickImageFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text(AppLocalizations.of(context)!.camera),
                onTap: () async {
                  Navigator.of(context).pop(); // Close dialog
                  await viewModel.pickImageFromCamera();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
          ],
        );
      },
    );
  }

  String _getLocalizedCategory(BuildContext context, String categoryName) {
    final l10n = AppLocalizations.of(context)!;
    switch (categoryName) {
      case 'Textbooks':
        return l10n.categoryTextbooks;
      case 'Fiction':
        return l10n.categoryFiction;
      case 'Science':
        return l10n.categoryScience;
      case 'History':
        return l10n.categoryHistory;
      case 'GCE':
        return l10n.categoryGCE;
      case 'Business':
        return l10n.categoryBusiness;
      case 'Technology':
        return l10n.categoryTechnology;
      case 'Arts':
        return l10n.categoryArts;
      case 'Language':
        return l10n.categoryLanguage;
      case 'Mathematics':
        return l10n.categoryMathematics;
      case 'Engineering':
        return l10n.categoryEngineering;
      case 'Medicine':
        return l10n.categoryMedicine;
      default:
        return categoryName;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.listing != null
              ? AppLocalizations.of(context)!.editListing
              : AppLocalizations.of(context)!.sellABook,
        ),
        centerTitle: true,
      ),
      body: Consumer<SellViewModel>(
        builder: (context, viewModel, child) {
          final theme = Theme.of(context);
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      _showImageSelectionDialog(context, viewModel);
                    },
                    child: Container(
                      width: double.infinity,
                      height:
                          MediaQuery.of(context).size.height *
                          0.25, // Responsive height
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.outlineVariant.withValues(alpha: 0.2),
                          width: 2,
                        ),
                      ),
                      child: viewModel.isLoading && viewModel.imageUrl == null
                          ? const Center(child: CircularProgressIndicator())
                          : viewModel.imageUrl != null &&
                                viewModel.imageUrl!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                viewModel.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildImagePlaceholder();
                                },
                              ),
                            )
                          : _buildImagePlaceholder(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Book Title
                  Text(
                    AppLocalizations.of(context)!.bookTitleLabel,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.bookTitleHint,
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context)!.bookTitleRequired;
                      }
                      return null;
                    },
                    onChanged: viewModel.setTitle,
                  ),
                  const SizedBox(height: 24),

                  // Author
                  Text(
                    AppLocalizations.of(context)!.authorLabel,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _authorController,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.authorHint,
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context)!.authorRequired;
                      }
                      return null;
                    },
                    onChanged: viewModel.setAuthor,
                  ),
                  const SizedBox(height: 24),

                  // Price
                  Text(
                    AppLocalizations.of(context)!.priceLabel,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)!.priceHint,
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(8),
                                bottomLeft: Radius.circular(8),
                              ),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return AppLocalizations.of(
                                context,
                              )!.priceRequired;
                            }
                            final price = int.tryParse(value);
                            if (price == null || price <= 0) {
                              return AppLocalizations.of(context)!.priceInvalid;
                            }
                            return null;
                          },
                          onChanged: (value) {
                            final price = int.tryParse(value);
                            if (price != null) {
                              viewModel.setPrice(price);
                            }
                          },
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(8),
                            bottomRight: Radius.circular(8),
                          ),
                        ),
                        child: const Icon(Icons.payments, size: 24),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Description
                  Text(
                    AppLocalizations.of(context)!.descriptionFieldLabel,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(
                        context,
                      )!.descriptionFieldHint,
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    onChanged: viewModel.setDescription,
                  ),
                  const SizedBox(height: 24),

                  // Condition
                  Text(
                    AppLocalizations.of(context)!.bookConditionLabel,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).textTheme.titleLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<BookCondition>(
                        value: viewModel.condition,
                        isExpanded: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        items: [
                          DropdownMenuItem(
                            value: BookCondition.brandNew,
                            child: Text(
                              AppLocalizations.of(context)!.conditionNew,
                            ),
                          ),
                          DropdownMenuItem(
                            value: BookCondition.likeNew,
                            child: Text(
                              AppLocalizations.of(context)!.conditionLikeNew,
                            ),
                          ),
                          DropdownMenuItem(
                            value: BookCondition.good,
                            child: Text(
                              AppLocalizations.of(context)!.conditionGood,
                            ),
                          ),
                          DropdownMenuItem(
                            value: BookCondition.fair,
                            child: Text(
                              AppLocalizations.of(context)!.conditionFair,
                            ),
                          ),
                          DropdownMenuItem(
                            value: BookCondition.poor,
                            child: Text(
                              AppLocalizations.of(context)!.conditionPoor,
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            viewModel.setCondition(value);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Category
                  Text(
                    AppLocalizations.of(context)!.categoryLabel,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: viewModel.category,
                        isExpanded: true,
                        menuMaxHeight: 350,
                        hint: Text(
                          AppLocalizations.of(context)!.selectCategoryHint,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text(AppLocalizations.of(context)!.none),
                          ),
                          ...appCategories.map(
                            (cat) => DropdownMenuItem(
                              value: cat.name,
                              child: Text(
                                _getLocalizedCategory(context, cat.name),
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          viewModel.setCategory(value);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Social Venture Section
                  Text(
                    AppLocalizations.of(context)!.socialVentureFeatures,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).textTheme.titleLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Seller Type
                  Text(
                    AppLocalizations.of(context)!.sellerTypeLabel,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: viewModel.sellerType,
                        isExpanded: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        items: [
                          DropdownMenuItem(
                            value: 'individual',
                            child: Text(
                              AppLocalizations.of(
                                context,
                              )!.sellerTypeIndividual,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'bookshop',
                            child: Text(
                              AppLocalizations.of(context)!.sellerTypeBookshop,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'author',
                            child: Text(
                              AppLocalizations.of(context)!.sellerTypeAuthor,
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            viewModel.setSellerType(value);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Buy-Back Eligibility
                  SwitchListTile(
                    title: Text(
                      AppLocalizations.of(context)!.eligibleForBuyBack,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    subtitle: Text(
                      AppLocalizations.of(context)!.buyBackSwitchDesc,
                      style: TextStyle(fontSize: 12, color: theme.hintColor),
                    ),
                    value: viewModel.isBuyBackEligible,
                    onChanged: viewModel.setIsBuyBackEligible,
                    activeTrackColor: AppTheme.scholarBlue.withValues(
                      alpha: 0.5,
                    ),
                    activeThumbColor: AppTheme.scholarBlue,
                  ),
                  const SizedBox(height: 16),
                  // Stock Count (for non-individuals)
                  if (viewModel.sellerType != 'individual') ...[
                    Text(
                      AppLocalizations.of(context)!.availableStockLabel,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: viewModel.stockCount.toString(),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)!.stockHint,
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      onChanged: (value) {
                        final stock = int.tryParse(value);
                        if (stock != null) {
                          viewModel.setStockCount(stock);
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                  const SizedBox(height: 16),

                  // Location info
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context)!.locationInfo,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Post Listing button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: viewModel.isLoading
                          ? null
                          : () {
                              if (_formKey.currentState!.validate()) {
                                if (viewModel.isEditing) {
                                  viewModel.updateListing();
                                } else {
                                  viewModel.createListing();
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.scholarBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      child: viewModel.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              viewModel.isEditing
                                  ? AppLocalizations.of(
                                      context,
                                    )!.updateListingButton
                                  : AppLocalizations.of(
                                      context,
                                    )!.postListingButton,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_a_photo,
          size: MediaQuery.of(context).size.width * 0.15, // Responsive size
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 8),
        Text(
          AppLocalizations.of(context)!.addBookPhotos,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(
              context,
            ).textTheme.bodyLarge?.color?.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;

  DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.gap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final Path path = Path();

    // Top border
    _drawDashedLine(path, 0, 0, size.width, 0);
    // Right border
    _drawDashedLine(path, size.width, 0, size.width, size.height);
    // Bottom border
    _drawDashedLine(path, size.width, size.height, 0, size.height);
    // Left border
    _drawDashedLine(path, 0, size.height, 0, 0);

    canvas.drawPath(path, paint);
  }

  void _drawDashedLine(
    Path path,
    double startX,
    double startY,
    double endX,
    double endY,
  ) {
    final dx = endX - startX;
    final dy = endY - startY;
    final length = sqrt(dx * dx + dy * dy);

    var currentX = startX;
    var currentY = startY;

    var drawSegment = true;
    while (true) {
      final segmentLength = drawSegment ? strokeWidth * 3 : gap;
      if (segmentLength > length) {
        path.lineTo(endX, endY);
        break;
      }

      final fraction = segmentLength / length;
      final nextX = currentX + dx * fraction;
      final nextY = currentY + dy * fraction;

      if (drawSegment) {
        path.moveTo(currentX, currentY);
        path.lineTo(nextX, nextY);
      } else {
        path.moveTo(nextX, nextY);
      }

      currentX = nextX;
      currentY = nextY;

      final remainingLength = sqrt(
        (endX - currentX) * (endX - currentX) +
            (endY - currentY) * (endY - currentY),
      );
      if (remainingLength < gap) {
        break;
      }

      drawSegment = !drawSegment;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
