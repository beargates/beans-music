import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../model/song.dart';

class LibraryStore {
  static const _favoritesKey = 'library_favorites';
  static const _historyKey = 'library_history';
  static const _maxHistory = 100;

  final SharedPreferences prefs;
  final List<Song> _favorites;
  final List<Song> _history;

  LibraryStore._(this.prefs, this._favorites, this._history);

  factory LibraryStore(SharedPreferences prefs) {
    return LibraryStore._(
      prefs,
      _readSongs(prefs, _favoritesKey),
      _readSongs(prefs, _historyKey),
    );
  }

  List<Song> get favorites => List.unmodifiable(_favorites);
  List<Song> get history => List.unmodifiable(_history);

  bool isFavorite(Song song) =>
      _favorites.any((item) => item.identityKey == song.identityKey);

  Future<void> toggleFavorite(Song song) async {
    final index =
        _favorites.indexWhere((item) => item.identityKey == song.identityKey);
    if (index >= 0) {
      _favorites.removeAt(index);
    } else {
      _favorites.insert(0, song);
    }
    await _save(_favoritesKey, _favorites);
  }

  Future<void> addHistory(Song song) async {
    _history.removeWhere((item) => item.identityKey == song.identityKey);
    _history.insert(0, song);
    if (_history.length > _maxHistory) {
      _history.removeRange(_maxHistory, _history.length);
    }
    await _save(_historyKey, _history);
  }

  Future<void> clearHistory() async {
    _history.clear();
    await prefs.remove(_historyKey);
  }

  Future<void> removeFavorite(Song song) async {
    _favorites.removeWhere((item) => item.identityKey == song.identityKey);
    await _save(_favoritesKey, _favorites);
  }

  Future<void> removeHistory(Song song) async {
    _history.removeWhere((item) => item.identityKey == song.identityKey);
    await _save(_historyKey, _history);
  }

  Future<void> clearFavorites() async {
    _favorites.clear();
    await prefs.remove(_favoritesKey);
  }

  Future<void> _save(String key, List<Song> songs) async {
    await prefs.setString(
      key,
      jsonEncode(songs.map((song) => song.toJson()).toList()),
    );
  }

  static List<Song> _readSongs(SharedPreferences prefs, String key) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .whereType<Map>()
          .map((item) => Song.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
