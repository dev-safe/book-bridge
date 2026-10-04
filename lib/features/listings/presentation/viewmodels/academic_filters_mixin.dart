import 'package:flutter/foundation.dart';
import 'package:book_bridge/features/listings/domain/entities/academic_lookups.dart';
import 'package:book_bridge/features/listings/domain/repositories/listing_repository.dart';

/// Shared class level / subject / school filter state for listing feeds.
///
/// Implementers supply [academicRepository] and react to filter changes in
/// [onAcademicFiltersChanged] (typically by reloading results).
mixin AcademicFiltersMixin on ChangeNotifier {
  ListingRepository get academicRepository;

  List<ClassLevel> _classLevels = const [];
  List<Subject> _subjects = const [];
  bool _lookupsLoaded = false;
  Future<void>? _lookupsInFlight;

  String? _classLevelId;
  String? _subjectId;
  School? _selectedSchool;

  List<ClassLevel> get classLevels => _classLevels;
  List<Subject> get subjects => _subjects;
  bool get lookupsLoaded => _lookupsLoaded;
  String? get selectedClassLevelId => _classLevelId;
  String? get selectedSubjectId => _subjectId;
  School? get selectedSchool => _selectedSchool;

  ClassLevel? get selectedClassLevel {
    for (final level in _classLevels) {
      if (level.id == _classLevelId) return level;
    }
    return null;
  }

  Subject? get selectedSubject {
    for (final subject in _subjects) {
      if (subject.id == _subjectId) return subject;
    }
    return null;
  }

  AcademicFilters get academicFilters => AcademicFilters(
    classLevelId: _classLevelId,
    subjectId: _subjectId,
    schoolId: _selectedSchool?.id,
  );

  bool get hasAcademicFilters => !academicFilters.isEmpty;

  /// Called after any filter change; implementers should reload results.
  Future<void> onAcademicFiltersChanged();

  /// Loads class levels and subjects once; failures are retried next call.
  /// Concurrent callers share the in-flight request.
  Future<void> loadAcademicLookups() {
    if (_lookupsLoaded) return Future.value();
    return _lookupsInFlight ??= _fetchAcademicLookups().whenComplete(
      () => _lookupsInFlight = null,
    );
  }

  Future<void> _fetchAcademicLookups() async {
    final levels = await academicRepository.getClassLevels();
    final subjects = await academicRepository.getSubjects();
    var ok = true;
    levels.fold((_) => ok = false, (v) => _classLevels = v);
    subjects.fold((_) => ok = false, (v) => _subjects = v);
    _lookupsLoaded = ok;
    notifyListeners();
  }

  Future<List<School>> searchSchools(String query) async {
    final result = await academicRepository.searchSchools(query);
    return result.fold((_) => const <School>[], (v) => v);
  }

  Future<void> setClassLevelFilter(String? id) async {
    if (id == _classLevelId) return;
    _classLevelId = id;
    await onAcademicFiltersChanged();
  }

  Future<void> setSubjectFilter(String? id) async {
    if (id == _subjectId) return;
    _subjectId = id;
    await onAcademicFiltersChanged();
  }

  Future<void> setSchoolFilter(School? school) async {
    if (school?.id == _selectedSchool?.id) return;
    _selectedSchool = school;
    await onAcademicFiltersChanged();
  }

  Future<void> clearAcademicFilters() async {
    if (!hasAcademicFilters) return;
    _classLevelId = null;
    _subjectId = null;
    _selectedSchool = null;
    await onAcademicFiltersChanged();
  }
}
