/// Whether the app offers paid digital features: Power Seller, listing
/// boosts and donations.
///
/// Off by default because Google Play requires Play Billing for digital
/// goods sold in-app; those payments currently go through Fapshi. Physical
/// book purchases (escrow) are unaffected. Enable for non-Play builds with
/// `--dart-define=ENABLE_DIGITAL_PAYMENTS=true`.
const bool kDigitalPaymentsEnabled = bool.fromEnvironment(
  'ENABLE_DIGITAL_PAYMENTS',
);
