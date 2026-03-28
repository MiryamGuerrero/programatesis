import "package:dio/dio.dart";

import "../config/app_config.dart";

Dio buildApiClient() {
  return Dio(
    BaseOptions(
      baseUrl: AppConfig.fastApiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      headers: {
        "Content-Type": "application/json",
      },
    ),
  );
}
