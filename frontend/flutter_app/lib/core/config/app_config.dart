class AppConfig {
  static const String supabaseUrl = String.fromEnvironment(
    "SUPABASE_URL",
    defaultValue: "",
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    "SUPABASE_ANON_KEY",
    defaultValue: "",
  );

  static String get fastApiBaseUrl {
    const url = String.fromEnvironment(
      "FASTAPI_BASE_URL",
      defaultValue: "http://localhost:8000/api/v1",
    );
    return url.endsWith("/") ? url : "$url/";
  }
}
