import 'package:dio/dio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth/netease_auth_store.dart';
import 'auth/platform_auth_store.dart';
import 'manager/audio_player_manager.dart';
import 'model/song.dart';
import 'service/kugou_music_service.dart';
import 'service/kugou_url_service.dart';
import 'service/lyric_service.dart';
import 'service/music_repository.dart';
import 'service/netease_music_service.dart';
import 'service/qq_music_service.dart';
import 'service/dio_client.dart';
import 'service/download_service.dart';
import 'service/song_url_service.dart';
import 'service/third_party_song_url_service.dart';
import 'service/cover_palette.dart';
import 'store/library_store.dart';
import 'store/lyric_style_store.dart';
import 'ui/library_page.dart';
import 'ui/player_page.dart';
import 'ui/profile_page.dart';
import 'ui/platform_login_page.dart';
import 'ui/search_page.dart';
import 'ui/discover_page.dart';
import 'viewmodel/search_view_model.dart';
import 'viewmodel/daily_recommend_viewmodel.dart';
import 'service/daily_recommend_service.dart';
import 'widget/mini_player.dart';

class BeansMusicApp extends StatefulWidget {
  const BeansMusicApp({super.key});

  @override
  State<BeansMusicApp> createState() => _BeansMusicAppState();
}

class _BeansMusicAppState extends State<BeansMusicApp> {
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  Dio? dio;
  MusicRepository? repository;
  SongUrlRepository? songUrlRepository;
  LyricService? lyricService;
  DownloadService? downloadService;
  AudioPlayerManager? playerManager;
  BeansAudioHandler? audioHandler;
  PlatformAuthStore? platformAuthStore;
  NeteaseAuthStore? neteaseAuthStore;
  LibraryStore? libraryStore;
  LyricStyleStore? lyricStyleStore;
  CoverColorExtractor? coverColorExtractor;
  int _selectedTab = 0;
  Song? _currentSong;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final client = DioClient(
      authStore: NeteaseAuthStore(prefs),
      platformAuthStore: PlatformAuthStore(prefs),
    );
    neteaseAuthStore = client.authStore;
    platformAuthStore = client.platformAuthStore;
    libraryStore = LibraryStore(prefs);
    lyricStyleStore = LyricStyleStore(prefs);
    final clientDio = client.dio;
    repository = MusicRepository(
      netease: NeteaseMusicService(clientDio),
      qq: QQMusicService(clientDio),
      kugou: KugouMusicService(
        clientDio,
        authStore: platformAuthStore,
      ),
    );
    songUrlRepository = SongUrlRepository(
      netease: NeteaseSongUrlService(clientDio),
      qq: QQSongUrlService(clientDio),
      kugou: KugouSongUrlService(clientDio),
      thirdParty: ThirdPartySongUrlService(
        clientDio,
        apiKey: const String.fromEnvironment('BEANS_THIRD_PARTY_API_KEY'),
      ),
    );
    lyricService = LyricService(clientDio);
    playerManager = AudioPlayerManager();
    audioHandler = await AudioService.init(
      builder: () => BeansAudioHandler(playerManager!),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.beans.music.playback',
        androidNotificationChannelName: 'Beans Music',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
    playerManager!.resolveUrl = (song) async {
      final resolved = await songUrlRepository!.resolveUrl(song);
      if (resolved == null || !resolved.isAvailable) return null;
      return resolved.url;
    };
    downloadService = DownloadService(
      dio: clientDio,
      resolveUrl: playerManager!.resolveUrl!,
    );
    dio = clientDio;
    coverColorExtractor = CoverColorExtractor(dio: clientDio);

    playerManager!.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() => _isPlaying = state.playing);
    });
    playerManager!.currentSongStream.listen((song) {
      if (!mounted) return;
      setState(() => _currentSong = song);
    });
    if (mounted) setState(() {});
  }

  Future<void> playSong(Song song, List<Song> songs) async {
    final index = songs.indexWhere((item) => identical(item, song));
    final resolvedIndex = index >= 0
        ? index
        : songs.indexWhere((item) => item.identityKey == song.identityKey);
    if (resolvedIndex < 0) return;
    try {
      await libraryStore?.addHistory(song);
      audioHandler?.setSongQueue(songs);
      await playerManager?.playSongs(
        songs,
        startAt: resolvedIndex,
        skipUnavailable: false,
      );
    } catch (error) {
      final message = error.toString().replaceFirst('Bad state: ', '');
      _messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('播放失败：$message')),
      );
    }
  }

  @override
  void dispose() {
    playerManager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = repository != null &&
        playerManager != null &&
        platformAuthStore != null &&
        neteaseAuthStore != null &&
        libraryStore != null &&
        lyricStyleStore != null;
    return MaterialApp(
        scaffoldMessengerKey: _messengerKey,
        navigatorKey: _navigatorKey,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFE5654B),
            brightness: Brightness.light,
            surface: const Color(0xFFFFFEFA),
          ),
          scaffoldBackgroundColor: const Color(0xFFF5F4EF),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            centerTitle: false,
          ),
          inputDecorationTheme: const InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(18)),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(18)),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(18)),
              borderSide: BorderSide(color: Color(0xFFE5654B), width: 1.5),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          navigationBarTheme: const NavigationBarThemeData(
            backgroundColor: Color(0xFFFFFEFA),
            surfaceTintColor: Colors.transparent,
            indicatorColor: Color(0xFFFFDDD3),
            elevation: 0,
          ),
        ),
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<DailyRecommendViewModel>(
              create: (context) => DailyRecommendViewModel(
                DailyRecommendService(dio ?? Dio()),
              ),
            ),
          ],
          child: Scaffold(
            body: !ready
                ? const Center(child: CircularProgressIndicator())
                : IndexedStack(
                    index: _selectedTab,
                    children: [
                      DiscoverPage(
                        onSongTap: (song, songs) async => playSong(song, songs),
                        onPlayAll: (songs) async {
                          if (songs.isNotEmpty) {
                            audioHandler?.setSongQueue(songs);
                            await playerManager?.playSongs(
                              songs,
                              startAt: 0,
                              skipUnavailable: true,
                            );
                          }
                        },
                        currentPlayingSongId: _currentSong?.identityKey,
                      ),
                      SearchPage(
                        viewModel: SearchViewModel(repository!),
                        onSongTapWithContext: (song, songs) async =>
                            playSong(song, songs),
                        onLoginTap: () {
                          _navigatorKey.currentState?.push(
                            MaterialPageRoute(
                              builder: (_) => PlatformLoginPage(
                                store: platformAuthStore!,
                              ),
                            ),
                          );
                        },
                      ),
                      LibraryPage(
                        store: libraryStore!,
                        onSongTap: playSong,
                      ),
                      ProfilePage(
                        neteaseStore: neteaseAuthStore!,
                        platformStore: platformAuthStore!,
                      ),
                    ],
                  ),
            bottomNavigationBar: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MiniPlayer(
                  song: _currentSong,
                  isPlaying: _isPlaying,
                  onPlayPause: () async {
                    if (_currentSong == null) return;
                    if (_isPlaying && playerManager != null) {
                      await playerManager!.pause();
                    } else {
                      await playerManager?.resume();
                    }
                  },
                  onTap: () {
                    if (_currentSong == null) return;
                    _navigatorKey.currentState?.push(
                      MaterialPageRoute(
                        builder: (_) => PlayerPage(
                          song: _currentSong!,
                          playerManager: playerManager!,
                          style: lyricStyleStore!,
                          lyricService: lyricService,
                          downloadService: downloadService,
                          colorExtractor: coverColorExtractor,
                        ),
                      ),
                    );
                  },
                ),
                NavigationBar(
                  selectedIndex: _selectedTab,
                  onDestinationSelected: (index) {
                    setState(() => _selectedTab = index);
                  },
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home),
                      label: '发现',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.search),
                      label: '搜索',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.library_music_outlined),
                      label: '音乐库',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.person_outline),
                      label: '我的',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ));
  }
}
