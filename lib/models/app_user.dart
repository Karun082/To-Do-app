class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
    required this.createdAt,
    this.themePref = 'system',
  });

  final String id;
  final String email;
  final String name;
  final String? avatarUrl;
  final DateTime createdAt;
  final String themePref;

  factory AppUser.fromMap(Map<String, Object?> map) {
    return AppUser(
      id: map['id']! as String,
      email: map['email']! as String,
      name: map['name']! as String,
      avatarUrl: map['avatar_url'] as String?,
      createdAt: DateTime.parse(map['created_at']! as String),
      themePref: map['theme_pref'] as String? ?? 'system',
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'avatar_url': avatarUrl,
      'created_at': createdAt.toIso8601String(),
      'theme_pref': themePref,
    };
  }
}
