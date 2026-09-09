import 'package:flutter/foundation.dart';
import 'package:book_bridge/features/safety/domain/entities/campus_zone.dart';
import 'package:book_bridge/features/safety/domain/usecases/get_campus_zones_usecase.dart';

class SafetyViewModel extends ChangeNotifier {
  final GetCampusZonesUseCase _getCampusZonesUseCase;

  SafetyViewModel({required GetCampusZonesUseCase getCampusZonesUseCase})
    : _getCampusZonesUseCase = getCampusZonesUseCase;

  List<CampusZone> _zones = [];
  List<CampusZone> get zones => _zones;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Future<void> loadCampusZones() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _getCampusZonesUseCase();
    result.fold(
      (failure) {
        _error = failure.message;
        _isLoading = false;
        notifyListeners();
      },
      (zonesList) {
        _zones = zonesList;
        _isLoading = false;
        notifyListeners();
      },
    );
  }
}
