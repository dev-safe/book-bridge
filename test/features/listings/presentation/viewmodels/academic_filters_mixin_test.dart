import 'dart:async';

import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/features/listings/domain/entities/academic_lookups.dart';
import 'package:book_bridge/features/listings/domain/repositories/listing_repository.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/academic_filters_mixin.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockListingRepository extends Mock implements ListingRepository {}

class _TestFilters extends ChangeNotifier with AcademicFiltersMixin {
  _TestFilters(this.academicRepository);

  @override
  final ListingRepository academicRepository;

  int changeCount = 0;

  @override
  Future<void> onAcademicFiltersChanged() async => changeCount++;
}

const _form3 = ClassLevel(
  id: 'cl-1',
  system: 'anglophone',
  code: 'F3',
  label: 'Form 3',
);
const _maths = Subject(id: 'sub-1', code: 'MATH', name: 'Mathematics');
const _school = School(id: 'sch-1', name: 'GBHS Molyko', town: 'Buea');

void main() {
  late MockListingRepository repository;
  late _TestFilters filters;

  setUp(() {
    repository = MockListingRepository();
    filters = _TestFilters(repository);
  });

  group('loadAcademicLookups', () {
    test('loads class levels and subjects once', () async {
      when(
        () => repository.getClassLevels(),
      ).thenAnswer((_) async => const Right([_form3]));
      when(
        () => repository.getSubjects(),
      ).thenAnswer((_) async => const Right([_maths]));

      await filters.loadAcademicLookups();
      await filters.loadAcademicLookups();

      expect(filters.classLevels, [_form3]);
      expect(filters.subjects, [_maths]);
      verify(() => repository.getClassLevels()).called(1);
      verify(() => repository.getSubjects()).called(1);
    });

    test('shares a single in-flight load between concurrent callers', () async {
      final completer = Completer<Either<Failure, List<ClassLevel>>>();
      when(
        () => repository.getClassLevels(),
      ).thenAnswer((_) => completer.future);
      when(
        () => repository.getSubjects(),
      ).thenAnswer((_) async => const Right([_maths]));

      final first = filters.loadAcademicLookups();
      final second = filters.loadAcademicLookups();
      completer.complete(const Right([_form3]));
      await Future.wait([first, second]);

      verify(() => repository.getClassLevels()).called(1);
      expect(filters.classLevels, [_form3]);
    });

    test('a failed load can be retried', () async {
      var calls = 0;
      when(() => repository.getClassLevels()).thenAnswer((_) async {
        calls++;
        return calls == 1
            ? const Left(ServerFailure(message: 'boom'))
            : const Right([_form3]);
      });
      when(
        () => repository.getSubjects(),
      ).thenAnswer((_) async => const Right([_maths]));

      await filters.loadAcademicLookups();
      expect(filters.classLevels, isEmpty);

      await filters.loadAcademicLookups();
      expect(filters.classLevels, [_form3]);
      verify(() => repository.getClassLevels()).called(2);
    });
  });

  group('filter setters', () {
    test('setClassLevelFilter triggers a refresh only on change', () async {
      await filters.setClassLevelFilter('cl-1');
      await filters.setClassLevelFilter('cl-1');

      expect(filters.selectedClassLevelId, 'cl-1');
      expect(filters.changeCount, 1);
    });

    test('setSubjectFilter triggers a refresh only on change', () async {
      await filters.setSubjectFilter('sub-1');
      await filters.setSubjectFilter('sub-1');
      await filters.setSubjectFilter(null);

      expect(filters.selectedSubjectId, isNull);
      expect(filters.changeCount, 2);
    });

    test('setSchoolFilter compares schools by id', () async {
      await filters.setSchoolFilter(_school);
      await filters.setSchoolFilter(
        const School(id: 'sch-1', name: 'Renamed', town: 'Buea'),
      );

      expect(filters.selectedSchool, _school);
      expect(filters.changeCount, 1);
    });

    test('academicFilters reflects the current selection', () async {
      expect(filters.academicFilters.isEmpty, isTrue);
      expect(filters.hasAcademicFilters, isFalse);

      await filters.setClassLevelFilter('cl-1');
      await filters.setSubjectFilter('sub-1');
      await filters.setSchoolFilter(_school);

      expect(
        filters.academicFilters,
        const AcademicFilters(
          classLevelId: 'cl-1',
          subjectId: 'sub-1',
          schoolId: 'sch-1',
        ),
      );
      expect(filters.hasAcademicFilters, isTrue);
    });

    test('selected lookups resolve against loaded lists', () async {
      when(
        () => repository.getClassLevels(),
      ).thenAnswer((_) async => const Right([_form3]));
      when(
        () => repository.getSubjects(),
      ).thenAnswer((_) async => const Right([_maths]));
      await filters.loadAcademicLookups();

      await filters.setClassLevelFilter('cl-1');
      await filters.setSubjectFilter('unknown');

      expect(filters.selectedClassLevel, _form3);
      expect(filters.selectedSubject, isNull);
    });
  });

  group('clearAcademicFilters', () {
    test('is a no-op when nothing is selected', () async {
      await filters.clearAcademicFilters();
      expect(filters.changeCount, 0);
    });

    test('clears every filter with a single refresh', () async {
      await filters.setClassLevelFilter('cl-1');
      await filters.setSchoolFilter(_school);
      filters.changeCount = 0;

      await filters.clearAcademicFilters();

      expect(filters.academicFilters.isEmpty, isTrue);
      expect(filters.selectedSchool, isNull);
      expect(filters.changeCount, 1);
    });
  });

  group('searchSchools', () {
    test('returns matches on success', () async {
      when(
        () => repository.searchSchools('mol'),
      ).thenAnswer((_) async => const Right([_school]));

      expect(await filters.searchSchools('mol'), [_school]);
    });

    test('returns an empty list on failure', () async {
      when(
        () => repository.searchSchools(any()),
      ).thenAnswer((_) async => const Left(ServerFailure(message: 'down')));

      expect(await filters.searchSchools('mol'), isEmpty);
    });
  });
}
