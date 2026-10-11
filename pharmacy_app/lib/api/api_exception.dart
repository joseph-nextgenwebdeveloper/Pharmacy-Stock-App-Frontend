/// A failure with a message that is safe to show to the person using the app.
/// `toString()` returns just the message (no "Exception:" prefix), so
/// providers can keep doing `_error = e.toString()`.
class ApiException implements Exception {
  final String message;

  /// True when the request failed because the phone could not reach the
  /// server (as opposed to the server rejecting it).
  final bool offline;

  const ApiException(this.message, {this.offline = false});

  @override
  String toString() => message;
}
