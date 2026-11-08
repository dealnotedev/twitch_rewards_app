class ViewerBalance {
  final String viewerId;
  final String username;
  final String displayName;
  final int balance;

  const ViewerBalance({
    required this.viewerId,
    required this.username,
    required this.displayName,
    required this.balance,
  });

  factory ViewerBalance.fromRow(Map<String, Object?> row) => ViewerBalance(
    viewerId: row['viewer_id'] as String,
    username: row['username'] as String,
    displayName: row['display_name'] as String,
    balance: row['balance'] as int,
  );

  bool matches(String query) {
    // SQLite NOCASE only handles ASCII. Match display names with Dart's
    // Unicode lowercasing so Cyrillic names work as well as Twitch logins.
    final needle = query.trim().toLowerCase();
    return viewerId.toLowerCase().contains(needle) ||
        username.toLowerCase().contains(needle) ||
        displayName.toLowerCase().contains(needle);
  }
}
