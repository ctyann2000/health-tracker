import 'package:flutter_test/flutter_test.dart';
import 'package:health_tracker/models/health_record.dart';
import 'package:health_tracker/providers/health_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('月間データ集計 (getRecordsForMonth) のテスト', () {
    test('指定した年月のデータのみが日付昇順で抽出されること', () async {
      final provider = HealthProvider();
      await Future.delayed(const Duration(milliseconds: 10));

      // 2026年9月のレコード (順不同で登録)
      final rSep15 = HealthRecord(
        date: DateTime(2026, 9, 15),
        steps: 8000,
        sleepHours: 7.0,
      );
      final rSep01 = HealthRecord(
        date: DateTime(2026, 9, 1),
        steps: 5000,
        sleepHours: 6.5,
      );
      final rSep30 = HealthRecord(
        date: DateTime(2026, 9, 30),
        steps: 10000,
        sleepHours: 8.0,
      );

      // 2026年8月、10月、2025年9月のレコード
      final rAug31 = HealthRecord(
        date: DateTime(2026, 8, 31),
        steps: 6000,
      );
      final rOct01 = HealthRecord(
        date: DateTime(2026, 10, 1),
        steps: 7000,
      );
      final r2025Sep = HealthRecord(
        date: DateTime(2025, 9, 15),
        steps: 4000,
      );

      provider.addRecord(rSep15);
      provider.addRecord(rAug31);
      provider.addRecord(rSep01);
      provider.addRecord(rOct01);
      provider.addRecord(rSep30);
      provider.addRecord(r2025Sep);

      // 2026年9月を取得
      final sepRecords = provider.getRecordsForMonth(DateTime(2026, 9, 1));
      expect(sepRecords.length, 3);
      expect(sepRecords[0].date.day, 1);
      expect(sepRecords[1].date.day, 15);
      expect(sepRecords[2].date.day, 30);

      // 2026年8月を取得
      final augRecords = provider.getRecordsForMonth(DateTime(2026, 8, 1));
      expect(augRecords.length, 1);
      expect(augRecords[0].date.day, 31);

      // 2025年9月を取得 (別年の同月)
      final y2025Records = provider.getRecordsForMonth(DateTime(2025, 9, 1));
      expect(y2025Records.length, 1);
      expect(y2025Records[0].date.year, 2025);

      // 記録がない月 (2026年7月) を取得
      final julRecords = provider.getRecordsForMonth(DateTime(2026, 7, 1));
      expect(julRecords.isEmpty, isTrue);
    });

    test('年を跨ぐ月切り替え（前月・次月）ロジックの検証', () {
      // 2026年1月の前月 -> 2025年12月
      final jan2026 = DateTime(2026, 1, 1);
      final prevOfJan = DateTime(jan2026.year, jan2026.month - 1, 1);
      expect(prevOfJan.year, 2025);
      expect(prevOfJan.month, 12);

      // 2026年12月の次月 -> 2027年1月
      final dec2026 = DateTime(2026, 12, 1);
      final nextOfDec = DateTime(dec2026.year, dec2026.month + 1, 1);
      expect(nextOfDec.year, 2027);
      expect(nextOfDec.month, 1);
    });
  });
}
