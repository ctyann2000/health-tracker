import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/health_record.dart';
import '../models/prescription_record.dart';
import '../utils/medication_normalizer.dart';

class HealthProvider with ChangeNotifier {
  List<HealthRecord> _records = [];
  List<PrescriptionRecord> _prescriptions = [];
  bool _isLoading = true;

  List<HealthRecord> get records => _records;
  List<PrescriptionRecord> get prescriptions => _prescriptions;
  bool get isLoading => _isLoading;

  HealthProvider() {
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. 体調・服薬記録の読み込み
    final String? recordsJson = prefs.getString('health_records');
    if (recordsJson != null) {
      final List<dynamic> decoded = jsonDecode(recordsJson);
      _records = decoded.map((e) => HealthRecord.fromJson(e)).toList();
    }

    // 2. お薬手帳・処方箋データの読み込み
    final String? presJson = prefs.getString('prescription_records');
    if (presJson != null) {
      final List<dynamic> decodedPres = jsonDecode(presJson);
      _prescriptions = decodedPres.map((e) => PrescriptionRecord.fromJson(e)).toList();
    } else {
      // 初回起動時: ユーザーの処方箋実例（栗田皮フ科）をサンプルとして初期プリセット
      _prescriptions = getInitialSamplePrescriptions();
      await savePrescriptions();
    }

    // 3. 既存の服薬記録に同一薬の重複（一般名と正式名など）があれば自動名寄せ・統合
    final bool sanitized = sanitizeExistingMedications();
    if (sanitized) {
      await saveRecords();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_records.map((e) => e.toJson()).toList());
    await prefs.setString('health_records', encoded);
  }

