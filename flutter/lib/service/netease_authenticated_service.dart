import 'package:dio/dio.dart';

import 'dio_client.dart';

class NeteaseAuthenticatedService {
  final DioClient dioClient;

  NeteaseAuthenticatedService({
    required this.dioClient,
  });

  Dio get dio => dioClient.dio;

  Future<void> attachCookie(String cookie) async {
    await dioClient.authStore.saveCookie(cookie);
  }

  Future<void> attachToken(String token) async {
    await dioClient.authStore.saveToken(token);
  }
}
