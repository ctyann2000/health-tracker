import 'package:flutter_test/flutter_test.dart';
import 'package:health_tracker/models/prescription_record.dart';
import 'package:health_tracker/providers/health_provider.dart';

void main() {
  group('PrescriptionRecord and MedicationNotebook Tests', () {
    test('Initial sample prescriptions contain Kurita Dermatology and 4 medications with efficacy and side effects', () {
      final samples = HealthProvider.getInitialSamplePrescriptions();
      expect(samples.isNotEmpty, true);

      final record = samples.first;
      expect(record.hospitalName, contains('栗田皮フ科'));
      expect(record.pharmacyName, contains('オリーブ薬局'));
      expect(record.department, '【皮膚科】');
      expect(record.doctorName, '栗田 依幸');
      expect(record.cost, 1180);
      expect(record.medications.length, 4);

      // 各薬品の検証
      final rinderonLotion = record.medications.firstWhere((m) => m.name.contains('ローション'));
      expect(rinderonLotion.dosage, contains('20mL'));
      expect(rinderonLotion.category, '外用');
      expect(rinderonLotion.efficacy, isNotNull);
      expect(rinderonLotion.sideEffects, isNotNull);

      final levocetirizine = record.medications.firstWhere((m) => m.name.contains('レボセチリジン'));
      expect(levocetirizine.dosage, contains('14日分'));
      expect(levocetirizine.category, '内服');
      expect(levocetirizine.efficacy, contains('アレルギー'));
      expect(levocetirizine.sideEffects, contains('眠気'));
    });

    test('PrescriptionRecord JSON serialization and deserialization retains all fields', () {
      final original = PrescriptionRecord(
        id: 'test_id_123',
        date: DateTime(2026, 4, 15),
        hospitalName: 'テストクリニック',
        department: '内科',
        doctorName: 'テスト医師',
        pharmacyName: 'テスト調剤薬局',
        pharmacistName: 'テスト薬剤師',
        cost: 1500,
        medications: [
          PrescriptionMedication(
            name: 'ロキソプロフェンナトリウム錠60mg',
            dosage: '1日3回 毎食後 1回1錠',
            category: '内服',
            efficacy: '炎症を抑え、痛みを和らげます',
            sideEffects: '胃部不快感、眠気',
            precautions: '空腹時の服用を避けてください',
          ),
        ],
        notes: 'テスト備考',
      );

      final jsonMap = original.toJson();
      final restored = PrescriptionRecord.fromJson(jsonMap);

      expect(restored.id, original.id);
      expect(restored.hospitalName, original.hospitalName);
      expect(restored.department, original.department);
      expect(restored.cost, 1500);
      expect(restored.medications.length, 1);
      expect(restored.medications.first.name, 'ロキソプロフェンナトリウム錠60mg');
      expect(restored.medications.first.efficacy, '炎症を抑え、痛みを和らげます');
      expect(restored.medications.first.sideEffects, '胃部不快感、眠気');
    });
  });
}
