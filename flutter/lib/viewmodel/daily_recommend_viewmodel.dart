import 'package:flutter/foundation.dart';
import '../model/song.dart';
import '../model/ranking.dart';
import '../model/playlist.dart';
import '../service/daily_recommend_service.dart';

enum DailyRecommendStatus {
  loading,
  success,
  error,
}

class DailyRecommendViewModel extends ChangeNotifier {
  final DailyRecommendService _service;

  DailyRecommendStatus _status = DailyRecommendStatus.loading;
  List<Song> _dailySongs = [];
  String _errorMessage = '';
  int _selectedPlatform = 0; // 0: 网易云, 1: QQ音乐, 2: 酷狗音乐
  List<Ranking> _rankings = [];
  bool _rankingsLoading = false;
  bool _rankingsExpanded = false;
  List<Playlist> _playlists = [];
  bool _playlistsLoading = false;
  String _playlistCategory = '全部';
  List<String> _playlistCategories = const [
    '全部',
    '华语',
    '流行',
    '经典',
    '摇滚',
    '民谣',
    '电子',
    '影视原声',
    'ACG',
    '欧美',
    '日韩',
  ];

  DailyRecommendViewModel(this._service);

  DailyRecommendStatus get status => _status;
  List<Song> get dailySongs => _dailySongs;
  String get errorMessage => _errorMessage;
  int get selectedPlatform => _selectedPlatform;
  List<Ranking> get rankings => List.unmodifiable(_rankings);
  bool get rankingsLoading => _rankingsLoading;
  bool get rankingsExpanded => _rankingsExpanded;
  List<Playlist> get playlists => List.unmodifiable(_playlists);
  bool get playlistsLoading => _playlistsLoading;
  String get playlistCategory => _playlistCategory;
  List<String> get playlistCategories => List.unmodifiable(_playlistCategories);

  /// 切换平台
  void setPlatform(int platform) {
    if (_selectedPlatform != platform) {
      _selectedPlatform = platform;
      _loadDailySongs();
      _loadRankings();
      _loadPlaylists();
      notifyListeners();
    }
  }

  /// 加载每日推荐
  Future<void> loadDailySongs() async {
    await _loadDailySongs();
    await _loadRankings();
    await _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    if (_selectedPlatform != 0) {
      _playlists = [];
      return;
    }
    _playlistsLoading = true;
    notifyListeners();
    try {
      _playlists = await _service.getPlaylistSquare(
        category: _playlistCategory,
      );
      final categories = await _service.getPlaylistCategories();
      if (categories.isNotEmpty) {
        _playlistCategories = ['全部', ...categories.where((c) => c != '全部')];
      }
    } finally {
      _playlistsLoading = false;
      notifyListeners();
    }

  }

  Future<void> setPlaylistCategory(String category) async {
    if (_playlistCategory == category) return;
    _playlistCategory = category;
    await _loadPlaylists();
  }

  Future<List<Song>> loadPlaylistSongs(Playlist playlist) {
    return _service.getPlaylistSongs(playlist);
  }

  Future<void> _loadRankings() async {
    _rankingsLoading = true;
    notifyListeners();
    try {
      _rankings = await _service.getRankings(
        SongSource.values[_selectedPlatform],
      );
    } finally {
      _rankingsLoading = false;
      notifyListeners();
    }
  }

  void toggleRankingsExpanded() {
    _rankingsExpanded = !_rankingsExpanded;
    notifyListeners();
  }

  Future<List<Song>> loadRankingSongs(Ranking ranking) {
    return _service.getRankingSongs(ranking);
  }

  Future<void> _loadDailySongs() async {
    try {
      _status = DailyRecommendStatus.loading;
      _errorMessage = '';
      notifyListeners();

      List<Song> songs;

      switch (_selectedPlatform) {
        case 0: // 网易云
          songs = await _service.getDailySongs();
          break;
        case 1: // QQ音乐
          songs = await _service.getQQDailySongs();
          break;
        case 2: // 酷狗音乐
          songs = await _service.getKugouDailySongs();
          break;
        default:
          songs = await _service.getDailySongs();
      }

      _dailySongs = songs;
      _status = DailyRecommendStatus.success;
    } catch (e) {
      _status = DailyRecommendStatus.error;
      _errorMessage = e.toString();
    }

    notifyListeners();
  }

  /// 刷新数据
  Future<void> refresh() async {
    await _loadDailySongs();
    await _loadRankings();
    await _loadPlaylists();
  }

  /// 获取平台名称
  String getPlatformName() {
    switch (_selectedPlatform) {
      case 0:
        return '网易云音乐';
      case 1:
        return 'QQ音乐';
      case 2:
        return '酷狗音乐';
      default:
        return '网易云音乐';
    }
  }

  /// 获取平台图标
  String getPlatformIcon() {
    switch (_selectedPlatform) {
      case 0:
        return '🎵';
      case 1:
        return '🎧';
      case 2:
        return '🎶';
      default:
        return '🎵';
    }
  }
}