  Future<void> savePrescriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_prescriptions.map((e) => e.toJson()).toList());
    await prefs.setString('prescription_records', encoded);
  }

  void addRecord(HealthRecord record) {
    _mergeRecordInternal(record);
    notifyListeners();
    saveRecords();
  }

  /// 歩数センサーからの自動同期用: 今日の歩数のみを更新
  void updateTodaySteps(int steps) {
    if (steps < 0) return;
    final now = DateTime.now();
    final index = _records.indexWhere((r) =>
        r.date.year == now.year &&
        r.date.month == now.month &&
        r.date.day == now.day);

    if (index >= 0) {
      final existing = _records[index];
      if (existing.steps == steps) return;
      _records[index] = existing.copyWith(steps: steps);
    } else {
      _records.add(HealthRecord(
        date: DateTime(now.year, now.month, now.day),
        steps: steps,
      ));
      _records.sort((a, b) => a.date.compareTo(b.date));
    }
    notifyListeners();
    saveRecords();
  }

  /// 特定の日付の記録を完全に上書き・更新（編集内容で置換）
  void updateRecord(HealthRecord record) {
    final index = _records.indexWhere((r) =>
        r.date.year == record.date.year &&
        r.date.month == record.date.month &&
        r.date.day == record.date.day);

    if (index >= 0) {
      _records[index] = record;
    } else {
      _records.add(record);
    }
    _records.sort((a, b) => a.date.compareTo(b.date));
    notifyListeners();
    saveRecords();
  }

  /// 特定の日付の記録を削除
  void deleteRecord(DateTime date) {
    _records.removeWhere((r) =>
        r.date.year == date.year &&
        r.date.month == date.month &&
        r.date.day == date.day);
    notifyListeners();
    saveRecords();
  }

  /// 特定の日付の記録から特定の症状を取り除く
  void removeSymptoms(DateTime date, List<String> symptomsToRemove) {
    final index = _records.indexWhere((r) =>
        r.date.year == date.year &&
        r.date.month == date.month &&
        r.date.day == date.day);

    if (index >= 0) {
      final existing = _records[index];
      final toRemoveNorm = symptomsToRemove.map((s) => s.trim().toLowerCase()).toSet();
      final updatedSymptoms = existing.symptoms.where((s) {
        final sNorm = s.trim().toLowerCase();
        return !toRemoveNorm.any((target) => sNorm == target || sNorm.contains(target) || target.contains(sNorm));
      }).toList();

      // 症状が除去されて無くなった場合、誤判定で下げられていた体調スコアを正常値へ復帰
      int? updatedScore = existing.conditionScore;
      if (updatedSymptoms.isEmpty && updatedScore != null && updatedScore < 5) {
        updatedScore = 7;
      }

      _records[index] = HealthRecord(
        date: existing.date,
        conditionScore: updatedScore,
        symptoms: updatedSymptoms,
        medications: existing.medications,
        weight: existing.weight,
        steps: existing.steps,
        workouts: existing.workouts,
        bodyFat: existing.bodyFat,
        bmi: existing.bmi,
        bmr: existing.bmr,
        calories: existing.calories,
        sleepHours: existing.sleepHours,
      );

      notifyListeners();
      saveRecords();
    }
  }

  /// 特定の日付の記録のすべての症状をクリアする
  void clearSymptoms(DateTime date) {
    final index = _records.indexWhere((r) =>
        r.date.year == date.year &&
        r.date.month == date.month &&
        r.date.day == date.day);

    if (index >= 0) {
      final existing = _records[index];
      int? updatedScore = existing.conditionScore;
      if (updatedScore != null && updatedScore < 5) {
        updatedScore = 7;
      }

      _records[index] = HealthRecord(
        date: existing.date,
        conditionScore: updatedScore,
        symptoms: [],
        medications: existing.medications,
        weight: existing.weight,
        steps: existing.steps,
        workouts: existing.workouts,
        bodyFat: existing.bodyFat,
        bmi: existing.bmi,
        bmr: existing.bmr,
        calories: existing.calories,
        sleepHours: existing.sleepHours,
      );

      notifyListeners();
      saveRecords();
    }
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
      
      // 薬品リストをMedicationNormalizerを用いて同一薬を1つに名寄せ統合
      final newMedications = _sanitizeMedicationsList([
        ...existing.medications,
        ...record.medications,
      ]);
      
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
      // 新規レコード追加時も薬品リストを名寄せサニタイズ
      final sanitizedMeds = _sanitizeMedicationsList(record.medications);
      _records.add(record.copyWith(medications: sanitizedMeds));
    }
  }

  /// 薬品リストを名寄せ・重複統合する
  List<Medication> _sanitizeMedicationsList(List<Medication> meds) {
    if (meds.isEmpty) return [];

    final presMedNames = _prescriptions
        .expand((p) => p.medications.map((m) => m.name))
        .toList();
    final List<Medication> result = [];

    for (var med in meds) {
      if (med.name.trim().isEmpty) continue;

      // 既存のリスト内に同一薬が存在するか判定
      final existIndex = result.indexWhere((r) =>
          MedicationNormalizer.isSameMedication(r.name, med.name, presMedNames));

      if (existIndex >= 0) {
        final existing = result[existIndex];
        // 服薬時間: '処方' は仮ステータスなので、具体的な時間帯（'朝'など）や非'処方'を優先
        String? mergedTime = existing.time;
        if (mergedTime == null || mergedTime == '処方') {
          mergedTime = (med.time != null && med.time != '処方') ? med.time : mergedTime;
        }

        // 代表名（一般名）に正規化
        final normExisting = MedicationNormalizer.normalize(existing.name);
        final normNew = MedicationNormalizer.normalize(med.name);
        final canonicalName = normExisting.isNotEmpty ? normExisting : normNew;

        result[existIndex] = Medication(
          name: canonicalName.isNotEmpty ? canonicalName : existing.name,
          time: mergedTime,
        );
      } else {
        // 新規薬品: 代表名（一般名）に正規化して登録
        final canonicalName = MedicationNormalizer.normalize(med.name);
        result.add(Medication(
          name: canonicalName.isNotEmpty ? canonicalName : med.name.trim(),
          time: med.time,
        ));
      }
    }

    return result;
  }

  /// 既存の全レコードをスキャンし、過去の重複・表記ゆれ薬品を自動統合・正規化
  bool sanitizeExistingMedications() {
    bool changed = false;
    for (int i = 0; i < _records.length; i++) {
      final r = _records[i];
      if (r.medications.isEmpty) continue;

      final sanitized = _sanitizeMedicationsList(r.medications);
      if (!_areMedListsEqual(sanitized, r.medications)) {
        _records[i] = r.copyWith(medications: sanitized);
        changed = true;
      }
    }
    return changed;
  }

  bool _areMedListsEqual(List<Medication> a, List<Medication> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].name != b[i].name || a[i].time != b[i].time) return false;
    }
    return true;
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

  /// 指定した年月（Year, Month）の記録を日付昇順（古い順）で取得するヘルパー
  List<HealthRecord> getRecordsForMonth(DateTime month) {
    final filtered = _records.where((r) =>
        r.date.year == month.year && r.date.month == month.month).toList();
    filtered.sort((a, b) => a.date.compareTo(b.date));
    return filtered;
  }

  /// 直近30日間の服薬実績およびお薬手帳の処方薬から、服用頻度の高い薬品名の代表名リストを取得
  List<String> getRecentMonthMeds() {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));

    final Map<String, int> medFrequency = {};

    // 1. 直近30日間の服薬実績を集計
    for (var r in _records) {
      final rDate = DateTime(r.date.year, r.date.month, r.date.day);
      if (!rDate.isBefore(startDate)) {
        for (var m in r.medications) {
          final canonical = MedicationNormalizer.normalize(m.name);
          if (canonical.isNotEmpty) {
            medFrequency[canonical] = (medFrequency[canonical] ?? 0) + 1;
          }
        }
      }
    }

    // 2. お薬手帳の処方薬も集計に含める
    for (var p in _prescriptions) {
      for (var m in p.medications) {
        final canonical = MedicationNormalizer.normalize(m.name);
        if (canonical.isNotEmpty) {
          medFrequency[canonical] = (medFrequency[canonical] ?? 0) + 1;
        }
      }
    }

    // 頻度降順でソート
    final sortedMeds = medFrequency.keys.toList()
      ..sort((a, b) => medFrequency[b]!.compareTo(medFrequency[a]!));

    // 実績が少ない場合の代表的・常用候補（重複なく末尾に補完）
    final defaultCandidates = [
      'エペリゾン',
      'ミグシス',
      'ナラトリプタン',
      'ロキソプロフェン',
      '川芎茶調散',
      'ヒルドイド',
      'レボセチリジン',
      'カロナール',
    ];

    for (var def in defaultCandidates) {
      if (!sortedMeds.contains(def)) {
        sortedMeds.add(def);
      }
    }

    return sortedMeds;
  }

  /// 直近30日間の症状履歴から、頻度の高い症状名リストを取得
  List<String> getRecentMonthSymptoms() {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));

    final Map<String, int> symptomFreq = {};

    for (var r in _records) {
      final rDate = DateTime(r.date.year, r.date.month, r.date.day);
      if (!rDate.isBefore(startDate)) {
        for (var s in r.symptoms) {
          final clean = s.trim();
          if (clean.isNotEmpty) {
            symptomFreq[clean] = (symptomFreq[clean] ?? 0) + 1;
          }
        }
      }
    }

    final sorted = symptomFreq.keys.toList()
      ..sort((a, b) => symptomFreq[b]!.compareTo(symptomFreq[a]!));

    final defaultCandidates = [
      '頭痛',
      '肩こり',
      '首の痛み',
      '倦怠感・だるさ',
      'めまい',
      '胃痛・もたれ',
      '腰痛',
    ];

    for (var def in defaultCandidates) {
      if (!sorted.contains(def)) {
        sorted.add(def);
      }
    }

    return sorted;
  }

  /// AIヘルスコーチ向けに、全期間の健康記録・お薬手帳の集約コンテキストテキストを生成
  String buildAiHealthContext() {
    final sb = StringBuffer();
    sb.writeln('【ユーザーの登録済み健康データ・お薬手帳コンテキスト】');
    sb.writeln('※以下はアプリ内に保存されているユーザーの実データです。過去の体調・お薬・処方箋に関する質問や会話の参照情報として活用してください。');

    // 1. お薬手帳・処方箋サマリー
    if (_prescriptions.isNotEmpty) {
      sb.writeln('\n▼ お薬手帳・処方箋一覧 (${_prescriptions.length}件):');
      for (var p in _prescriptions) {
        final dateStr = '${p.date.year}/${p.date.month}/${p.date.day}';
        final medList = p.medications.map((m) {
          final eff = m.efficacy != null && m.efficacy!.isNotEmpty ? '（効能: ${m.efficacy}）' : '';
          return '${m.name} [${m.dosage.replaceAll("\n", " ")}]$eff';
        }).join('、');
        final hospital = p.hospitalName.isNotEmpty ? p.hospitalName : "医療機関";
        sb.writeln('- $dateStr $hospital${p.department != null ? "(${p.department})" : ""}: $medList');
      }
    }

    if (_records.isEmpty) {
      sb.writeln('\n（※過去の体調・服薬記録はまだ登録されていません）');
      return sb.toString();
    }

    // 2. 全期間の月別統計サマリー
    final recordsByMonth = <String, List<HealthRecord>>{};
    for (var r in _records) {
      final key = '${r.date.year}年${r.date.month}月';
      recordsByMonth.putIfAbsent(key, () => []).add(r);
    }

    sb.writeln('\n▼ 月別統計サマリー (全${recordsByMonth.length}ヶ月分):');
    for (var entry in recordsByMonth.entries) {
      final mKey = entry.key;
      final mRecords = entry.value;

      // 平均スコア
      final scores = mRecords.map((r) => r.conditionScore).whereType<int>().toList();
      final avgScore = scores.isNotEmpty
          ? (scores.reduce((a, b) => a + b) / scores.length).toStringAsFixed(1)
          : '-';

      // 症状の集計
      final symptomCounts = <String, int>{};
      for (var r in mRecords) {
        for (var s in r.symptoms) {
          symptomCounts[s] = (symptomCounts[s] ?? 0) + 1;
        }
      }
      final symptomSummary = symptomCounts.isNotEmpty
          ? symptomCounts.entries.map((e) => '${e.key}(${e.value}日)').join(', ')
          : '記録なし';

      // 服薬の集計（正規化名）
      final medCounts = <String, int>{};
      for (var r in mRecords) {
        final dayMeds = <String>{};
        for (var m in r.medications) {
          final canon = MedicationNormalizer.normalize(m.name);
          dayMeds.add(canon.isNotEmpty ? canon : m.name);
        }
        for (var mName in dayMeds) {
          medCounts[mName] = (medCounts[mName] ?? 0) + 1;
        }
      }
      final medSummary = medCounts.isNotEmpty
          ? medCounts.entries.map((e) => '${e.key}(${e.value}日)').join(', ')
          : '服薬なし';

      // 体重
      final weights = mRecords.map((r) => r.weight).whereType<double>().toList();
      final weightSummary = weights.isNotEmpty
          ? '最小${weights.reduce((a, b) => a < b ? a : b)}kg〜最大${weights.reduce((a, b) => a > b ? a : b)}kg (平均${(weights.reduce((a, b) => a + b) / weights.length).toStringAsFixed(1)}kg)'
          : '-';

      sb.writeln('- $mKey: 記録${mRecords.length}日分 | 平均体調スコア: $avgScore/10 | 症状: $symptomSummary | 服薬: $medSummary | 体重: $weightSummary');
    }

    // 3. 直近90日間の日別コンパクト記録（日付降順/新しい順）
    final sortedRecords = [..._records]..sort((a, b) => b.date.compareTo(a.date));
    final recentRecords = sortedRecords.take(90).toList();

    sb.writeln('\n▼ 直近の日別記録 (最新${recentRecords.length}日分、新しい順):');
    for (var r in recentRecords) {
      final dateStr = '${r.date.year}-${r.date.month.toString().padLeft(2, '0')}-${r.date.day.toString().padLeft(2, '0')}';
      final parts = <String>[];
      if (r.conditionScore != null) parts.add('スコア:${r.conditionScore}/10');
      if (r.symptoms.isNotEmpty) parts.add('症状:[${r.symptoms.join(",")}]');
      if (r.medications.isNotEmpty) {
        final mNames = r.medications
            .map((m) => m.time != null && m.time != '処方' ? '${m.name}(${m.time})' : m.name)
            .join(",");
        parts.add('服薬:[$mNames]');
      }
      if (r.weight != null) parts.add('体重:${r.weight}kg');
      if (r.bodyFat != null) parts.add('体脂肪:${r.bodyFat}%');
      if (r.sleepHours != null) parts.add('睡眠:${r.sleepHours}h');
      if (r.steps != null) parts.add('歩数:${r.steps}歩');
      if (r.workouts.isNotEmpty) {
        final wList = r.workouts
            .map((w) => '${w.name} ${w.weight}kg×${w.reps}回×${w.sets}set')
            .join(",");
        parts.add('運動:[$wList]');
      }

      sb.writeln('- $dateStr: ${parts.join(" | ")}');
    }

    return sb.toString();
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

  // --- お薬手帳・処方データ管理 ---

  /// 新しい処方箋レコードを追加
  void addPrescription(PrescriptionRecord prescription) {
    _prescriptions.removeWhere((p) => p.id == prescription.id);
    _prescriptions.insert(0, prescription);
    _prescriptions.sort((a, b) => b.date.compareTo(a.date)); // 処方日の降順
    notifyListeners();
    savePrescriptions();
  }

  /// 処方箋レコードを削除
  void deletePrescription(String id) {
    _prescriptions.removeWhere((p) => p.id == id);
    notifyListeners();
    savePrescriptions();
  }

  /// サンプルデータにリセット
  void resetPrescriptionsToDefault() {
    _prescriptions = getInitialSamplePrescriptions();
    notifyListeners();
    savePrescriptions();
  }

  /// 初期サンプル処方データ（実例：栗田皮フ科・オリーブ薬局・処方薬4種）
  static List<PrescriptionRecord> getInitialSamplePrescriptions() {
    return [
      PrescriptionRecord(
        id: 'sample_kurita_dermatology_20260415',
        date: DateTime(2026, 4, 15),
        hospitalName: '医療法人社団 栗田会 栗田皮フ科',
        department: '【皮膚科】',
        doctorName: '栗田 依幸',
        pharmacyName: 'オリーブ薬局幕張本郷店',
        pharmacistName: 'なし',
        cost: 1180,
        medications: [
          PrescriptionMedication(
            name: 'リンデロン-Vローション',
            dosage: '◆外用 塗布◆\n総量:20mL',
            category: '外用',
            efficacy: 'ステロイドの外用薬（強さ: ストロング）で、湿疹や皮膚炎、頭皮などの炎症、赤み、かゆみを速やかに鎮めます。液状で毛髪部にも塗りやすい製剤です。',
            sideEffects: '塗布部の刺激感、皮膚の感染症（毛嚢炎など）、長期連用による皮膚の菲薄化・赤みなど。',
            precautions: '目や目の周囲、傷口への使用は避けてください。指示された期間・部位のみに使用し、自己判断で長期連用しないでください。',
          ),
          PrescriptionMedication(
            name: 'リンデロン-V軟膏0.12%',
            dosage: '◆外用 塗布◆\n総量:10g',
            category: '外用',
            efficacy: 'ステロイドの軟膏（強さ: ストロング）で、皮膚の湿疹・皮膚炎・かゆみなどの強い炎症を鎮めます。刺激が少なく、ジュクジュクした患部や乾燥した患部の両方に適しています。',
            sideEffects: '塗布部の発赤、刺激感、毛嚢炎。大量・長期使用時の皮膚萎縮、毛細血管拡張など。',
            precautions: '顔面への長期連用は避け、医師に指示された部位にのみ薄く塗布してください。症状が改善したら指示に従って減量または中止します。',
          ),
          PrescriptionMedication(
            name: 'ヒルドイドソフト軟膏0.3%',
            dosage: '◆外用 塗布◆\n総量:10g',
            category: '外用',
            efficacy: 'ヘパリン類似物質を含み、皮膚の水分保持能力（保湿力）を高め、血行を促進して皮膚の乾燥や角化・荒れを防ぎます。アトピー性皮膚炎や乾燥肌のスキンケアにも広く使われます。',
            sideEffects: 'まれに皮膚炎、かゆみ、発赤、刺激感などが現れることがあります。',
            precautions: '血行促進作用があるため、出血性血液疾患のある方や、出血している傷口・びらん面には使用しないでください。',
          ),
          PrescriptionMedication(
            name: '(AG)レボセチリジン塩酸塩錠5mg「武田テバ」',
            dosage: '◆内服 分1 医師の指示通り◆\n1日の使用量:1錠 / 総量:14日分',
            category: '内服',
            efficacy: '第2世代抗ヒスタミン薬で、アレルギー性鼻炎（花粉症等）によるくしゃみ・鼻水・鼻づまりや、じんましん・湿疹に伴う皮膚のかゆみを強力に抑えます。',
            sideEffects: '眠気、倦怠感、口渇（口の渇き）、頭痛、吐き気、まれに肝機能値上昇など。',
            precautions: '眠気を催すことがあるため、服用後は自動車の運転や危険を伴う機械の操作は避けてください。アルコールとの併用は眠気が強まるため控えてください。',
          ),
        ],
        notes: '皮膚アレルギー症状および湿疹の治療処方',
      ),
    ];
  }
}
