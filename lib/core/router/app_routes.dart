/// Named route table. Using a tiny constants class instead of a full
/// router package — we only have three routes and no deep-linking yet.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String tracking = '/tracking';
}
