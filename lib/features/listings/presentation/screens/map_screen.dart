import 'package:book_bridge/features/listings/domain/entities/listing.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/home_viewmodel.dart';
import 'package:book_bridge/features/listings/presentation/widgets/radius_filter_bar.dart';
import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

const _osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const _userAgentPackageName = 'cm.devsafe.bookbridge';

/// Map of nearby pickup locations, centred on the user, with the active
/// distance radius drawn as a circle.
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final viewModel = context.watch<HomeViewModel>();
    final position = viewModel.currentPosition;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.mapViewTitle)),
      body: position == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.mapNeedsLocation, textAlign: TextAlign.center),
              ),
            )
          : Column(
              children: [
                RadiusFilterBar(
                  selectedKm: viewModel.radiusKm,
                  onChanged: viewModel.setRadiusKm,
                ),
                Expanded(
                  child: _NearbyMap(
                    origin: LatLng(position.latitude, position.longitude),
                    radiusKm: viewModel.radiusKm,
                    listings: viewModel.filteredListings
                        .where((l) => l.latitude != null && l.longitude != null)
                        .toList(),
                  ),
                ),
              ],
            ),
    );
  }
}

class _NearbyMap extends StatelessWidget {
  final LatLng origin;
  final double? radiusKm;
  final List<Listing> listings;

  const _NearbyMap({
    required this.origin,
    required this.radiusKm,
    required this.listings,
  });

  double get _initialZoom {
    final km = radiusKm;
    if (km == null) return 13;
    if (km <= 1) return 15;
    if (km <= 2) return 14;
    if (km <= 5) return 12.5;
    return 11.5;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        FlutterMap(
          // Re-create the map when the radius changes so zoom follows it.
          key: ValueKey(radiusKm),
          options: MapOptions(initialCenter: origin, initialZoom: _initialZoom),
          children: [
            TileLayer(
              urlTemplate: _osmTileUrl,
              userAgentPackageName: _userAgentPackageName,
            ),
            if (radiusKm != null)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: origin,
                    radius: radiusKm! * 1000,
                    useRadiusInMeter: true,
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderColor: colorScheme.primary,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                for (final listing in listings)
                  Marker(
                    point: LatLng(listing.latitude!, listing.longitude!),
                    width: 44,
                    height: 44,
                    child: Tooltip(
                      message: listing.title,
                      child: GestureDetector(
                        onTap: () => context.push('/listing/${listing.id}'),
                        child: Icon(
                          Icons.location_on,
                          size: 44,
                          color: colorScheme.error,
                          semanticLabel: listing.title,
                        ),
                      ),
                    ),
                  ),
                Marker(
                  point: origin,
                  width: 24,
                  height: 24,
                  child: Semantics(
                    label: l10n.yourLocation,
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('© OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
        if (listings.isEmpty)
          Positioned(
            left: 16,
            right: 16,
            top: 12,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  l10n.noBooksWithinRadius,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
