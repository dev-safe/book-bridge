/// Error sentinel raised when a free seller hits the active-listing cap.
///
/// Matches the `free_tier_limit` exception raised by the
/// `check_listing_limit` database trigger.
const String kFreeTierLimitError = 'free_tier_limit';

/// Active listings a free seller may have at once.
const int kFreeTierListingLimit = 3;

/// Power Seller price in FCFA for one billing period.
const int kPowerSellerPriceFcfa = 500;

/// Length of one Power Seller billing period, in days.
const int kPowerSellerDays = 30;

/// Whether a server error message is the free-tier listing cap.
bool isFreeTierLimitError(String? message) =>
    message != null && message.contains(kFreeTierLimitError);
