import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:health_tracker/models/health_record.dart';
import 'package:health_tracker/providers/health_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Medication Quantity Model & Parser Tests', () {
    test('Medication defaults to quantity 1 and preserves backward compatibility in fromJson', () {
      final defaultMed = Medication(name: 'エペリゾン');
      expect(defaultMed.quantity, 1);
      expect(defaultMed.displayWithQuantity, 'エペリゾン 1錠');

      final legacyJsonMed = Medication.fromJson({'name': 'ミグシス', 'time': '08:00'});
      expect(legacyJsonMed.name, 'ミグシス');
      expect(legacyJsonMed.time, '08:00');
      expect(legacyJsonMed.quantity, 1);

      final explicitJsonMed = Medication.fromJson({'name': 'ロキソプロフェン', 'time': '12:30', 'quantity': 2});
      expect(explicitJsonMed.quantity, 2);
      expect(explicitJsonMed.toJson()['quantity'], 2);

      final zeroFallbackMed = Medication(name: 'カロナール', quantity: 0);
      expect(zeroFallbackMed.quantity, 1);
    });

    test('Medication.parseFromInput parses quantities accurately and defaults unspecified to 1', () {
      final m1 = Medication.parseFromInput('ロキソニン 2錠');
      expect(m1.name, 'ロキソニン');
      expect(m1.quantity, 2);

      final m2 = Medication.parseFromInput('エペリゾン');
      expect(m2.name, 'エペリゾン');
      expect(m2.quantity, 1);

      final m3 = Medication.parseFromInput('漢方×3');
      expect(m3.name, '漢方');
      expect(m3.quantity, 3);

      // 規格（60mgなど）を錠数と誤認しないこと
      final m4 = Medication.parseFromInput('ロキソプロフェン錠60mg');
      expect(m4.name, 'ロキソプロフェン錠60mg');
      expect(m4.quantity, 1);

      final m5 = Medication.parseFromInput('ミグシス ３錠');
      expect(m5.name, 'ミグシス');
      expect(m5.quantity, 3);
    });
  });

  group('HealthProvider Same-Day Medication Quantity Accumulation Tests', () {
    test('Accumulates medication quantities across multiple inputs on the same day', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = HealthProvider();
      // コンストラクタ内の非同期 _loadAllData 完了待ち
      await Future.delayed(const Duration(milliseconds: 100));

      final targetDay = DateTime(2026, 11, 24);

      // 1回目: エペリゾン（数量指定なし -> 1錠）
      provider.addRecord(HealthRecord(
        date: targetDay,
        medications: [Medication(name: 'エペリゾン', time: '08:00')],
      ));

      var saved = provider.getRecordForDate(targetDay)!;
      expect(saved.medications.length, 1);
      expect(saved.medications.first.name, 'エペリゾン');
      expect(saved.medications.first.quantity, 1);

      // 2回目: 同日にミオナール（エペリゾンの先発品・数量指定なし -> 1錠追加で合計2錠）
      provider.addRecord(HealthRecord(
        date: targetDay,
        medications: [Medication(name: 'ミオナール', time: '13:00')],
      ));

      saved = provider.getRecordForDate(targetDay)!;
      expect(saved.medications.length, 1);
      expect(saved.medications.first.name, 'エペリゾン');
      expect(saved.medications.first.quantity, 2);
      expect(saved.medications.first.time, '08:00, 13:00');

      // 3回目: 同日にエペリゾン 2錠追加（合計4錠）
      provider.addRecord(HealthRecord(
        date: targetDay,
        medications: [Medication(name: 'エペリゾン', time: '20:00', quantity: 2)],
      ));

      saved = provider.getRecordForDate(targetDay)!;
      expect(saved.medications.length, 1);
      expect(saved.medications.first.quantity, 4);
      expect(saved.medications.first.time, '08:00, 13:00, 20:00');
    });
  });
}
