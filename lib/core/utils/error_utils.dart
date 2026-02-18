/// Returns a user-friendly error message, hiding technical details.
String friendlyError(String error) {
  final lower = error.toLowerCase();
  if (lower.contains('supabase') ||
      lower.contains('initialize') ||
      lower.contains('socket') ||
      lower.contains('connection') ||
      lower.contains('.pub-cache')) {
    return 'Unable to connect to the server. Check your connection.';
  }
  return error;
}
