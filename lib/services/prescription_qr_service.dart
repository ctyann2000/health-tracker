import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/prescription_record.dart';
import 'gemini_service.dart';

/// 処方箋・お薬手帳のQRコード解析を行うサービス
class PrescriptionQrService {
  final GeminiService _geminiService;

  PrescriptionQrService({GeminiService? geminiService})
      : _geminiService = geminiService ?? GeminiService();

  /// 静止画ファイルパスからQRコードを読み取り、生テキストを抽出する（複数・分割QRコードに対応）
  Future<String?> scanQrFromImagePath(String imagePath) async {
    final controller = MobileScannerController();
    try {
      final BarcodeCapture? capture = await controller.analyzeImage(imagePath);
      if (capture != null && capture.barcodes.isNotEmpty) {
        final values = <String>[];
        for (final barcode in capture.barcodes) {
          final val = barcode.rawValue;
          if (val != null && val.trim().isNotEmpty && !values.contains(val.trim())) {
            values.add(val.trim());
          }
        }
        if (values.isNotEmpty) {
          return values.join('\n');
        }
      }
      return null;
    } catch (e) {
      debugPrint('PrescriptionQrService.scanQrFromImagePath error: $e');
      return null;
    } finally {
      controller.dispose();
    }
  }

  /// QRコードから読み取られた生テキストを解析し、PrescriptionRecordを生成する
  /// Gemini APIによる高精度解析（効能・副作用等の自動補完）を優先し、
  /// オフライン時やAPIエラー時は内蔵JAHISローカルパーサーでフォールバック
  Future<PrescriptionRecord> parsePrescriptionText(String rawText) async {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty) {
      throw Exception('QRコードのデータが空です。');
    }

    // 1. Gemini APIで解析（効能・副作用等の付加情報を自動補完）
    try {
      final apiKey = await _geminiService.getApiKey();
      if (apiKey.isNotEmpty) {
        final parsedMap = await _geminiService.parsePrescriptionFromQrText(trimmed);
        return PrescriptionRecord.fromJson(parsedMap);
      }
    } catch (e) {
      debugPrint('Gemini prescription parse failed, using local fallback: $e');
    }

