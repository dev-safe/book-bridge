import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Swipeable gallery of a listing's photos with page indicators.
///
/// [coverErrorBuilder] is used only for the first (cover) image so callers
/// can treat a broken cover as a broken listing; other photos fall back to a
/// placeholder icon.
class ListingImageCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final ImageErrorWidgetBuilder? coverErrorBuilder;

  const ListingImageCarousel({
    super.key,
    required this.imageUrls,
    this.coverErrorBuilder,
  });

  @override
  State<ListingImageCarousel> createState() => _ListingImageCarouselState();
}

class _ListingImageCarouselState extends State<ListingImageCarousel> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final urls = widget.imageUrls.where((u) => u.isNotEmpty).toList();
    if (urls.isEmpty) return _placeholder(context);

    final l10n = AppLocalizations.of(context)!;
    final page = _page.clamp(0, urls.length - 1);

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          key: const Key('listing-carousel'),
          itemCount: urls.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (context, i) => Semantics(
            image: true,
            label: l10n.photoOfTotal(i + 1, urls.length),
            child: Image.network(
              urls[i],
              fit: BoxFit.cover,
              errorBuilder: i == 0 && widget.coverErrorBuilder != null
                  ? widget.coverErrorBuilder
                  : (context, error, stackTrace) => _placeholder(context),
            ),
          ),
        ),
        if (urls.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: Row(
              key: const Key('listing-carousel-dots'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < urls.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == page ? 18 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == page
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 4),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Icon(
        Icons.image_not_supported,
        size: MediaQuery.of(context).size.height * 0.05,
        color: Theme.of(context).disabledColor,
      ),
    );
  }
}
