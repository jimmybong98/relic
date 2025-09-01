class AppUser {
  final int id;
  final String username;
  final bool isAdmin;

  AppUser({required this.id, required this.username, required this.isAdmin});

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      username: json['username'] as String,
      isAdmin: (json['is_admin'] as int) == 1,
    );
  }
}
