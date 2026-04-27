/// Environment configuration.
///
/// Flip [flavor] at build time (ideally via `--dart-define`) to switch
/// between dev/staging/prod. Kept as plain constants so there's no runtime
/// cost and nothing to initialise.
library;

enum Flavor { dev, staging, prod }

class Env {
  Env._();

  static const Flavor flavor = Flavor.dev;

  // Single mock backend for all flavors today. Split per-env when the
  // backend team exposes real dev/staging/prod hosts.
  static const Map<Flavor, String> _baseUrls = {
    Flavor.dev: 'https://fanthrofit.com/actions',
    Flavor.staging: 'https://fanthrofit.com/actions',
    Flavor.prod: 'https://fanthrofit.com/actions',
  };

  static String get baseUrl => _baseUrls[flavor]!;

  static const Duration requestTimeout = Duration(seconds: 20);

  /// Target cadence for location points. OS constraints may stretch it.
  static const Duration locationInterval = Duration(seconds: 5);

  /// Max points sent per flush request when draining the offline queue.
  static const int flushBatchSize = 50;

  static bool get verboseLogs => flavor != Flavor.prod;
}
