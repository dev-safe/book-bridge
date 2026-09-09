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

  // Fapshi configuration
  static const String fapshiApiUser = String.fromEnvironment(
    'FAPSHI_API_USER',
    defaultValue: '',
  );
  static const String fapshiApiKey = String.fromEnvironment(
    'FAPSHI_API_KEY',
    defaultValue: '',
  );
  static const String fapshiBaseUrl = String.fromEnvironment(
    'FAPSHI_BASE_URL',
    defaultValue: 'https://sandbox.fapshi.com',
  );
}
