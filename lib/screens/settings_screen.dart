import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/health_provider.dart';
import '../services/gemini_service.dart';
import '../services/debug_log_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: AppBar(
              title: Text(
                '設定・管理',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.primary,
                  letterSpacing: 1.0,
                ),
              ),
              backgroundColor: Colors.white.withOpacity(0.65),
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(
                  color: Colors.white.withOpacity(0.7),
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Color(0xFFFDFBFB),
              Color(0xFFEBEDEE),
            ],
          ),
        ),
        child: SafeArea(
          child: Consumer<HealthProvider>(
            builder: (context, provider, child) {
              final totalRecords = provider.records.length;

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(
                  top: 16.0,
                  left: 16.0,
                  right: 16.0,
                  bottom: 32.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- セクション1: アプリ仕様・プライバシー ---
                    _buildSectionHeader('アプリ情報 & プライバシー'),
                    const SizedBox(height: 10),
                    _buildGlassCard(
                      child: Column(
                        children: [
                          _buildInfoRow(
                            icon: Icons.person_outline,
                            iconColor: Colors.blueAccent,
                            title: '利用モード',
                            value: '個人専用（スタンドアロン）',
                          ),
                          const Divider(height: 18),
                          _buildInfoRow(
                            icon: Icons.cloud_off_outlined,
                            iconColor: Colors.teal,
                            title: 'クラウド連携',
                            value: '完全無効（外部送信なし）',
                          ),
                          const Divider(height: 18),
                          _buildInfoRow(
                            icon: Icons.sd_storage_outlined,
                            iconColor: Colors.deepPurpleAccent,
                            title: '保存先',
                            value: '端末内ローカルストレージ',
                          ),
                          const Divider(height: 18),
                          _buildInfoRow(
                            icon: Icons.receipt_long_outlined,
                            iconColor: Colors.orangeAccent,
                            title: '登録レコード数',
                            value: '$totalRecords 件',
                          ),
                        ],
                      ),
                    ).animate().fade().slideY(begin: 0.05),

                    const SizedBox(height: 28),

                    // --- セクション2: ローカルバックアップ & 復元 ---
                    _buildSectionHeader('データバックアップ & 復元'),
                    const SizedBox(height: 10),
                    _buildGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'クラウドを使わずに、端末内に保存された健康・服薬・運動データをファイルやテキストとして安全に退避・復元できます。',
                            style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.5),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: totalRecords == 0
                                      ? null
                                      : () => _showExportDialog(context, provider),
                                  icon: const Icon(Icons.file_download_outlined, size: 18),
                                  label: const Text('エクスポート'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).colorScheme.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _showImportDialog(context, provider),
                                  icon: const Icon(Icons.file_upload_outlined, size: 18),
                                  label: const Text('インポート'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Theme.of(context).colorScheme.primary,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    side: BorderSide(
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ).animate().fade(delay: 100.ms).slideY(begin: 0.05),

                    const SizedBox(height: 28),

                    // --- セクション3: AI設定 ---
                    _buildSectionHeader('AI解析エンジン'),
                    const SizedBox(height: 10),
                    _buildGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow(
                            icon: Icons.auto_awesome_outlined,
                            iconColor: Colors.amber.shade700,
                            title: '最優先モデル',
                            value: 'flash-lite-latest (自動追従)',
                          ),
                          const Divider(height: 18),
                          _buildInfoRow(
                            icon: Icons.speed_outlined,
                            iconColor: Colors.blueAccent,
                            title: 'フォールバック',
                            value: '3.5-lite → 3.1-lite → 2.5-lite',
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            '※ 無料枠のレート制限に配慮し、常に最新のFlash-Liteを自動追従して最優先稼働するよう最適化されています。',
                            style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _showApiKeyDialog(context),
                                  icon: const Icon(Icons.key_outlined, size: 16),
                                  label: const Text('APIキー設定'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.blueAccent,
                                    side: BorderSide(color: Colors.blueAccent.withOpacity(0.5)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _showModelsDialog(context),
                                  icon: const Icon(Icons.travel_explore_outlined, size: 16),
                                  label: const Text('モデル一覧確認'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.amber.shade900,
                                    side: BorderSide(color: Colors.amber.shade700.withOpacity(0.5)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ).animate().fade(delay: 200.ms).slideY(begin: 0.05),

                    const SizedBox(height: 28),

                    // --- セクション4: 危険エリア（データ初期化） ---
                    _buildSectionHeader('データ初期化'),
                    const SizedBox(height: 10),
                    _buildGlassCard(
                      borderColor: Colors.redAccent.withOpacity(0.3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '端末内に保存されているすべての健康データを完全に削除します。テストデータを一新したい場合などにご利用ください。',
                            style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.5),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: totalRecords == 0
                                  ? null
                                  : () => _confirmClearData(context, provider),
                              icon: Icon(
                                Icons.delete_forever_outlined,
                                color: totalRecords == 0 ? Colors.black26 : Colors.redAccent,
                              ),
                              label: Text(
                                'すべてのデータを削除（リセット）',
                                style: TextStyle(
                                  color: totalRecords == 0 ? Colors.black26 : Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: totalRecords == 0 ? Colors.black12 : Colors.redAccent.withOpacity(0.4),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fade(delay: 300.ms).slideY(begin: 0.05),

                    const SizedBox(height: 28),

                    // --- セクション5: システム診断 & デバッグ ---
                    _buildSectionHeader('システム診断 & 開発者ログ'),
                    const SizedBox(height: 10),
                    _buildGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '不具合調査やQRコード解析の診断ログを確認・コピーしたり、画面上に開発者ツールを表示できます。',
                            style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.5),
                          ),
                          const SizedBox(height: 14),
                          // ログ表示ダイアログを開くボタン
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => DebugLogService.showLogDialog(context),
                              icon: const Icon(Icons.terminal, size: 18),
                              label: const Text('システム調査ログを表示'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E293B),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fade(delay: 400.ms).slideY(begin: 0.05),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E293B),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 4,
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF334155),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          flex: 5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.9)),
            ),
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF475569),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlassCard({required Widget child, Color? borderColor}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.65),
                Colors.white.withOpacity(0.35),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: borderColor ?? Colors.white.withOpacity(0.85),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildGlassDialog({
    required BuildContext context,
    required Widget title,
    required Widget content,
    required List<Widget> actions,
  }) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: 16),
                Flexible(child: content),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- エクスポートダイアログ ---
  void _showExportDialog(BuildContext context, HealthProvider provider) {
    final jsonStr = provider.exportJson();

    showDialog(
      context: context,
      builder: (ctx) => _buildGlassDialog(
        context: ctx,
        title: const Row(
          children: [
            Icon(Icons.file_download_outlined, color: Colors.blueAccent),
            SizedBox(width: 8),
            Text('データのエクスポート', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '以下のバックアップ用JSONデータをコピーして、メモ帳等に保存してください。',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Container(
              height: 180,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  jsonStr,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('閉じる'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              try {
                await Clipboard.setData(ClipboardData(text: jsonStr));
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ バックアップデータをクリップボードにコピーしました！'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('クリップボードへのコピーに失敗しました: $e')),
                  );
                }
              }
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('コピーする'),
          ),
        ],
      ),
    );
  }

  // --- インポートダイアログ ---
  void _showImportDialog(BuildContext screenContext, HealthProvider provider) {
    final textController = TextEditingController();
    bool overwrite = false;
    bool isProcessing = false;

    showDialog(
      context: screenContext,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogStateCtx, setDialogState) => _buildGlassDialog(
          context: dialogCtx,
          title: const Row(
            children: [
              Icon(Icons.file_upload_outlined, color: Colors.teal),
              SizedBox(width: 8),
              Text('データのインポート', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '保存してあるバックアップJSONデータを貼り付けてください。',
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: textController,
                  enabled: !isProcessing,
                  maxLines: 6,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  decoration: InputDecoration(
                    hintText: '[{"date": "2026-08-13", ...}]',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.black12),
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 10),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('既存データをすべて上書き（置き換え）する', style: TextStyle(fontSize: 12)),
                  subtitle: const Text('チェックを外すと、既存データにマージ（統合）されます', style: TextStyle(fontSize: 10, color: Colors.black54)),
                  value: overwrite,
                  onChanged: isProcessing ? null : (val) => setDialogState(() => overwrite = val ?? false),
                ),
                if (isProcessing) ...[
                  const SizedBox(height: 12),
                  const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 10),
                        Text('復元処理中...', style: TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isProcessing ? null : () => Navigator.pop(dialogCtx),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: isProcessing
                  ? null
                  : () async {
                      final input = textController.text.trim();
                      if (input.isEmpty) {
                        ScaffoldMessenger.of(screenContext).showSnackBar(
                          const SnackBar(content: Text('データを貼り付けてください。')),
                        );
                        return;
                      }

                      setDialogState(() => isProcessing = true);

                      try {
                        final count = await provider.importJson(input, overwrite: overwrite);
                        if (dialogCtx.mounted) {
                          Navigator.pop(dialogCtx);
                        }
                        if (screenContext.mounted) {
                          ScaffoldMessenger.of(screenContext).showSnackBar(
                            SnackBar(
                              content: Text('🎉 $count 件のデータを正常に復元しました！'),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: Colors.teal.shade700,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isProcessing = false);
                        if (screenContext.mounted) {
                          ScaffoldMessenger.of(screenContext).showSnackBar(
                            SnackBar(
                              content: Text('❌ 復元に失敗しました: $e'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      }
                    },
              child: const Text('復元を実行'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      textController.dispose();
    });
  }

  // --- 全削除確認ダイアログ ---
  void _confirmClearData(BuildContext screenContext, HealthProvider provider) {
    bool isProcessing = false;

    showDialog(
      context: screenContext,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogStateCtx, setDialogState) => _buildGlassDialog(
          context: dialogCtx,
          title: const Text('データの全削除', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
          content: isProcessing
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('データを削除しています...'),
                  ],
                )
              : const Text('本当にすべての記録を削除しますか？\nこの操作は元に戻せません。（事前にエクスポートしておくことを推奨します）'),
          actions: isProcessing
              ? []
              : [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text('キャンセル'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                    onPressed: () async {
                      setDialogState(() => isProcessing = true);
                      try {
                        await provider.clearAllRecords();
                        if (dialogCtx.mounted) {
                          Navigator.pop(dialogCtx);
                        }
                        if (screenContext.mounted) {
                          ScaffoldMessenger.of(screenContext).showSnackBar(
                            const SnackBar(content: Text('すべてのデータを消去しました。')),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isProcessing = false);
                        if (screenContext.mounted) {
                          ScaffoldMessenger.of(screenContext).showSnackBar(
                            SnackBar(content: Text('データの削除に失敗しました: $e'), backgroundColor: Colors.redAccent),
                          );
                        }
                      }
                    },
                    child: const Text('完全に消去'),
                  ),
                ],
        ),
      ),
    );
  }

  // --- Gemini APIキー設定ダイアログ ---
  void _showApiKeyDialog(BuildContext screenContext) {
    final geminiService = GeminiService();
    final controller = TextEditingController();
    bool isObscured = true;

    showDialog(
      context: screenContext,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return FutureBuilder<String>(
            future: geminiService.getApiKey(),
            builder: (context, snapshot) {
              final currentKey = snapshot.data ?? '';
              final isKeyConfigured = currentKey.isNotEmpty;

              return _buildGlassDialog(
                context: dialogCtx,
                title: const Row(
                  children: [
                    Icon(Icons.key, color: Colors.blueAccent),
                    SizedBox(width: 8),
                    Text('Gemini APIキー設定', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isKeyConfigured ? Colors.green.shade50 : Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isKeyConfigured ? Colors.green.shade200 : Colors.amber.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isKeyConfigured ? Icons.check_circle : Icons.warning_amber_rounded,
                              color: isKeyConfigured ? Colors.green.shade700 : Colors.amber.shade800,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isKeyConfigured
                                    ? 'APIキー設定済み（端末内に安全に保存されています）'
                                    : 'APIキー未設定です。以下に入力して保存してください。',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isKeyConfigured ? Colors.green.shade900 : Colors.amber.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Google AI Studioで取得したAPIキーを入力してください。ブラウザ・端末のローカルストレージにのみ保存され、外部サーバーには送信されません。',
                        style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: controller,
                        obscureText: isObscured,
                        decoration: InputDecoration(
                          hintText: isKeyConfigured ? '新しいAPIキーを入力して上書き' : 'AIzaSy...',
                          labelText: 'Gemini API Key',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.vpn_key_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(isObscured ? Icons.visibility_off : Icons.visibility),
                            onPressed: () {
                              setDialogState(() {
                                isObscured = !isObscured;
                              });
                            },
                          ),
                        ),
                      ),
                      if (isKeyConfigured) ...[
                        const SizedBox(height: 12),
                        Text(
                          '現在のキー: ${currentKey.length > 8 ? "${currentKey.substring(0, 6)}...${currentKey.substring(currentKey.length - 4)}" : "******"}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'monospace'),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  if (isKeyConfigured)
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                      onPressed: () async {
                        await geminiService.clearApiKey();
                        if (dialogCtx.mounted) {
                          Navigator.pop(dialogCtx);
                        }
                        if (screenContext.mounted) {
                          ScaffoldMessenger.of(screenContext).showSnackBar(
                            const SnackBar(content: Text('APIキーを削除しました')),
                          );
                        }
                      },
                      child: const Text('キー削除'),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text('閉じる'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final input = controller.text.trim();
                      if (input.isEmpty) {
                        ScaffoldMessenger.of(screenContext).showSnackBar(
                          const SnackBar(content: Text('APIキーを入力してください')),
                        );
                        return;
                      }
                      await geminiService.saveApiKey(input);
                      if (dialogCtx.mounted) {
                        Navigator.pop(dialogCtx);
                      }
                      if (screenContext.mounted) {
                        ScaffoldMessenger.of(screenContext).showSnackBar(
                          const SnackBar(
                            content: Text('✅ APIキーを保存しました！AI機能をご利用いただけます。'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(screenContext).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('保存'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // --- 最新AIモデル確認ダイアログ ---
  void _showModelsDialog(BuildContext screenContext) {
    showDialog(
      context: screenContext,
      builder: (dialogCtx) => FutureBuilder<List<Map<String, dynamic>>>(
        future: GeminiService().fetchLiteModels(),
        builder: (context, snapshot) {
          Widget content;
          if (snapshot.connectionState == ConnectionState.waiting) {
            content = const SizedBox(
              height: 180,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Google APIに問い合わせ中...', style: TextStyle(fontSize: 13, color: Colors.black54)),
                  ],
                ),
              ),
            );
          } else if (snapshot.hasError) {
            content = SizedBox(
              height: 160,
              child: Center(
                child: Text(
                  '❌ モデル情報の取得に失敗しました:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                ),
              ),
            );
          } else {
            final models = snapshot.data ?? [];
            content = SizedBox(
              width: double.maxFinite,
              height: 340,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: Colors.amber.shade800, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            '最優先設定: gemini-flash-lite-latest (常時最新追従)',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'APIからリアルタイム取得したLite系モデル一覧:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: models.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final m = models[index];
                        final rawName = m['name'] as String? ?? '';
                        final shortName = rawName.replaceAll('models/', '');
                        final displayName = m['displayName'] as String? ?? shortName;
                        final isLatest = shortName.contains('latest') || shortName.contains('3.5');

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isLatest ? Colors.amber.shade400 : Colors.black12,
                              width: isLatest ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      displayName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                  if (isLatest)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade100,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '最新',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                rawName,
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.blueGrey),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }

          return _buildGlassDialog(
            context: dialogCtx,
            title: const Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.amber),
                SizedBox(width: 8),
                Text('利用可能なGeminiモデル', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: content,
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('閉じる'),
              ),
            ],
          );
        },
      ),
    );
  }
}
