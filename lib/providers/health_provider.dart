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
