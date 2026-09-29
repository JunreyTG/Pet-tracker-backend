/// Safely reads a route argument as a non-empty id string.
///
/// `Get.arguments` is `dynamic`, so a direct `as String?` cast throws a
/// `_TypeError` when a route is opened with a different argument type (for
/// example from a notification payload or a deep link). That error is thrown
/// on every rebuild, which floods the UI with exceptions.
String? asIdString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
