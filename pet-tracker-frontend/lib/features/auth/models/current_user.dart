class CurrentUser {
  final String uid;
  final String? email;
  final String? displayName;

  const CurrentUser({
    required this.uid,
    required this.email,
    required this.displayName,
  });

  factory CurrentUser.fromJson(Map<String, dynamic> json) {
    return CurrentUser(
      uid: json['uid'] as String? ?? '',
      email: json['email'] as String?,
      displayName: json['display_name'] as String?,
    );
  }
}
