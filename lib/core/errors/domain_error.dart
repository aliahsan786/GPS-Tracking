/// Typed error hierarchy for the repository/provider boundary.
///
/// Services throw raw SDK errors (DioException, PlatformException, etc).
/// Repositories catch those and rethrow one of these instead, so providers
/// only ever need to pattern-match on DomainError subtypes — never on
/// third-party types.
sealed class DomainError implements Exception {
  final String message;
  const DomainError(this.message);

  @override
  String toString() => '$runtimeType($message)';
}

/// No connectivity, timeout, DNS failure, etc.
class NetworkError extends DomainError {
  const NetworkError([super.message = 'Network unavailable']);
}

/// Backend returned 401. Triggers the SessionExpired UI state.
class SessionExpiredError extends DomainError {
  const SessionExpiredError([super.message = 'Session expired']);
}

/// 5xx or malformed response. `code` is a stable identifier the backend
/// uses (e.g. "TRACKING_SESSION_CONFLICT") so the UI can branch on it
/// without string-matching the message.
class ServerError extends DomainError {
  final int? statusCode;
  final String? code;
  const ServerError({
    this.statusCode,
    this.code,
    String message = 'Server error',
  }) : super(message);
}

/// 4xx (other than 401). Optional `fields` for form-level errors.
class ValidationError extends DomainError {
  final Map<String, String>? fields;
  const ValidationError({
    this.fields,
    String message = 'Invalid request',
  }) : super(message);
}

/// Last-resort bucket. Logging should page on these.
class UnknownError extends DomainError {
  const UnknownError([super.message = 'Unknown error']);
}