    // 2. ローカルフォールバック解析
    return parseLocalJahisOrText(trimmed);
  }

  /// JAHIS電子お薬手帳フォーマット、カンマ区切り、JSON、またはプレーンテキストをローカルで構造化
  static PrescriptionRecord parseLocalJahisOrText(String rawText) {
    final trimmedText = rawText.trim();

    // もしJSON形式の場合
    if (trimmedText.startsWith('{') && trimmedText.endsWith('}')) {
      try {
        final decoded = jsonDecode(trimmedText) as Map<String, dynamic>;
        return PrescriptionRecord.fromJson(decoded);
      } catch (_) {}
    }

    final lines = trimmedText.split(RegExp(r'\r?\n')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    String hospitalName = '処方医療機関';
    String? department;
    String? doctorName;
    String? pharmacyName;
    DateTime date = DateTime.now();
    int? cost;
    final List<PrescriptionMedication> medications = [];

    // JAHIS形式の行解析 (1: 医療機関, 5: 薬局, 11: 薬品, 201: 用法)
    String currentMedName = '';
    String currentMedDosage = '';
    String? currentCategory;

    for (final line in lines) {
      final parts = line.split(',');

      if (parts.isNotEmpty) {
        final code = parts[0].trim();

        // 医療機関情報 (1, 日付, 医療機関名, 診療科, 医師名, ...)
        if (code == '1' || code == '2') {
          if (parts.length > 2 && parts[2].trim().isNotEmpty) {
            hospitalName = parts[2].trim();
          }
          if (parts.length > 1 && parts[1].trim().isNotEmpty) {
            final d = _parseDateString(parts[1].trim());
            if (d != null) date = d;
          }
          if (parts.length > 3 && parts[3].trim().isNotEmpty) {
            department = parts[3].trim();
          }
          if (parts.length > 4 && parts[4].trim().isNotEmpty) {
            doctorName = parts[4].trim();
          }
        }
        // 薬局情報 (5, 薬局名, 日付, ...)
        else if (code == '5') {
          if (parts.length > 1 && parts[1].trim().isNotEmpty) {
            pharmacyName = parts[1].trim();
          }
          if (parts.length > 2 && parts[2].trim().isNotEmpty) {
            final d = _parseDateString(parts[2].trim());
            if (d != null) date = d;
          }
        }
        // 薬品情報 (11, RP番号, 薬品名, 分量, 単位, 区分...)
        else if (code == '11') {
          // 前の薬品があれば保存
          if (currentMedName.isNotEmpty) {
            medications.add(PrescriptionMedication(
              name: currentMedName,
              dosage: currentMedDosage.isNotEmpty ? currentMedDosage : '指示通り服用',
              category: currentCategory,
            ));
            currentMedName = '';
            currentMedDosage = '';
            currentCategory = null;
          }

          if (parts.length > 2 && parts[2].trim().isNotEmpty) {
            currentMedName = parts[2].trim();
          }
          if (parts.length > 3 && parts[3].trim().isNotEmpty) {
            final amount = parts[3].trim();
            final unit = parts.length > 4 ? parts[4].trim() : '';
            currentMedDosage = '$amount$unit';
          }
          if (parts.length > 5 && parts[5].trim().isNotEmpty) {
            currentCategory = parts[5].trim();
          }
        }
        // 用法情報 (201, 用法名称, ...)
        else if (code == '201' || code == '281') {
          if (parts.length > 1 && parts[1].trim().isNotEmpty) {
            final usage = parts[1].trim();
            final days = parts.length > 2 && parts[2].trim().isNotEmpty ? '${parts[2].trim()}日分' : '';
            final fullDosage = [currentMedDosage, usage, days].where((s) => s.isNotEmpty).join(' ');
            currentMedDosage = fullDosage;
          }
        }
        // 単純カンマ区切り（薬品名, 用法）の場合
        else if (parts.length >= 2 && currentMedName.isEmpty && !code.startsWith('JAHIS')) {
          final possibleName = parts[0].trim();
          final possibleDosage = parts[1].trim();
          if (possibleName.isNotEmpty && !possibleName.contains(':') && !possibleName.contains('http')) {
            medications.add(PrescriptionMedication(
              name: possibleName,
              dosage: possibleDosage,
            ));
          }
        }
      }
    }

    // 最後の薬品をコミット
    if (currentMedName.isNotEmpty) {
      medications.add(PrescriptionMedication(
        name: currentMedName,
        dosage: currentMedDosage.isNotEmpty ? currentMedDosage : '指示通り服用',
        category: currentCategory,
      ));
    }

    // もし上記で薬品が取れなかった場合、一般的な改行テキストから抽出
    if (medications.isEmpty) {
      for (final line in lines) {
        if (line.contains('クリニック') || line.contains('病院') || line.contains('医院')) {
          hospitalName = line;
        } else if (line.contains('薬局')) {
          pharmacyName = line;
        } else if (line.contains('錠') || line.contains('カプセル') || line.contains('散') || line.contains('mg') || line.contains('包')) {
          medications.add(PrescriptionMedication(
            name: line,
            dosage: '医師・薬剤師の指示通り服用',
          ));
        }
      }
    }

    // それでも空なら最低限1行目を薬名またはQRデータとして保持
    if (medications.isEmpty) {
      medications.add(PrescriptionMedication(
        name: lines.isNotEmpty ? lines.first : '処方薬',
        dosage: '指示通り服用',
      ));
    }

    return PrescriptionRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: date,
      hospitalName: hospitalName,
      department: department,
      doctorName: doctorName,
      pharmacyName: pharmacyName,
      cost: cost,
      medications: medications,
      notes: 'QRコード読み取りデータより自動登録',
    );
  }

  /// "20260908" や "2026/09/08" などの文字列をDateTimeに変換
  static DateTime? _parseDateString(String str) {
    try {
      final clean = str.replaceAll(RegExp(r'[\/\-\.]'), '');
      if (clean.length == 8) {
        final year = int.parse(clean.substring(0, 4));
        final month = int.parse(clean.substring(4, 6));
        final day = int.parse(clean.substring(6, 8));
        return DateTime(year, month, day);
      }
      return DateTime.parse(str);
    } catch (_) {
      return null;
    }
  }
}