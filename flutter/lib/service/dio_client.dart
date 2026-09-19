import 'package:dio/dio.dart';

import '../auth/platform_auth_store.dart';
import '../auth/netease_auth_store.dart';

class DioClient {
  final NeteaseAuthStore authStore;
  final PlatformAuthStore? platformAuthStore;
  final Dio dio;

  DioClient({
    required this.authStore,
    this.platformAuthStore,
  }) : dio = Dio() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final cookie = authStore.cookie;
          final token = authStore.token;
          final host = options.uri.host;

          final headers = <String, dynamic>{
            'Referer': 'https://music.163.com',
            'Origin': 'https://music.163.com',
            'User-Agent':
                'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
            ...options.headers,
          };

          if (cookie != null && cookie.isNotEmpty) {
            headers['Cookie'] = cookie;
          }

          if (token != null && token.isNotEmpty) {
            headers['MUSIC_U'] = token;
          }

          if (platformAuthStore != null && host.contains('qq.com')) {
            final cookies = platformAuthStore!.qqCookies;
            if (cookies.isNotEmpty) {
              headers['Cookie'] = cookies.entries
                  .map((entry) => '${entry.key}=${entry.value}')
                  .join('; ');
            }
          }

          if (platformAuthStore != null && host.contains('kugou.com')) {
            final auth = platformAuthStore!.kugouAuth;
            final kugouCookie = <String, String>{
              'userid': auth['userid'] ?? '',
              'token': auth['token'] ?? '',
              'KUGOU_API_MID': auth['KUGOU_API_MID'] ?? auth['mid'] ?? '',
              'dfid': auth['dfid'] ?? '-',
            }..removeWhere((key, value) => value.isEmpty);
            if (kugouCookie.isNotEmpty) {
              headers['Cookie'] = kugouCookie.entries
                  .map((entry) => '${entry.key}=${entry.value}')
                  .join('; ');
            }
          }

          options.headers = headers;
          handler.next(options);
        },
      ),
    );
  }
}
