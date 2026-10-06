/// Why a user reports a listing or another user. [wire] matches the
/// `content_reports.reason` check constraint.
enum ReportReason {
  spam('spam'),
  scam('scam'),
  inappropriate('inappropriate'),
  harassment('harassment'),
  prohibited('prohibited'),
  other('other');

  const ReportReason(this.wire);

  final String wire;
}
