import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// リアルタイムデバッグログを管理するシングルトンサービス
class DebugLogService extends ChangeNotifier {
  static final DebugLogService instance = DebugLogService._internal();
  DebugLogService._internal();

  final List<String> _logs = [];
  bool _isVisible = false;

  List<String> get logs => List.unmodifiable(_logs);
  bool get isVisible => _isVisible;

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
    if (_logs.length > 100) {
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
}

/// 画面にオーバーレイ表示するリアルタイムログ枠ウィジェット
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
                                logText.contains('失敗');
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
