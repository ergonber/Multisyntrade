sealed class AppException implements Exception {
  final String message;
  final String? code;

  const AppException({required this.message, this.code});

  @override
  String toString() => message;
}

class AuthException extends AppException {
  const AuthException({required super.message, super.code});
}

class NetworkException extends AppException {
  const NetworkException({required super.message, super.code});
}

class ServerException extends AppException {
  const ServerException({required super.message, super.code});
}

class CacheException extends AppException {
  const CacheException({required super.message, super.code});
}

class ValidationException extends AppException {
  const ValidationException({required super.message, super.code});
}

class DerivConnectionException extends AppException {
  const DerivConnectionException({required super.message, super.code});
}

class DerivAuthException extends AppException {
  const DerivAuthException({required super.message, super.code});
}

class PermissionException extends AppException {
  const PermissionException({required super.message, super.code});
}

class ParseException extends AppException {
  const ParseException({required super.message, super.code});
}
