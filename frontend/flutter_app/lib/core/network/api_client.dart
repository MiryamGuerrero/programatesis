import "package:flutter/foundation.dart";
import "package:dio/dio.dart";

import "../config/app_config.dart";

Dio buildApiClient() {
  return Dio(
    BaseOptions(
      baseUrl: AppConfig.fastApiBaseUrl,
      // Keep generous timeouts so role/auth loading is not interrupted on slow networks.
      connectTimeout: const Duration(minutes: 2),
      receiveTimeout: const Duration(minutes: 5),
      sendTimeout: kIsWeb ? null : const Duration(minutes: 5),
      headers: {
        "Content-Type": "application/json",
      },
    ),
  );
}
