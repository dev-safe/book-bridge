import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

const _osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const _userAgentPackageName = 'cm.devsafe.bookbridge';

/// Yaoundé city centre: the fallback when there is no better starting point.
const defaultMeetupCenter = LatLng(3.848, 11.502);

/// Full-screen map where the seller taps to drop a meetup pin.
///
/// Pops with the chosen [LatLng], or null when cancelled.
class MeetupPinPicker extends StatefulWidget {
  final LatLng initialCenter;
  final LatLng? initialPin;

  const MeetupPinPicker({
    super.key,
    required this.initialCenter,
    this.initialPin,
  });

  /// Opens the picker and returns the chosen point, if any.
  static Future<LatLng?> show(
    BuildContext context, {
    required LatLng initialCenter,
    LatLng? initialPin,
  }) {
    return Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MeetupPinPicker(
          initialCenter: initialCenter,
          initialPin: initialPin,
        ),
      ),
    );
  }

  @override
  State<MeetupPinPicker> createState() => _MeetupPinPickerState();
}

class _MeetupPinPickerState extends State<MeetupPinPicker> {
  LatLng? _pin;

  @override
  void initState() {
    super.initState();
    _pin = widget.initialPin;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pin = _pin;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.meetupPinPickerTitle),
        actions: [
          TextButton(
            onPressed: pin == null
                ? null
                : () => Navigator.of(context).pop(pin),
            child: Text(l10n.meetupPinConfirm),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: widget.initialPin ?? widget.initialCenter,
              initialZoom: 15,
              onTap: (_, point) => setState(() => _pin = point),
            ),
            children: [
              TileLayer(
                urlTemplate: _osmTileUrl,
                userAgentPackageName: _userAgentPackageName,
              ),
              if (pin != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: pin,
                      width: 40,
                      height: 40,
                      alignment: Alignment.topCenter,
                      child: Icon(
                        Icons.location_on,
                        size: 40,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  l10n.meetupPinPickerHint,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
