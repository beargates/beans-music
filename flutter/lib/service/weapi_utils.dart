import 'dart:convert';
import 'dart:math';

import 'package:encrypt/encrypt.dart';

class WeapiUtils {
  static const String fixedKey = '0CoJUm6Qyw8W8jud';
  static const String fixedIV = '0102030405060708';

  /// This matches the project's original NetEase weapi logic more closely:
  /// 1) AES-CBC with fixed key/IV
  /// 2) base64 the encrypted bytes
  /// 3) send it as params + encSecKey
  ///
  static const String _rsaModulusHex =
      '00e0b509f6259df8642dbc35662901477df22677ec152b5ff68ace615bb7b725'
      '152b3ab17a876aea8a5aa76d2e417629ec4ee341f56135fccf695280104e0312'
      'ecbda92557c93870114af6c9d05c4f7f0c3685b7a46bee255932575cce10b424'
      'd813cfe4875d3e82047b97ddef52741d546b8e289dc6935b3ece0462db0a22b8e7';
  static final BigInt _rsaExponent = BigInt.from(65537);

  static Map<String, String> encryptPayload(Map<String, dynamic> payload) {
    final jsonBody = jsonEncode(payload);

    final first = Encrypter(
      AES(
        Key.fromUtf8(fixedKey),
        mode: AESMode.cbc,
      ),
    ).encrypt(
      jsonBody,
      iv: IV.fromUtf8(fixedIV),
    );

    final secretKey = _random16();
    final second = Encrypter(
      AES(
        Key.fromUtf8(secretKey),
        mode: AESMode.cbc,
      ),
    ).encrypt(
      base64.encode(first.bytes),
      iv: IV.fromUtf8(fixedIV),
    );

    return {
      'params': base64.encode(second.bytes),
      'encSecKey': _encryptRSA(secretKey),
    };
  }

  static String _encryptRSA(String secretKey) {
    final reversed = secretKey.split('').reversed.join();
    final message = BigInt.parse(_utf8Hex(reversed), radix: 16);
    final modulus = BigInt.parse(_rsaModulusHex, radix: 16);
    final encrypted = message.modPow(_rsaExponent, modulus);
    return encrypted.toRadixString(16).padLeft(256, '0');
  }

  static String _utf8Hex(String value) {
    return utf8
        .encode(value)
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  static String _random16() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(16, (_) => chars[random.nextInt(chars.length)]).join();
  }
}
