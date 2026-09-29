/// Environment configuration for the app
/// This file loads environment variables from the .env file
///
/// NOTE: The .env file should never be committed to version control
/// and should be added to .gitignore
class AppConfig {
  // Supabase configuration
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  // BookBridge Rust core service (payments and escrow actions). Public URL,
  // not a secret. Fapshi credentials live only on that service.
  static const String rustCoreUrl = String.fromEnvironment(
    'RUST_CORE_URL',
    defaultValue: 'https://bookbridge-rust-core.onrender.com',
  );
}
