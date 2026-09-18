import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PlatformAuthStore {
  static const _qqCookiesKey = 'qqmusic_cookies';
  static const _qqNicknameKey = 'qqmusic_nickname';
  static const _kugouAuthKey = 'kugou_auth';

  final SharedPreferences prefs;

  PlatformAuthStore(this.prefs);

  Map<String, String> get qqCookies {
    final raw = prefs.getString(_qqCookiesKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((key, value) => MapEntry(key, value.toString()));
    } catch (_) {
      return {};
    }
  }

  String? get qqNickname => prefs.getString(_qqNicknameKey);

  Map<String, String> get kugouAuth {
    final raw = prefs.getString(_kugouAuthKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((key, value) => MapEntry(key, value.toString()));
    } catch (_) {
      return {};
    }
  }

  Future<void> saveQQCookies(
    Map<String, String> cookies, {
    String? nickname,
  }) async {
    await prefs.setString(_qqCookiesKey, jsonEncode(cookies));
    if (nickname != null && nickname.isNotEmpty) {
      await prefs.setString(_qqNicknameKey, nickname);
    }
  }

  Future<void> saveKugouAuth(Map<String, String> auth) async {
    await prefs.setString(_kugouAuthKey, jsonEncode(auth));
  }

  Future<void> clearQQ() async {
    await prefs.remove(_qqCookiesKey);
    await prefs.remove(_qqNicknameKey);
  }

  Future<void> clearKugou() async {
    await prefs.remove(_kugouAuthKey);
  }
}
