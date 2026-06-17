import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../../network/api_client.dart";
import "auth_providers.dart";

import "../../error/api_exception.dart";

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final dioProvider = Provider<Dio>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final dio = buildApiClient();

  dio.interceptors.add(
    InterceptorsWrapper(
      onError: (DioException e, handler) {
        ApiException exception;
        
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError) {
          exception = NetworkException(originalError: e);
        } else if (e.response != null) {
          final status = e.response!.statusCode;
          final data = e.response!.data;
          
          if (status == 401) {
            exception = UnauthorizedException();
          } else if (status == 422) {
            String msg = "Error de validación";
            Map<String, dynamic>? errorMap;
            if (data is Map) {
              errorMap = data.cast<String, dynamic>();
              if (errorMap.containsKey("detail")) {
                msg = errorMap["detail"].toString();
              }
            }
            exception = ValidationException(msg, errors: errorMap);
          } else if (status! >= 500) {
            exception = ServerException(statusCode: status, originalError: e);
          } else {
            String msg = "Ocurrió un error inesperado";
            if (data is Map && data["detail"] != null) {
              msg = data["detail"].toString();
            }
            exception = ApiException(msg, statusCode: status, originalError: e);
          }
        } else {
          exception = ApiException("Error desconocido", originalError: e);
        }
        
        return handler.next(DioException(
          requestOptions: e.requestOptions,
          response: e.response,
          type: e.type,
          error: exception,
          message: exception.message,
        ));
      },
    ),
  );

  dio.interceptors.add(
    QueuedInterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await resolveValidAccessToken(client);
        if (token != null && token.isNotEmpty) {
          options.headers["Authorization"] = "Bearer $token";
        } else {
          options.headers.remove("Authorization");
        }

        return handler.next(options);
      },
      onError: (error, handler) async {
        final statusCode = error.response?.statusCode;
        final request = error.requestOptions;
        final alreadyRetried = request.extra["auth_retry"] == true;

        if (statusCode == 403) {
          final data = error.response?.data;
          if (data is Map && data["detail"] == "Account deactivated") {
            try {
              ref.read(authErrorProvider.notifier).state =
                  "Tu cuenta ha sido desactivada. Contacta al administrador.";
              await safeSignOut(client);
            } catch (_) {}
          }
        }

        if (statusCode == 401 && !alreadyRetried) {
          try {
            final refreshed = await client.auth.refreshSession();
            final newToken = refreshed.session?.accessToken ??
                client.auth.currentSession?.accessToken;

            if (newToken != null && newToken.isNotEmpty) {
              request.headers["Authorization"] = "Bearer $newToken";
              request.extra["auth_retry"] = true;

              final retried = await dio.fetch<dynamic>(request);
              return handler.resolve(retried);
            }
          } catch (_) {
            // Fall through to force sign-out below.
          }

          await safeSignOut(client);
        }

        return handler.next(error);
      },
    ),
  );

  return dio;
});
