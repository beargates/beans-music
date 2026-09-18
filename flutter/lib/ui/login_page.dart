import 'dart:async';

import 'package:flutter/material.dart';

import '../service/netease_login_repository.dart';

class NeteaseLoginPage extends StatefulWidget {
  final NeteaseLoginRepository repository;

  const NeteaseLoginPage({super.key, required this.repository});

  @override
  State<NeteaseLoginPage> createState() => _NeteaseLoginPageState();
}

class _NeteaseLoginPageState extends State<NeteaseLoginPage> {
  bool _loading = false;
  String? _qrCodeKey;
  Timer? _pollTimer;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _startLogin() async {
    setState(() => _loading = true);
    try {
      final key = await widget.repository.getQrKey();
      setState(() => _qrCodeKey = key);

      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
        if (_qrCodeKey == null) {
          timer.cancel();
          return;
        }

        final status = await widget.repository.pollQrLogin(_qrCodeKey!);
        if (status == 803) {
          timer.cancel();
          if (!mounted) return;
          Navigator.of(context).pop();
          return;
        }

        if (status == 800) {
          timer.cancel();
          setState(() => _qrCodeKey = null);
        }
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final qrUrl = _qrCodeKey == null ? null : widget.repository.buildQrUrl(_qrCodeKey!);

    return Scaffold(
      appBar: AppBar(title: const Text('网易云登录')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_loading)
                const CircularProgressIndicator()
              else if (qrUrl != null)
                Column(
                  children: [
                    const Text('请使用网易云音乐 App 扫码登录'),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SizedBox(
                        width: 220,
                        height: 220,
                        child: Placeholder(
                          child: Center(
                            child: Text('二维码：$qrUrl'),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                ElevatedButton(
                  onPressed: _startLogin,
                  child: const Text('生成登录二维码'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
