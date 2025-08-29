/// Utility functions for string normalization.
///
/// Removes leading zeros from numeric-like strings so that
/// values like "020" and "20" are treated equivalently.
String normalizeCode(String value) {
  final trimmed = value.trim();
  final normalized = trimmed.replaceFirst(RegExp(r'^0+'), '');
  return normalized.isEmpty ? '0' : normalized;
}
