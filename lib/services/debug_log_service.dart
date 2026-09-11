import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/eruda_controller.dart';

/// リアルタイムデバッグログを管理するシングルトンサービス
class DebugLogService extends ChangeNotifier {
  static final DebugLogService instance = DebugLogService._internal();
  DebugLogService._internal();

  static const String _prefKeyDebugMode = 'pref_debug_mode_enabled';

  final List<String> _logs = [];
  bool _isDebugModeEnabled = false;
  bool _isVisible = false;

  List<String> get logs => List.unmodifiable(_logs);
  bool get isDebugModeEnabled => _isDebugModeEnabled;
  bool get isVisible => _isVisible;

  /// アプリ起動時の設定ロード
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDebugModeEnabled = prefs.getBool(_prefKeyDebugMode) ?? false;
      _isVisible = _isDebugModeEnabled;
      setErudaVisible(_isDebugModeEnabled);
      notifyListeners();
    } catch (_) {}
  }

  /// デバッグモード（画面上のオーバーレイ ＆ Erudaツール）のON/OFF
  Future<void> setDebugModeEnabled(bool enabled) async {
    _isDebugModeEnabled = enabled;
    _isVisible = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyDebugMode, enabled);
    } catch (_) {}
    setErudaVisible(enabled);
    notifyListeners();
  }

  void toggleVisibility() {
    _isVisible = !_isVisible;
    notifyListeners();
  }

  void log(String message) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}';
    final entry = '[$timeStr] $message';
    _logs.add(entry);
    if (_logs.length > 200) {
      _logs.removeAt(0);
    }
    // ignore: avoid_print
    print('[DEBUG_LOG] $entry');
    notifyListeners();
  }

  void clear() {
    _logs.clear();
    notifyListeners();
  }

  Future<void> copyToClipboard(BuildContext context) async {
    final text = _logs.join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ログをクリップボードにコピーしました'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// 設定画面などから呼び出す「システム調査ログ」ダイアログ
  static void showLogDialog(BuildContext context) {
    final service = DebugLogService.instance;
    showDialog(
      context: context,
      builder: (ctx) => ListenableBuilder(
        listenable: service,
        builder: (context, _) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.terminal, color: Colors.greenAccent, size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'システム診断・調査ログ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 420,
              child: Column(
                children: [
                  // 画面上のデバッグモード連動スイッチ
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.bug_report, color: Colors.greenAccent, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            '画面上にログ枠・ツールを表示',
                            style: TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ),
                        Switch(
                          value: service.isDebugModeEnabled,
                          activeColor: Colors.greenAccent,
                          onChanged: (val) => service.setDebugModeEnabled(val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // ログ一覧エリア
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: service.logs.isEmpty
                          ? const Center(
                              child: Text(
                                '記録されたログはありません',
                                style: TextStyle(color: Colors.white38, fontSize: 12),
                              ),
                            )
                          : ListView.builder(
                              reverse: true,
                              itemCount: service.logs.length,
                              itemBuilder: (context, index) {
                                final logText = service.logs[service.logs.length - 1 - index];
                                final isError = logText.contains('エラー') ||
                                    logText.contains('ERROR') ||
                                    logText.contains('失敗') ||
                                    logText.contains('例外');
                                final isSuccess = logText.contains('✓') ||
                                    logText.contains('成功') ||
                                    logText.contains('検知');
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 1.5),
                                  child: SelectableText(
                                    logText,
                                    style: TextStyle(
                                      color: isError
                                          ? Colors.redAccent
                                          : (isSuccess ? Colors.greenAccent : Colors.white70),
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                label: const Text('クリア', style: TextStyle(color: Colors.redAccent)),
                onPressed: service.logs.isEmpty ? null : service.clear,
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A86B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('全ログをコピー'),
                onPressed: service.logs.isEmpty ? null : () => service.copyToClipboard(context),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 画面にオーバーレイ表示するリアルタイムログ枠ウィジェット
/// ※ isDebugModeEnabled が false の場合は一切画面に描画されません
class DebugLogOverlay extends StatelessWidget {
  final double height;
  final Alignment alignment;
  final EdgeInsets? margin;

  const DebugLogOverlay({
    super.key,
    this.height = 140,
    this.alignment = Alignment.bottomCenter,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final service = DebugLogService.instance;

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        // デバッグモードがOFFの場合は完全に非表示（ボタンも含め一切描画しない）
        if (!service.isDebugModeEnabled) {
          return const SizedBox.shrink();
        }

        if (!service.isVisible) {
          return Align(
            alignment: alignment == Alignment.topCenter ? Alignment.topLeft : Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FloatingActionButton.small(
                heroTag: 'show_debug_log_btn_${alignment.toString()}',
                backgroundColor: Colors.black87,
                onPressed: service.toggleVisibility,
                child: const Icon(Icons.bug_report, color: Colors.greenAccent, size: 20),
              ),
            ),
          );
        }

        return Align(
          alignment: alignment,
          child: Container(
            height: height,
            width: double.infinity,
            margin: margin ?? const EdgeInsets.all(8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.6), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ヘッダー行
                Row(
                  children: [
                    const Icon(Icons.terminal, color: Colors.greenAccent, size: 16),
                    const SizedBox(width: 6),
                    const Text(
                      'ライブ調査ログ',
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    // コピーボタン
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.white70, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'ログをコピー',
                      onPressed: () => service.copyToClipboard(context),
                    ),
                    const SizedBox(width: 8),
                    // クリアボタン
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.white70, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'クリア',
                      onPressed: service.clear,
                    ),
                    const SizedBox(width: 8),
                    // 最小化ボタン
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: '隠す',
                      onPressed: service.toggleVisibility,
                    ),
                  ],
                ),
                const Divider(color: Colors.white24, height: 6),
                // ログ本文スクロール
                Expanded(
                  child: service.logs.isEmpty
                      ? const Center(
                          child: Text(
                            'ログ待機中...（QR読取または写真解析を実行してください）',
                            style: TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        )
                      : ListView.builder(
                          reverse: true, // 最新ログを下部に
                          itemCount: service.logs.length,
                          itemBuilder: (context, index) {
                            final logText = service.logs[service.logs.length - 1 - index];
                            final isError = logText.contains('エラー') ||
                                logText.contains('ERROR') ||
                                logText.contains('失敗') ||
                                logText.contains('例外');
                            final isSuccess = logText.contains('✓') ||
                                logText.contains('成功') ||
                                logText.contains('検知');
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 1),
                              child: Text(
                                logText,
                                style: TextStyle(
                                  color: isError
                                      ? Colors.redAccent
                                      : (isSuccess ? Colors.greenAccent : Colors.white),
                                  fontSize: 10.5,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
