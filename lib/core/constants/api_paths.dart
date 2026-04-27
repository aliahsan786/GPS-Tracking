/// Single source of truth for backend endpoint paths.
///
/// These are the four live mock endpoints hosted at
/// `https://fanthrofit.com/actions/`. When the real backend ships, the
/// paths will stay the same (the client confirmed this) — only
/// validation/storage semantics change on the server side.
class ApiPaths {
  ApiPaths._();

  // Auth
  static const String authGoogle = '/api_auth_google.php';

  // Tracking sessions
  static const String sessionsStart = '/api_tracking_start.php';
  static const String sessionsStop = '/api_tracking_stop.php';

  // Location ingest — one point per POST (not batched).
  static const String pointsIngest = '/api_tracking_location.php';
}

