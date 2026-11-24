import 'dart:typed_data';
import 'package:charset/charset.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:health_tracker/services/prescription_qr_service.dart';

void main() {
  group('PrescriptionQrService JAHIS & Shift-JIS Tests', () {
    test('extractBarcodeText decodes Barcode with rawDecodedBytes in Shift-JIS when rawValue is null or garbled', () {
      const jahisSample = '''JAHISTC08,1
1,鈴木 太郎,1,19580303,,,,,,,
5,R080415,1
11,オリーブ薬局幕張本郷店,12,4,1234567,,,,1
51,医療法人社団 栗田会 栗田皮フ科,12,1,1234567,1
55,栗田 依幸,皮膚科,1
201,1,ﾘﾝﾃﾞﾛﾝ-Vﾛｰｼｮﾝ,20,mL,2,620004992,1,,,
301,1,患部に塗布,1,全量,3,1,,1''';

      final sjisBytes = Uint8List.fromList(shiftJis.encode(jahisSample));
      final simulatedAndroidBarcode = Barcode(
        rawDecodedBytes: DecodedBarcodeBytes(bytes: sjisBytes),
        rawValue: '\uFFFD\uFFFDJAHISTC08',
      );

      final extracted = PrescriptionQrService.extractBarcodeText(simulatedAndroidBarcode);
      expect(extracted, isNotNull);
      expect(extracted, contains('医療法人社団 栗田会 栗田皮フ科'));
      expect(extracted, contains('リンデロン-Vローション'));
    });

    test('Decodes Shift-JIS encoded JAHIS QR bytes and parses records accurately', () {
      const jahisSample = '''JAHISTC08,1
1,鈴木 太郎,1,19580303,,,,,,,
5,R080415,1
11,オリーブ薬局幕張本郷店,12,4,1234567,,,,1
15,薬剤師 太郎,,1
51,医療法人社団 栗田会 栗田皮フ科,12,1,1234567,1
55,栗田 依幸,皮膚科,1
201,1,ﾘﾝﾃﾞﾛﾝ-Vﾛｰｼｮﾝ,20,mL,2,620004992,1,,,
301,1,患部に塗布,1,全量,3,1,,1
201,2,ﾚﾎﾞｾﾁﾘｼﾞﾝ塩酸塩錠5mg,1,錠,2,620425801,1,,,
301,2,1日1回就寝前,14,日分,1,1,,1''';

      // Shift-JIS バイト列にエンコードしてデコード検証
      final sjisBytes = Uint8List.fromList(shiftJis.encode(jahisSample));
      final decodedText = PrescriptionQrService.decodeQrBytes(sjisBytes);
      final normalized = PrescriptionQrService.normalizeHalfWidthKatakana(decodedText);

      expect(normalized, contains('リンデロン-Vローション'));
      expect(normalized, contains('レボセチリジン塩酸塩錠5mg'));

      final record = PrescriptionQrService.parseLocalJahisOrText(normalized);
      expect(record.hospitalName, '医療法人社団 栗田会 栗田皮フ科');
      expect(record.pharmacyName, 'オリーブ薬局幕張本郷店');
      expect(record.doctorName, '栗田 依幸');
      expect(record.department, '皮膚科');
      expect(record.date.year, 2026);
      expect(record.date.month, 4);
      expect(record.date.day, 15);
      expect(record.medications.length, 2);
      expect(record.medications[0].name, 'リンデロン-Vローション');
      expect(record.medications[0].category, '外用');
      expect(record.medications[0].dosage, contains('20mL'));
      expect(record.medications[1].name, 'レボセチリジン塩酸塩錠5mg');
      expect(record.medications[1].category, '内服');
      expect(record.medications[1].dosage, contains('14日分'));
    });

    test('Parses JAHIS 院外処方せん2次元シンボル format (201 with code before drug name)', () {
      const presQr = '''JAHIS10
51,12,1,1234567,幕張クリニック
52,20261124
53,1,内科
55,001,山田 医師
101,1,1,内服,14
111,1,1,01001,1日3回毎食後,3
201,1,1,1,2,611111111,ロキソプロフェンNa錠60mg,3,1,錠
201,1,2,1,2,622222222,レバミピド錠100mg,3,1,錠''';

      final record = PrescriptionQrService.parseLocalJahisOrText(presQr);
      expect(record.hospitalName, '幕張クリニック');
      expect(record.department, '内科');
      expect(record.doctorName, '山田 医師');
      expect(record.medications.length, 2);
      expect(record.medications[0].name, 'ロキソプロフェンNa錠60mg');
      expect(record.medications[0].dosage, contains('3錠'));
      expect(record.medications[0].dosage, contains('1日3回毎食後'));
      expect(record.medications[1].name, 'レバミピド錠100mg');
    });
  });
}
