class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic originalError;

  ApiException(this.message, {this.statusCode, this.originalError});

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

class NetworkException extends ApiException {
  NetworkException({dynamic originalError})
      : super('Error de conexión a internet. Verifica tu red.',
            originalError: originalError);
}

class ServerException extends ApiException {
  ServerException({int? statusCode, dynamic originalError})
      : super('Error en el servidor. Inténtalo más tarde.',
            statusCode: statusCode,
            originalError: originalError);
}

class UnauthorizedException extends ApiException {
  UnauthorizedException() : super('Sesión expirada o no autorizada.', statusCode: 401);
}

class ValidationException extends ApiException {
  final Map<String, dynamic>? errors;
  ValidationException(String message, {this.errors})
      : super(message, statusCode: 422);
}
