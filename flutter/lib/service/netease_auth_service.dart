import 'package:dio/dio.dart';

import '../model/netease_user.dart';
import 'weapi_utils.dart';

class NeteaseAuthService {
  final Dio dio;

  NeteaseAuthService(this.dio);

  Future<String> qrKey() async {
    final payload = {'type': 3};
    final body = WeapiUtils.encryptPayload(payload);

    final response = await dio.post(
      'https://music.163.com/weapi/login/qrcode/unikey',
      data: body,
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {
          'Referer': 'https://music.163.com',
          'Origin': 'https://music.163.com',
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        },
      ),
    );

    final data = response.data['data'] ?? response.data;
    final key = data['unikey'] as String? ?? (data['data'] as Map<String, dynamic>?)?['unikey'] as String?;

    if (key == null || key.isEmpty) {
      throw StateError('Failed to get NetEase QR code key.');
    }

    return key;
  }

  String qrLoginUrl(String key) {
    return 'https://music.163.com/login?codekey=$key';
  }

  Future<int> qrCheck(String key) async {
    final payload = {'key': key, 'type': 3};
    final body = WeapiUtils.encryptPayload(payload);

    final response = await dio.post(
      'https://music.163.com/weapi/login/qrcode/client/login',
      data: body,
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {
          'Referer': 'https://music.163.com',
          'Origin': 'https://music.163.com',
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        },
      ),
    );

    final code = response.data['code'] as int? ?? -1;
    return code;
  }

  Future<NeteaseUser> account() async {
    final body = WeapiUtils.encryptPayload({});

    final response = await dio.post(
      'https://music.163.com/weapi/w/nuser/account/get',
      data: body,
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {
          'Referer': 'https://music.163.com',
          'Origin': 'https://music.163.com',
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        },
      ),
    );

    final data = response.data ?? {};
    return NeteaseUser.fromJson(data);
  }
}
