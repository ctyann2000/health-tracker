import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:health_tracker/models/health_record.dart';
import 'package:health_tracker/providers/health_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Gemini response extracts symptoms and builds empathetic coach reply correctly', () {
    final geminiResult = {
      'reply': '頭痛、お辛いですね。ロキソプロフェンを服用された記録をつけておきました。無理をなさらず、水分をしっかり摂って少し横になって休んでくださいね。',
      'condition_score': 4,
      'symptoms': ['頭痛'],
      'medications': [
        {'name': 'ロキソプロフェン', 'time': null}
      ],
      'weight': null,
      'steps': null,
      'bodyFat': null,
      'bmi': null,
      'bmr': null,
      'calories': null,
      'sleepHours': null,
      'workouts': []
    };

    final record = HealthRecord(
      date: DateTime.now(),
      conditionScore: geminiResult['condition_score'] as int?,
      symptoms: List<String>.from(geminiResult['symptoms'] as List),
      medications: (geminiResult['medications'] as List)
          .map((e) => Medication.fromJson(e as Map<String, dynamic>))
          .toList(),
      weight: geminiResult['weight'] != null ? (geminiResult['weight'] as num).toDouble() : null,
      steps: geminiResult['steps'] as int?,
      workouts: (geminiResult['workouts'] as List)
          .map((e) => Workout.fromJson(e))
          .toList(),
    );

    expect(record.conditionScore, 4);
    expect(record.symptoms, contains('頭痛'));
    expect(record.medications.first.name, 'ロキソプロフェン');

    final coachReply = (geminiResult['reply'] as String?)?.trim() ?? '';
    final List<String> summaryLines = [];
    if (record.conditionScore != null) {
      summaryLines.add('体調スコア: ${record.conditionScore}/10');
    } else {
      summaryLines.add('体調スコア: -');
    }
    if (record.symptoms.isNotEmpty) {
      summaryLines.add('症状: ${record.symptoms.join(', ')}');
    }
    if (record.medications.isNotEmpty) {
      final meds = record.medications.map((m) => m.time != null ? '${m.time} ${m.name}' : m.name).join(', ');
      summaryLines.add('お薬: $meds');
    }

    final summaryBlock = summaryLines.join('\n');
    final fullMessage = coachReply.isNotEmpty
        ? '$coachReply\n\n【記録内容】\n$summaryBlock'
        : '記録を保存しました！\n$summaryBlock';

    expect(fullMessage, contains('頭痛、お辛いですね'));
    expect(fullMessage, contains('体調スコア: 4/10'));
    expect(fullMessage, contains('症状: 頭痛'));
    expect(fullMessage, contains('お薬: ロキソプロフェン'));
  });

  test('Gemini response extracts custom date (yesterday/specific date) for workout correctly', () {
    final geminiResult = {
      'date': '2026-09-08',
      'reply': '9月8日のトレーニング記録ですね！ベンチプレスしっかりこなされて素晴らしいです。',
      'condition_score': 8,
      'symptoms': [],
      'medications': [],
      'weight': null,
      'steps': null,
      'bodyFat': null,
      'bmi': null,
      'bmr': null,
      'calories': null,
      'sleepHours': null,
      'workouts': [
        {'name': 'ベンチプレス', 'weight': 60, 'reps': 10, 'sets': 3}
      ]
    };

    DateTime targetDate = DateTime.now();
    if (geminiResult['date'] != null && (geminiResult['date'] as String).isNotEmpty) {
      targetDate = DateTime.parse(geminiResult['date'] as String);
    }

    final record = HealthRecord(
      date: targetDate,
      conditionScore: geminiResult['condition_score'] as int?,
      workouts: (geminiResult['workouts'] as List)
          .map((e) => Workout.fromJson(e))
          .toList(),
    );

    expect(record.date.year, 2026);
    expect(record.date.month, 9);
    expect(record.date.day, 8);
    expect(record.workouts.first.name, 'ベンチプレス');
    expect(record.workouts.first.weight, 60.0);
  });

  test('定期服薬の報告のみの場合は症状を捏造せず、お薬のみ登録されること', () {
    final geminiResult = {
      'reply': 'ミグシス、エペリゾン、川芎茶調散を服用されたのですね。毎日しっかり続けられていて素晴らしいです！',
      'condition_score': null,
      'symptoms': [],
      'remove_symptoms': [],
      'clear_all_symptoms': false,
      'medications': [
        {'name': 'ミグシス', 'time': null},
        {'name': 'エペリゾン', 'time': null},
        {'name': '川芎茶調散', 'time': null},
      ],
      'weight': null,
      'steps': null,
      'bodyFat': null,
      'bmi': null,
      'bmr': null,
      'calories': null,
      'sleepHours': null,
      'workouts': []
    };

    final record = HealthRecord(
      date: DateTime.now(),
      conditionScore: geminiResult['condition_score'] as int?,
      symptoms: List<String>.from(geminiResult['symptoms'] as List),
      medications: (geminiResult['medications'] as List)
          .map((e) => Medication.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

    expect(record.symptoms.isEmpty, isTrue);
    expect(record.medications.length, 3);
    expect(record.conditionScore, isNull);
  });

  test('チャットで「頭痛も肩こりもないよ」と否定した際、HealthProviderから症状が削除されスコアが正常化すること', () async {
    final provider = HealthProvider();
    await Future.delayed(const Duration(milliseconds: 10));

    final today = DateTime.now();

    // 誤って頭痛と肩こりが記録されていた初期状態
    provider.addRecord(HealthRecord(
      date: today,
      conditionScore: 4,
      symptoms: ['頭痛', '肩こり'],
      medications: [
        Medication(name: 'ミグシス'),
        Medication(name: 'エペリゾン'),
        Medication(name: '川芎茶調散'),
      ],
    ));

    expect(provider.getRecordForDate(today)!.symptoms.length, 2);
    expect(provider.getRecordForDate(today)!.conditionScore, 4);

    // AIが「否定」を検出して出力した結果
    final geminiResult = {
      'reply': '頭痛や肩こりはないのですね！安心いたしました。記録から頭痛・肩こりの症状を取り消しました。',
      'condition_score': null,
      'symptoms': [],
      'remove_symptoms': ['頭痛', '肩こり'],
      'clear_all_symptoms': false,
    };

    final removeSymptoms = List<String>.from(geminiResult['remove_symptoms'] as List);
    if (removeSymptoms.isNotEmpty) {
      provider.removeSymptoms(today, removeSymptoms);
    }

    final updated = provider.getRecordForDate(today)!;
    // 症状が除去されていること
    expect(updated.symptoms.isEmpty, isTrue);
    // お薬は保持されていること
    expect(updated.medications.length, 3);
    // 誤判定で下げられていたスコアが正常（7）に回復していること
    expect(updated.conditionScore, 7);
  });
}
