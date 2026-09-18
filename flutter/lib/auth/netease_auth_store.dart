import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../model/netease_user.dart';

class NeteaseAuthStore {
  static const String _tokenKey = 'netease_token';
  static const String _cookieKey = 'netease_cookie';
  static const String _userKey = 'netease_user';
  static const String _loginKey = 'netease_logged_in';

  final SharedPreferences prefs;

  NeteaseAuthStore(this.prefs);

  bool get isLoggedIn => prefs.getBool(_loginKey) ?? false;

  String? get token => prefs.getString(_tokenKey);

  String? get cookie => prefs.getString(_cookieKey);

  NeteaseUser? get user {
    final raw = prefs.getString(_userKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      return NeteaseUser.fromJson(decoded as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveToken(String token) async {
    await prefs.setString(_tokenKey, token);
    await prefs.setBool(_loginKey, true);
  }

  Future<void> saveCookie(String cookie) async {
    await prefs.setString(_cookieKey, cookie);
    await prefs.setBool(_loginKey, true);
  }

  Future<void> saveUser(NeteaseUser user) async {
    final encoded = jsonEncode({
      'profile': {
        'userId': user.id,
        'nickname': user.nickname,
        'avatarUrl': user.avatarUrl,
      },
    });
    await prefs.setString(_userKey, encoded);
    await prefs.setBool(_loginKey, true);
  }

  Future<void> clear() async {
    await prefs.remove(_tokenKey);
    await prefs.remove(_cookieKey);
    await prefs.remove(_userKey);
    await prefs.remove(_loginKey);
  }

  Future<void> setLoggedIn(bool value) async {
    await prefs.setBool(_loginKey, value);
    if (!value) {
      await clear();
    }
  }
}
