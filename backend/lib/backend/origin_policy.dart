/// Browser-origin policy for Lumi's loopback API.
///
/// A loopback listener is still reachable from a browser tab on another
/// website.  CORS is therefore an explicit compatibility allowlist, never an
/// authorization mechanism and never a wildcard.
final class OriginPolicy {
  OriginPolicy(Iterable<String> origins)
      : _origins = origins
            .map((origin) => origin.trim())
            .where((origin) => origin.isNotEmpty)
            .toSet();

  factory OriginPolicy.fromEnvironment(Map<String, String> environment) {
    return OriginPolicy(
      (environment['LUMI_ALLOWED_ORIGINS'] ?? '')
          .split(',')
          .where((origin) => origin.isNotEmpty),
    );
  }

  final Set<String> _origins;

  List<String> get allowedOrigins => _origins.toList()..sort();

  /// Requests without Origin are same-origin navigations/non-browser clients.
  /// Every browser cross-origin request must be explicitly configured.
  bool allows(String? origin) =>
      origin == null || origin.isEmpty || _origins.contains(origin);
}
