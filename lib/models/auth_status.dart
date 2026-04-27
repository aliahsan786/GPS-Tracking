/// Finite-state enum owned by [AuthProvider].
///
/// Transitions:
///   unknown        -> unauthenticated | authenticated   (on bootstrap)
///   unauthenticated -> signingIn                        (user taps Google)
///   signingIn      -> authenticated | unauthenticated   (success | fail/cancel)
///   authenticated  -> expired                           (backend 401)
///   authenticated  -> unauthenticated                   (user logs out)
///   expired        -> unauthenticated                   (user taps Login Again)
enum AuthStatus {
  unknown,
  unauthenticated,
  signingIn,
  authenticated,
  expired,
}
