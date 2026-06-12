import "package:dio/dio.dart";

import "../config/app_config.dart";

Dio buildApiClient() {
  return Dio(
    BaseOptions(
      baseUrl: AppConfig.fastApiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {
        "Content-Type": "application/json",
      },
    ),
  );
}
