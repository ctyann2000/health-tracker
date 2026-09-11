import 'package:flutter_test/flutter_test.dart';
import 'package:health_tracker/services/prescription_qr_service.dart';
import 'package:health_tracker/models/prescription_record.dart';
import 'package:health_tracker/models/health_record.dart';
import 'package:health_tracker/providers/health_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrescriptionQrService Tests', () {
    test('parseLocalJahisOrText parses standard JAHIS formatted prescription', () {
      final jahisText = '''
1,20260908,医療法人社団 栗田会 栗田皮フ科,皮膚科,栗田 依幸
5,オリーブ薬局幕張本郷店,20260908
11,1,ミグシス錠5mg,2,錠,内服
201,1日2回 朝夕食後,14,日分
11,2,ツムラ川芎茶調散エキス顆粒,3,包,内服
201,1日3回 毎食前,14,日分
''';

      final record = PrescriptionQrService.parseLocalJahisOrText(jahisText);

      expect(record.hospitalName, '医療法人社団 栗田会 栗田皮フ科');
      expect(record.department, '皮膚科');
      expect(record.doctorName, '栗田 依幸');
      expect(record.pharmacyName, 'オリーブ薬局幕張本郷店');
      expect(record.date.year, 2026);
      expect(record.date.month, 9);
      expect(record.date.day, 8);
      expect(record.medications.length, 2);

      expect(record.medications[0].name, 'ミグシス錠5mg');
      expect(record.medications[0].dosage, contains('2錠 1日2回 朝夕食後 14日分'));
      expect(record.medications[0].category, '内服');

      expect(record.medications[1].name, 'ツムラ川芎茶調散エキス顆粒');
      expect(record.medications[1].dosage, contains('3包 1日3回 毎食前 14日分'));
      expect(record.medications[1].category, '内服');
    });

    test('parseLocalJahisOrText parses fallback plain text or comma separated text', () {
      final plainText = '''
さくらクリニック
ロキソプロフェンNa錠60mg, 1回1錠 痛む時
ムコスタ錠100mg, 1回1錠 毎食後
''';

      final record = PrescriptionQrService.parseLocalJahisOrText(plainText);

      expect(record.medications.length, greaterThanOrEqualTo(2));
      expect(record.medications.any((m) => m.name.contains('ロキソプロフェン')), isTrue);
      expect(record.medications.any((m) => m.name.contains('ムコスタ')), isTrue);
    });

    test('parseLocalJahisOrText parses JSON formatted prescription directly', () {
      final jsonText = '''
{
  "hospital_name": "総合医療センター",
  "pharmacy_name": "ひまわり薬局",
  "date": "2026-09-10",
  "medications": [
    {
      "name": "エペリゾン塩酸塩錠50mg",
      "dosage": "1回1錠 1日3回 毎食後",
      "category": "内服",
      "efficacy": "筋肉の緊張をほぐす薬",
      "side_effects": "眠気、めまい"
    }
  ]
}
''';

      final record = PrescriptionQrService.parseLocalJahisOrText(jsonText);

      expect(record.hospitalName, '総合医療センター');
      expect(record.pharmacyName, 'ひまわり薬局');
      expect(record.medications.length, 1);
      expect(record.medications[0].name, 'エペリゾン塩酸塩錠50mg');
      expect(record.medications[0].efficacy, '筋肉の緊張をほぐす薬');
    });
  });

  group('HealthProvider Integration Tests for Prescriptions', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('addPrescription and medication sync with HealthRecord', () async {
      final provider = HealthProvider();
      await Future.delayed(const Duration(milliseconds: 100));

      final testPrescription = PrescriptionRecord(
        id: 'test-pres-1',
        date: DateTime(2026, 9, 11),
        hospitalName: 'テスト内科クリニック',
        pharmacyName: 'テスト薬局',
        medications: [
          PrescriptionMedication(
            name: 'アムロジピン錠5mg',
            dosage: '1回1錠 朝食後',
            category: '内服',
            efficacy: '血圧を下げる薬',
          ),
        ],
      );

      // 1. お薬手帳に追加
      provider.addPrescription(testPrescription);
      expect(provider.prescriptions.any((p) => p.id == 'test-pres-1'), isTrue);

      // 2. 今日の服薬記録に連動追加
      final today = DateTime.now();
      final medsToAdd = testPrescription.medications.map((m) => Medication(name: m.name)).toList();
      provider.addRecord(HealthRecord(date: today, medications: medsToAdd));

      final todayRecord = provider.getRecordForDate(today);
      expect(todayRecord, isNotNull);
      expect(todayRecord!.medications.any((m) => m.name == 'アムロジピン錠5mg'), isTrue);
    });
  });
}