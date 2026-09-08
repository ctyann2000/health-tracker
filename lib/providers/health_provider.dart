import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/health_record.dart';

class HealthProvider with ChangeNotifier {
  List<HealthRecord> _records = [];
  bool _isLoading = true;

  List<HealthRecord> get records => _records;
  bool get isLoading => _isLoading;

  HealthProvider() {
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final String? recordsJson = prefs.getString('health_records');
    
    if (recordsJson != null) {
      final List<dynamic> decoded = jsonDecode(recordsJson);
      _records = decoded.map((e) => HealthRecord.fromJson(e)).toList();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_records.map((e) => e.toJson()).toList());
    await prefs.setString('health_records', encoded);
  }

  void addRecord(HealthRecord record) {
    _mergeRecordInternal(record);
    notifyListeners();
    saveRecords();
  }

  void _mergeRecordInternal(HealthRecord record) {
    // 同じ日付の記録があれば上書きするか、単純に追加するか。
    final index = _records.indexWhere((r) => 
        r.date.year == record.date.year && 
        r.date.month == record.date.month && 
        r.date.day == record.date.day);

    if (index >= 0) {
      final existing = _records[index];
      
      final newScore = record.conditionScore ?? existing.conditionScore;
      final newSymptoms = {...existing.symptoms, ...record.symptoms}.toList();
      
      final medsMap = <String, Medication>{};
      for (var m in [...existing.medications, ...record.medications]) {
        medsMap['${m.name.trim()}_${m.time}'] = m;
      }
      final newMedications = medsMap.values.toList();
      
      final workoutMap = <String, Workout>{};
      for (var w in [...existing.workouts, ...record.workouts]) {
        workoutMap[w.name.trim()] = w;
      }
      final newWorkouts = workoutMap.values.toList();
      
      final newWeight = record.weight ?? existing.weight;
      final newSteps = record.steps ?? existing.steps;
      final newBodyFat = record.bodyFat ?? existing.bodyFat;
      final newBmi = record.bmi ?? existing.bmi;
      final newBmr = record.bmr ?? existing.bmr;
      final newCalories = record.calories ?? existing.calories;
      final newSleepHours = record.sleepHours ?? existing.sleepHours;

      _records[index] = HealthRecord(
        date: existing.date,
        conditionScore: newScore,
        symptoms: newSymptoms,
        medications: newMedications,
        weight: newWeight,
        steps: newSteps,
        workouts: newWorkouts,
        bodyFat: newBodyFat,
        bmi: newBmi,
        bmr: newBmr,
        calories: newCalories,
        sleepHours: newSleepHours,
      );
    } else {
      _records.add(record);
    }
  }

  // 特定の日付の記録を取得するヘルパー
  HealthRecord? getRecordForDate(DateTime date) {
    try {
      return _records.firstWhere((r) => 
          r.date.year == date.year && 
          r.date.month == date.month && 
          r.date.day == date.day);
    } catch (e) {
      return null;
    }
  }

  // 直近7日間のデータを取得するヘルパー
  List<HealthRecord> getRecentRecords(int days) {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));
    
    return _records.where((r) {
      final rDate = DateTime(r.date.year, r.date.month, r.date.day);
      return rDate.isAfter(startDate.subtract(const Duration(days: 1)));
    }).toList();
  }

  // --- ローカルバックアップ用ヘルパー ---

  /// 全データを整形済みJSON文字列としてエクスポート
  String exportJson() {
    final list = _records.map((e) => e.toJson()).toList();
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(list);
  }

  /// JSON文字列からデータを復元（マージまたは上書き）
  Future<int> importJson(String jsonString, {bool overwrite = false}) async {
    final dynamic decoded;
    try {
      decoded = jsonDecode(jsonString);
    } catch (e) {
      throw const FormatException('JSON形式が正しくありません。構文をご確認ください。');
    }

    if (decoded is! List) {
      throw const FormatException('バックアップデータが配列形式（List）ではありません。');
    }

    if (decoded.isEmpty) {
      throw const FormatException('復元対象のデータが空です。有効なデータ配列を指定してください。');
    }

    final List<HealthRecord> importedRecords = [];
    for (int i = 0; i < decoded.length; i++) {
      final item = decoded[i];
      if (item is! Map) {
        throw FormatException('${i + 1}件目のデータがオブジェクト形式ではありません。');
      }
      try {
        importedRecords.add(HealthRecord.fromJson(Map<String, dynamic>.from(item)));
      } catch (e) {
        throw FormatException('${i + 1}件目のレコード解析に失敗しました: $e');
      }
    }

    if (overwrite) {
      _records = importedRecords;
    } else {
      for (var record in importedRecords) {
        _mergeRecordInternal(record);
      }
    }

    // 日付昇順で整列
    _records.sort((a, b) => a.date.compareTo(b.date));

    notifyListeners();
    await saveRecords();
    return importedRecords.length;
  }

  /// 全データを初期化（削除）
  Future<void> clearAllRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('health_records');
    _records.clear();
    notifyListeners();
  }
}
