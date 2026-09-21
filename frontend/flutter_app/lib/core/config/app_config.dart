class AppConfig {
  static const String supabaseUrl = String.fromEnvironment(
    "SUPABASE_URL",
    defaultValue: "https://ygsxvepdycnjznqqinwc.supabase.co",
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    "SUPABASE_ANON_KEY",
    defaultValue: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlnc3h2ZXBkeWNuanpucXFpbndjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgxODc0MjgsImV4cCI6MjA5Mzc2MzQyOH0.4eyMQw5dG-XAis8iFmTUhxtbYms5hA9B9hkneJEQ7MU",
  );

  static String get fastApiBaseUrl {
    const url = String.fromEnvironment(
      "FASTAPI_BASE_URL",
      defaultValue: "https://programatesis-production.up.railway.app/api/v1",
    );
    return url.endsWith("/") ? url : "$url/";
  }
}
