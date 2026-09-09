import 'package:flutter_test/flutter_test.dart';
import 'package:health_tracker/models/health_record.dart';
import 'package:health_tracker/providers/health_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('HealthProvider Record Edit and Delete Tests', () {
    test('deleteRecord correctly removes record for the specified date', () async {
      final provider = HealthProvider();
      final targetDate = DateTime(2026, 9, 8, 10, 0);

      final record1 = HealthRecord(
        date: targetDate,
        conditionScore: 5,
        symptoms: ['頭痛'],
        workouts: [Workout(name: 'ベンチプレス', weight: 50, reps: 10, sets: 3)],
      );
      final record2 = HealthRecord(
        date: DateTime(2026, 9, 9, 12, 0),
        conditionScore: 8,
      );

      provider.addRecord(record1);
      provider.addRecord(record2);

      expect(provider.records.length, 2);
      expect(provider.getRecordForDate(targetDate), isNotNull);

      // 異なる時刻の同じ日時のDateTimeで削除
      provider.deleteRecord(DateTime(2026, 9, 8, 23, 59));

      expect(provider.records.length, 1);
      expect(provider.getRecordForDate(targetDate), isNull);
      expect(provider.getRecordForDate(DateTime(2026, 9, 9)), isNotNull);
    });

    test('updateRecord correctly replaces existing record with updated values', () async {
      final provider = HealthProvider();
      final targetDate = DateTime(2026, 9, 8);

      final initialRecord = HealthRecord(
        date: targetDate,
        conditionScore: 4,
        symptoms: ['頭痛'],
        weight: 70.0,
        workouts: [Workout(name: 'ベンチプレス', weight: 50, reps: 10, sets: 3)],
      );

      provider.addRecord(initialRecord);

      final updatedRecord = HealthRecord(
        date: targetDate,
        conditionScore: 9, // 体調が良くなった
        symptoms: [], // 症状が治った
        weight: 69.5, // 体重修正
        workouts: [
          Workout(name: 'スクワット', weight: 80, reps: 10, sets: 3)
        ], // 種目変更
      );

      provider.updateRecord(updatedRecord);

      final fetched = provider.getRecordForDate(targetDate);
      expect(fetched, isNotNull);
      expect(fetched!.conditionScore, 9);
      expect(fetched.symptoms.isEmpty, true);
      expect(fetched.weight, 69.5);
      expect(fetched.workouts.length, 1);
      expect(fetched.workouts.first.name, 'スクワット');
      expect(fetched.workouts.first.weight, 80.0);
    });
  });
}
