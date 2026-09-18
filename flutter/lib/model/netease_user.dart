class NeteaseUser {
  final int id;
  final String nickname;
  final String? avatarUrl;

  NeteaseUser({
    required this.id,
    required this.nickname,
    this.avatarUrl,
  });

  factory NeteaseUser.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] as Map<String, dynamic>? ?? {};

    return NeteaseUser(
      id: (profile['userId'] as int?) ?? (json['userId'] as int?) ?? 0,
      nickname: profile['nickname'] as String? ?? json['nickname'] as String? ?? '',
      avatarUrl: profile['avatarUrl'] as String? ?? json['avatarUrl'] as String?,
    );
  }
}
