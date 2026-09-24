import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/health_provider.dart';

/// スマートフォン内蔵の歩数センサー（Step Counter）と連動し、
/// 今日の歩数を自動取得・計算してHealthProviderに同期するサービス
class StepCounterService {
  StepCounterService._internal();
  static final StepCounterService instance = StepCounterService._internal();

  StreamSubscription<StepCount>? _stepCountSubscription;
  HealthProvider? _healthProvider;

  final ValueNotifier<int> todaySteps = ValueNotifier<int>(0);
  final ValueNotifier<bool> isSensorActive = ValueNotifier<bool>(false);
  final ValueNotifier<String> statusMessage = ValueNotifier<String>('未初期化');

  static const String _prefKeyBaseDate = 'pedometer_base_date';
  static const String _prefKeyBaseSteps = 'pedometer_base_steps';

  /// サービスの初期化（アプリ起動時に呼び出し）
  Future<void> init(HealthProvider healthProvider) async {
    _healthProvider = healthProvider;

    // Web環境では歩数センサー非対応のため安全にスキップ
    if (kIsWeb) {
      statusMessage.value = 'Web版のため端末センサーは無効です';
      return;
    }

    try {
      await _requestPermissionAndStart();
    } catch (e) {
      debugPrint('StepCounterService init error: $e');
      statusMessage.value = '初期化エラー: $e';
    }
  }

  /// 身体活動（歩数計）アクセス権限の要求とセンサーリスニング開始
  Future<void> _requestPermissionAndStart() async {
    statusMessage.value = '権限を確認中...';

    // Android 10 (API 29) 以降は ACTIVITY_RECOGNITION 権限が必要
    PermissionStatus status = await Permission.activityRecognition.status;
    if (!status.isGranted) {
      status = await Permission.activityRecognition.request();
    }

    if (!status.isGranted) {
      statusMessage.value = '身体活動（歩数計）の権限が許可されていません';
      isSensorActive.value = false;
      return;
    }

    statusMessage.value = '歩数センサーに接続中...';

    // 既存の購読をキャンセル
    await _stepCountSubscription?.cancel();

    _stepCountSubscription = Pedometer.stepCountStream.listen(
      _onStepCountReceived,
      onError: _onStepCountError,
      cancelOnError: false,
    );

    isSensorActive.value = true;
    statusMessage.value = '歩数センサー稼働中（自動計測）';
  }

  /// 歩数センサーからの生イベント受信時処理
  Future<void> _onStepCountReceived(StepCount event) async {
    final int rawCumulativeSteps = event.steps;
    final now = DateTime.now();
    final String todayDateStr = DateFormat('yyyy-MM-dd').format(now);

    final prefs = await SharedPreferences.getInstance();
    final String? savedDate = prefs.getString(_prefKeyBaseDate);
    final int? savedBaseSteps = prefs.getInt(_prefKeyBaseSteps);

    int baseSteps;

    // 日付が変わった、または初回記録の場合: 今日の基準歩数として保存
    if (savedDate != todayDateStr || savedBaseSteps == null) {
      baseSteps = rawCumulativeSteps;
      await prefs.setString(_prefKeyBaseDate, todayDateStr);
      await prefs.setInt(_prefKeyBaseSteps, baseSteps);
    } else {
      baseSteps = savedBaseSteps;
      // 端末再起動などで生歩数が基準値を下回った場合の安全リセット
      if (rawCumulativeSteps < baseSteps) {
        baseSteps = rawCumulativeSteps;
        await prefs.setInt(_prefKeyBaseSteps, baseSteps);
      }
    }

    final int calculatedTodaySteps = rawCumulativeSteps - baseSteps;
    final int validSteps = calculatedTodaySteps >= 0 ? calculatedTodaySteps : 0;

    todaySteps.value = validSteps;
    statusMessage.value = '自動計測中: 今日の歩数 $validSteps 歩';

    // HealthProviderを通じて今日の健康記録へ自動反映
    _healthProvider?.updateTodaySteps(validSteps);
  }

  /// センサーエラー時のハンドラ
  void _onStepCountError(dynamic error) {
    debugPrint('StepCountStream error: $error');
    isSensorActive.value = false;
    statusMessage.value = '歩数センサー接続エラー';
  }

  /// 手動での権限再チェック・再接続（設定画面等から呼び出し用）
  Future<void> retryConnection() async {
    if (kIsWeb) return;
    await _requestPermissionAndStart();
  }

  void dispose() {
    _stepCountSubscription?.cancel();
  }
}
