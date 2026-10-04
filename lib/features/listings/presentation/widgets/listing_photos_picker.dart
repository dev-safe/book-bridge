import 'package:flutter/material.dart';

import 'package:book_bridge/l10n/app_localizations.dart';

/// Photo picker for the sell form: a large cover preview plus a row of
/// thumbnails. Tapping a thumbnail makes it the cover; the x removes it.
class ListingPhotosPicker extends StatelessWidget {
  final List<String> imageUrls;
  final int maxImages;
  final bool isUploading;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final ValueChanged<int> onSetCover;

  const ListingPhotosPicker({
    super.key,
    required this.imageUrls,
    required this.maxImages,
    required this.isUploading,
    required this.onAdd,
    required this.onRemove,
    required this.onSetCover,
  });

  bool get _canAdd => imageUrls.length < maxImages;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final height = MediaQuery.of(context).size.height * 0.25;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: imageUrls.isEmpty && !isUploading ? onAdd : null,
          child: Container(
            width: double.infinity,
            height: height,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: imageUrls.isEmpty
                ? (isUploading
                      ? const Center(child: CircularProgressIndicator())
                      : _Placeholder(label: l10n.addBookPhotos))
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          imageUrls.first,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _Placeholder(label: l10n.addBookPhotos),
                        ),
                      ),
                      Positioned(
                        left: 8,
                        top: 8,
                        child: _CoverBadge(label: l10n.coverPhotoLabel),
                      ),
                    ],
                  ),
          ),
        ),
        if (imageUrls.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 72,
            child: Row(
              children: [
                for (var i = 0; i < imageUrls.length; i++) ...[
                  _Thumbnail(
                    key: ValueKey('photo-thumb-$i'),
                    url: imageUrls[i],
                    isCover: i == 0,
                    removeTooltip: l10n.removePhoto,
                    onTap: () => onSetCover(i),
                    onRemove: () => onRemove(i),
                  ),
                  const SizedBox(width: 8),
                ],
                if (_canAdd)
                  _AddTile(
                    key: const ValueKey('photo-add'),
                    tooltip: l10n.addPhoto,
                    isUploading: isUploading,
                    onTap: isUploading ? null : onAdd,
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          l10n.photoCountHint(maxImages),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String label;

  const _Placeholder({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final widthBased = MediaQuery.of(context).size.width * 0.15;
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_a_photo,
            // Keep icon + label inside short boxes (tablets, landscape).
            size: constraints.hasBoundedHeight
                ? widthBased.clamp(0.0, constraints.maxHeight * 0.5)
                : widthBased,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverBadge extends StatelessWidget {
  final String label;

  const _CoverBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String url;
  final bool isCover;
  final String removeTooltip;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _Thumbnail({
    super.key,
    required this.url,
    required this.isCover,
    required this.removeTooltip,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCover
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
                    width: isCover ? 2 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Material(
              color: theme.colorScheme.surface.withValues(alpha: 0.85),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRemove,
                child: Tooltip(
                  message: removeTooltip,
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.close, size: 16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  final String tooltip;
  final bool isUploading;
  final VoidCallback? onTap;

  const _AddTile({
    super.key,
    required this.tooltip,
    required this.isUploading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Center(
            child: isUploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.add_photo_alternate_outlined,
                    color: theme.colorScheme.primary,
                  ),
          ),
        ),
      ),
    );
  }
}
