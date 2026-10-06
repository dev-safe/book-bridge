import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/features/admin/domain/entities/admin_cases.dart';
import 'package:book_bridge/features/admin/domain/repositories/admin_repository.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

enum AdminLoadState { checking, denied, loading, loaded }

class AdminViewModel extends ChangeNotifier {
  final AdminRepository _repository;

  AdminViewModel(this._repository);

  AdminLoadState _state = AdminLoadState.checking;
  List<AdminDispute> _disputes = const [];
  List<UnmatchedPayment> _unmatched = const [];
  List<IdVerificationSubmission> _idSubmissions = const [];
  List<ContentReport> _reports = const [];
  String? _error;
  String? _busyId;

  AdminLoadState get state => _state;
  List<AdminDispute> get disputes => _disputes;
  List<UnmatchedPayment> get unmatched => _unmatched;
  List<IdVerificationSubmission> get idSubmissions => _idSubmissions;
  List<ContentReport> get reports => _reports;

  /// Why the screen is denied, or why the last load failed.
  String? get error => _error;

  /// The dispute or payment an action is running on; all actions are
  /// disabled while one runs.
  String? get busyId => _busyId;

  Future<void> open() async {
    _state = AdminLoadState.checking;
    _error = null;
    notifyListeners();
    final access = await _repository.checkAdmin();
    if (access.isLeft()) {
      _error = _message(access);
      _state = AdminLoadState.denied;
      notifyListeners();
      return;
    }
    await refresh();
  }

  Future<void> refresh() async {
    _state = AdminLoadState.loading;
    _error = null;
    notifyListeners();
    final results = await Future.wait([
      _repository.disputes(),
      _repository.unmatchedPayments(),
      _repository.idVerifications(),
      _repository.reports(),
    ]);
    final disputes = results[0] as Either<Failure, List<AdminDispute>>;
    final unmatched = results[1] as Either<Failure, List<UnmatchedPayment>>;
    final ids = results[2] as Either<Failure, List<IdVerificationSubmission>>;
    final reports = results[3] as Either<Failure, List<ContentReport>>;
    _disputes = disputes.getOrElse(() => _disputes);
    _unmatched = unmatched.getOrElse(() => _unmatched);
    _idSubmissions = ids.getOrElse(() => _idSubmissions);
    _reports = reports.getOrElse(() => _reports);
    _error =
        _message(disputes) ??
        _message(unmatched) ??
        _message(ids) ??
        _message(reports);
    _state = AdminLoadState.loaded;
    notifyListeners();
  }

  /// Each action returns null on success or the error to show; lists are
  /// reloaded either way so they reflect what the server now holds.
  Future<String?> releaseDispute(String transactionId, String note) => _act(
    transactionId,
    () => _repository.releaseDispute(transactionId, note),
  );

  Future<String?> refundDispute(
    String transactionId,
    String note, {
    String? phone,
  }) => _act(
    transactionId,
    () => _repository.refundDispute(transactionId, note, phone: phone),
  );

  Future<String?> refundUnmatched(String id, String note, {String? phone}) =>
      _act(id, () => _repository.refundUnmatched(id, note, phone: phone));

  Future<String?> dismissUnmatched(String id, String note) =>
      _act(id, () => _repository.dismissUnmatched(id, note));

  Future<String?> approveId(String userId, String note) =>
      _act(userId, () => _repository.approveId(userId, note));

  Future<String?> rejectId(String userId, String note) =>
      _act(userId, () => _repository.rejectId(userId, note));

  Future<String?> dismissReport(String reportId, String note) =>
      _act(reportId, () => _repository.dismissReport(reportId, note));

  Future<String?> removeReportedListing(String reportId, String note) =>
      _act(reportId, () => _repository.removeReportedListing(reportId, note));

  /// Resolves to a short-lived photo URL; throws the failure message.
  Future<String> idPhotoUrl(String path) async {
    final result = await _repository.idPhotoUrl(path);
    return result.fold((failure) => throw Exception(failure.message), (u) => u);
  }

  Future<String?> _act(
    String id,
    Future<Either<Failure, Unit>> Function() run,
  ) async {
    if (_busyId != null) return 'Another action is still running';
    _busyId = id;
    notifyListeners();
    final result = await run();
    _busyId = null;
    await refresh();
    return _message(result);
  }

  static String? _message(Either<Failure, Object?> result) =>
      result.fold((failure) => failure.message, (_) => null);
}
