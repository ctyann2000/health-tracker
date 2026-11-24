import 'dart:convert';
import 'package:charset/charset.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/prescription_record.dart';
import 'gemini_service.dart';
import 'debug_log_service.dart';
import '../utils/web_qr_detector.dart';
import '../utils/medication_efficacy_helper.dart';

/// 処方箋・お薬手帳のQRコード解析を行うサービス
/// JAHIS電子版お薬手帳規格・院外処方せん2次元シンボル規格（Shift-JIS / UTF-8両対応）
class PrescriptionQrService {
  final GeminiService _geminiService;

  PrescriptionQrService({GeminiService? geminiService})
      : _geminiService = geminiService ?? GeminiService();

  /// BarcodeオブジェクトからShift-JIS / UTF-8を自動判別して文字化けなしでテキストを抽出
  static String? extractBarcodeText(Barcode barcode) {
    Uint8List? rawBytes;
    final decodedBytesObj = barcode.rawDecodedBytes;
    if (decodedBytesObj is DecodedBarcodeBytes) {
      rawBytes = decodedBytesObj.bytes;
    } else if (decodedBytesObj is DecodedVisionBarcodeBytes) {
      rawBytes = decodedBytesObj.bytes ?? decodedBytesObj.rawBytes;
    }

    final String? rawVal = barcode.rawValue ?? barcode.displayValue;

    // 1. rawBytes が取得できている場合: UTF-8 と Shift-JIS (CP932) を自動判定
    if (rawBytes != null && rawBytes.isNotEmpty) {
      final decodedFromBytes = decodeQrBytes(rawBytes);
      if (decodedFromBytes.trim().isNotEmpty) {
        // もし rawVal の方が文字化けのない綺麗な日本語を持っていれば比較して採用
        if (rawVal != null &&
            rawVal.trim().isNotEmpty &&
            !_looksGarbled(rawVal) &&
            _containsJapaneseOrJahis(rawVal) &&
            !_containsJapaneseOrJahis(decodedFromBytes)) {
          return normalizeHalfWidthKatakana(rawVal.trim());
        }
        return normalizeHalfWidthKatakana(decodedFromBytes.trim());
      }
    }

    // 2. rawValue / displayValue からの復元
    if (rawVal != null && rawVal.trim().isNotEmpty) {
      // ML KitがShift-JISバイト列をISO-8859-1 (Latin-1: 0x00..0xFF) として文字列化してしまった場合の復元
      if (_looksLikeLatin1EncodedShiftJis(rawVal)) {
        try {
          final latin1Bytes = Uint8List.fromList(rawVal.codeUnits);
          final sjisText = shiftJis.decode(latin1Bytes);
          if (sjisText.trim().isNotEmpty && !_looksGarbled(sjisText)) {
            DebugLogService.instance.log('[QR文字コード] Latin1経由のShift-JISバイト列を日本語に復元しました');
            return normalizeHalfWidthKatakana(sjisText.trim());
          }
        } catch (_) {}
      }
      return normalizeHalfWidthKatakana(rawVal.trim());
    }

    return null;
  }

  /// QRコードの生バイト配列（UTF-8 または Shift-JIS）を文字列へデコード
  static String decodeQrBytes(Uint8List bytes) {
    // まず厳密なUTF-8としてデコードを試みる
    try {
      final utf8Str = utf8.decode(bytes, allowMalformed: false);
      if (!utf8Str.contains('\uFFFD')) {
        // ASCII制御文字やLatin-1化けでなければUTF-8採用
        if (!_looksLikeLatin1EncodedShiftJis(utf8Str)) {
          return utf8Str;
        }
      }
    } catch (_) {
      // UTF-8として不正なバイト列 = 日本の処方箋・お薬手帳標準の Shift-JIS (CP932)
    }

    // Shift-JISとしてデコード
    try {
      final sjisStr = shiftJis.decode(bytes);
      if (sjisStr.trim().isNotEmpty) {
        DebugLogService.instance.log('[QR文字コード] Shift-JISとしてQRバイト列(${bytes.length}B)をデコード完了');
        return sjisStr;
      }
    } catch (e) {
      debugPrint('Shift-JIS decode error: $e');
    }

    // フォールバック
    return utf8.decode(bytes, allowMalformed: true);
  }

  static bool _looksGarbled(String text) {
    return text.contains('\uFFFD');
  }

  static bool _containsJapaneseOrJahis(String text) {
    if (text.toUpperCase().contains('JAHIS')) return true;
    // ひらがな・カタカナ・漢字・半角カナのいずれかを含むか
    return RegExp(r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF\uFF65-\uFF9F]').hasMatch(text);
  }

  /// 文字列がISO-8859-1 (0x80〜0xFF) のみで構成され日本語文字を含まない（Shift-JISのLatin-1誤解釈）か判定
  static bool _looksLikeLatin1EncodedShiftJis(String text) {
    bool hasHighLatin = false;
    for (final unit in text.codeUnits) {
      if (unit > 0xFF) {
        // すでにUnicodeの日本語文字等に変換されている場合はLatin-1ではない
        return false;
      }
      if (unit >= 0x80 && unit <= 0xFF) {
        hasHighLatin = true;
      }
    }
    return hasHighLatin;
  }

  /// JAHIS QRで多用される半角カタカナ（濁点・半濁点結合含む）を読みやすい全角カタカナへ正規化
  static String normalizeHalfWidthKatakana(String input) {
    if (!RegExp(r'[\uFF61-\uFF9F]').hasMatch(input)) return input;

    const Map<String, String> dakutenMap = {
      'ｶﾞ': 'ガ', 'ｷﾞ': 'ギ', 'ｸﾞ': 'グ', 'ｹﾞ': 'ゲ', 'ｺﾞ': 'ゴ',
      'ｻﾞ': 'ザ', 'ｼﾞ': 'ジ', 'ｽﾞ': 'ズ', 'ｾﾞ': 'ゼ', 'ｿﾞ': 'ゾ',
      'ﾀﾞ': 'ダ', 'ﾁﾞ': 'ヂ', 'ﾂﾞ': 'ヅ', 'ﾃﾞ': 'デ', 'ﾄﾞ': 'ド',
      'ﾊﾞ': 'バ', 'ﾋﾞ': 'ビ', 'ﾌﾞ': 'ブ', 'ﾍﾞ': 'ベ', 'ﾎﾞ': 'ボ',
      'ﾊﾟ': 'パ', 'ﾋﾟ': 'ピ', 'ﾌﾟ': 'プ', 'ﾍﾟ': 'ペ', 'ﾎﾟ': 'ポ',
      'ｳﾞ': 'ヴ', 'ﾜﾞ': 'ヷ', 'ｦﾞ': 'ヺ',
    };

    const Map<String, String> singleMap = {
      '｡': '。', '｢': '「', '｣': '」', '､': '、', '･': '・',
      'ｦ': 'ヲ', 'ｧ': 'ァ', 'ｨ': 'ィ', 'ｩ': 'ゥ', 'ｪ': 'ェ', 'ｫ': 'ォ',
      'ｬ': 'ャ', 'ｭ': 'ュ', 'ｮ': 'ョ', 'ｯ': 'ッ', 'ｰ': 'ー',
      'ｱ': 'ア', 'ｲ': 'イ', 'ｳ': 'ウ', 'ｴ': 'エ', 'ｵ': 'オ',
      'ｶ': 'カ', 'ｷ': 'キ', 'ｸ': 'ク', 'ｹ': 'ケ', 'ｺ': 'コ',
      'ｻ': 'サ', 'ｼ': 'シ', 'ｽ': 'ス', 'ｾ': 'セ', 'ｿ': 'ソ',
      'ﾀ': 'タ', 'ﾁ': 'チ', 'ﾂ': 'ツ', 'ﾃ': 'テ', 'ﾄ': 'ト',
      'ﾅ': 'ナ', 'ﾆ': 'ニ', 'ﾇ': 'ヌ', 'ﾈ': 'ネ', 'ﾉ': 'ノ',
      'ﾊ': 'ハ', 'ﾋ': 'ヒ', 'ﾌ': 'フ', 'ﾍ': 'ヘ', 'ﾎ': 'ホ',
      'ﾏ': 'マ', 'ﾐ': 'ミ', 'ﾑ': 'ム', 'ﾒ': 'メ', 'ﾓ': 'モ',
      'ﾔ': 'ヤ', 'ﾕ': 'ユ', 'ﾖ': 'ヨ',
      'ﾗ': 'ラ', 'ﾘ': 'リ', 'ﾙ': 'ル', 'ﾚ': 'レ', 'ﾛ': 'ロ',
      'ﾜ': 'ワ', 'ﾝ': 'ン', 'ﾞ': '゛', 'ﾟ': '゜',
    };

    String result = input;
    dakutenMap.forEach((k, v) {
      result = result.replaceAll(k, v);
    });
    final sb = StringBuffer();
    for (int i = 0; i < result.length; i++) {
      final ch = result[i];
      sb.write(singleMap[ch] ?? ch);
    }
    return sb.toString();
  }

  /// 静止画バイトデータからQRコードを高速検出（Web環境用）
  Future<String?> scanQrFromBytes(Uint8List bytes) async {
    if (kIsWeb) {
      try {
        final qrs = await WebQrDetector.detectQr(bytes);
        if (qrs.isNotEmpty) {
          debugPrint('[PrescriptionQrService] WebネイティブBarcodeDetectorでQR検知: ${qrs.length}件');
          return qrs.map(normalizeHalfWidthKatakana).join('\n');
        }
      } catch (e) {
        debugPrint('[PrescriptionQrService] WebQrDetector error: $e');
      }
      return null;
    }
    return null;
  }

  /// 静止画ファイルパスまたはバイトからQRコードを読み取り、生テキストを抽出する（複数・分割QRコードに対応）
  Future<String?> scanQrFromImagePath(String imagePath, {Uint8List? imageBytes}) async {
    // 1. Web環境の場合: Webネイティブ高速QR検出
    if (kIsWeb && imageBytes != null) {
      final webResult = await scanQrFromBytes(imageBytes);
      if (webResult != null && webResult.isNotEmpty) {
        return webResult;
      }
      return null;
    }

    if (kIsWeb) {
      return null;
    }

    // 2. Android / iOS ネイティブ環境: Google ML Kit Barcode Scanning で静止画を解析
    final controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
    );
    try {
      DebugLogService.instance.log('[ネイティブQR解析] ML Kit analyzeImage 開始: $imagePath');
      final BarcodeCapture? capture = await controller
          .analyzeImage(imagePath)
          .timeout(const Duration(seconds: 6), onTimeout: () => null);
      if (capture != null && capture.barcodes.isNotEmpty) {
        final values = <String>[];
        for (final barcode in capture.barcodes) {
          final val = extractBarcodeText(barcode);
          if (val != null && val.trim().isNotEmpty && !values.contains(val.trim())) {
            values.add(val.trim());
          }
        }
        if (values.isNotEmpty) {
          DebugLogService.instance.log('[ネイティブQR解析] ✓ ${values.length}件のQR抽出に成功');
          return values.join('\n');
        }
      }
      DebugLogService.instance.log('[ネイティブQR解析] 静止画内にQRコードが見つかりませんでした');
      return null;
    } catch (e) {
      DebugLogService.instance.log('[ネイティブQR解析エラー] $e');
      return null;
    } finally {
      controller.dispose();
    }
  }

  /// QRコードから読み取られた生テキストを解析し、PrescriptionRecordを生成する
  /// JAHIS標準フォーマットのローカル高速解析を最優先（待機時間0秒）で実行し、
  /// 自由テキスト形式等の場合のみGemini APIへフォールバック
  Future<PrescriptionRecord> parsePrescriptionText(String rawText) async {
    final trimmed = normalizeHalfWidthKatakana(rawText.trim());
    if (trimmed.isEmpty) {
      throw Exception('QRコードのデータが空です。');
    }

    // 1. ローカルJAHIS／カンマ区切り／JSON解析を最優先で実行（所要時間0.001秒）
    final localRecord = parseLocalJahisOrText(trimmed);
    final hasValidMeds = localRecord.medications.any(
      (m) => m.name.isNotEmpty && m.name != '処方薬',
    );

    if (hasValidMeds) {
      return localRecord;
    }

    // 2. ローカル解析で薬品情報が取れなかった場合のみ、Gemini APIによるAI解析を実行
    try {
      final apiKey = await _geminiService.getApiKey();
      if (apiKey.isNotEmpty) {
        final parsedMap = await _geminiService
            .parsePrescriptionFromQrText(trimmed)
            .timeout(const Duration(seconds: 6));
        if (parsedMap['error'] == null && parsedMap['medications'] != null) {
          final geminiRecord = PrescriptionRecord.fromJson(parsedMap);
          if (geminiRecord.medications.isNotEmpty) {
            return geminiRecord;
          }
        }
      }
    } catch (e) {
      debugPrint('Gemini prescription parse failed, using local result: $e');
    }

    return localRecord;
  }

  /// JAHIS電子お薬手帳フォーマット（JAHISTC）、院外処方せん2次元シンボル（JAHIS10等）、
  /// カンマ区切り、JSON、またはプレーンテキストをローカルで正確に構造化
  static PrescriptionRecord parseLocalJahisOrText(String rawText) {
    final normalizedText = normalizeHalfWidthKatakana(rawText.trim());

    // 1. JSON形式の場合
    if (normalizedText.startsWith('{') && normalizedText.endsWith('}')) {
      try {
        final decoded = jsonDecode(normalizedText) as Map<String, dynamic>;
        return PrescriptionRecord.fromJson(decoded);
      } catch (_) {}
    }

    final lines = normalizedText
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    String? hospitalName;
    String? department;
    String? doctorName;
    String? pharmacyName;
    String? pharmacistName;
    DateTime date = DateTime.now();
    int? cost;

    // RP番号ごとの薬品リスト・用法・剤形を管理
    final Map<String, List<_JahisDrugEntry>> rpDrugs = {};
    final Map<String, String> rpUsage = {};
    final Map<String, String> rpCategory = {};
    final List<PrescriptionMedication> directMedications = [];

    bool isJahisFormat = false;
    String lastRpNumber = '1';

    for (final line in lines) {
      final parts = line.split(',').map((p) => p.trim()).toList();
      if (parts.isEmpty) continue;

      final code = parts[0];
      final upperCode = code.toUpperCase();

      // ヘッダー行 (JAHISTC08, JAHIS10, H,Ver... 等)
      if (upperCode.startsWith('JAHIS') || upperCode == 'H') {
        isJahisFormat = true;
        continue;
      }

      // レコード番号が数値のJAHISレコードか判定
      if (RegExp(r'^\d+$').hasMatch(code)) {
        isJahisFormat = true;

        switch (code) {
          case '1':
            // 1: 患者情報レコード (1,氏名,性別,生年月日,...)
            break;

          case '5':
          case '52':
            // 5: 調剤年月日レコード (5,20260415,1 または 5,R080415,1)
            // 52: 処方せん交付年月日レコード (52,20260415)
            if (parts.length > 1 && parts[1].isNotEmpty) {
              final d = _parseDateString(parts[1]);
              if (d != null) date = d;
            }
            break;

          case '11':
            // 11: 調剤－医療機関等（薬局）レコード
            // 標準: 11,薬局名称,都道府県コード,点数表,薬局コード,郵便番号,所在地,電話番号,...
            final name = _extractInstitutionName(parts);
            if (name != null) pharmacyName = name;
            break;

          case '15':
            // 15: 調剤－薬剤師レコード (15,薬剤師名,連絡先,...)
            if (parts.length > 1 && parts[1].isNotEmpty && !_isNumericOrCode(parts[1])) {
              pharmacistName = parts[1];
            }
            break;

          case '51':
            // 51: 処方－医療機関（病院・クリニック）レコード
            // お薬手帳標準: 51,医療機関名称,都道府県コード,点数表,医療機関コード,...
            // 処方せん標準: 51,都道府県コード,点数表,医療機関コード,医療機関名称,所在地,電話番号,...
            final name = _extractInstitutionName(parts);
            if (name != null) hospitalName = name;
            break;

          case '21':
          case '53':
            // 診療科レコード (53,コード種別,診療科名 または 21,診療科名)
            for (int i = 1; i < parts.length; i++) {
              if (parts[i].isNotEmpty && !_isNumericOrCode(parts[i])) {
                department = parts[i];
                break;
              }
            }
            break;

          case '22':
          case '55':
            // 55: 処方－医師レコード
            // お薬手帳標準: 55,医師氏名,診療科名,レコード作成者
            // 処方せん標準: 55,医師コード,医師漢字氏名,医師カナ氏名
            final nonNumeric = <String>[];
            for (int i = 1; i < parts.length; i++) {
              if (parts[i].isNotEmpty && !_isNumericOrCode(parts[i])) {
                nonNumeric.add(parts[i]);
              }
            }
            if (nonNumeric.isNotEmpty) {
              doctorName = nonNumeric[0];
              if (nonNumeric.length >= 2 &&
                  (nonNumeric[1].contains('科') || nonNumeric[1].contains('部') || nonNumeric[1].contains('外来'))) {
                department = nonNumeric[1];
              }
            }
            break;

          case '101':
            // 101: 剤形レコード（院外処方せん2次元シンボル）
            // 101,RP番号,剤形区分(1:内服,2:頓服,3:外用...),剤形名称,調剤数量(日数)
            if (parts.length > 1 && parts[1].isNotEmpty) {
              final rp = parts[1];
              lastRpNumber = rp;
              if (parts.length > 2) {
                final cat = _mapCategoryCode(parts[2]);
                if (cat != null) rpCategory[rp] = cat;
              }
              if (parts.length > 4 && parts[4].isNotEmpty && RegExp(r'^\d+$').hasMatch(parts[4])) {
                final unit = (rpCategory[rp] == '内服') ? '日分' : '回分';
                final existing = rpUsage[rp] ?? '';
                if (!existing.contains('${parts[4]}$unit')) {
                  rpUsage[rp] = [existing, '${parts[4]}$unit'].where((s) => s.isNotEmpty).join(' ');
                }
              }
            }
            break;

          case '111':
            // 111: 用法レコード（院外処方せん2次元シンボル）
            // 111,RP番号,用法コード種別,用法コード,用法名称,1日回数
            if (parts.length > 1 && parts[1].isNotEmpty) {
              final rp = parts[1];
              lastRpNumber = rp;
              String usageName = '';
              if (parts.length > 4 && parts[4].isNotEmpty && !_isNumericOrCode(parts[4])) {
                usageName = parts[4];
              } else {
                for (int i = 2; i < parts.length; i++) {
                  if (parts[i].isNotEmpty && !_isNumericOrCode(parts[i])) {
                    usageName = parts[i];
                    break;
                  }
                }
              }
              if (usageName.isNotEmpty) {
                final existing = rpUsage[rp] ?? '';
                rpUsage[rp] = [usageName, existing].where((s) => s.isNotEmpty).join(' ');
              }
            }
            break;

          case '201':
            // 201: 薬品レコード
            // パターン1 (お薬手帳標準): 201,RP番号,薬品名称,用量,単位名,薬品コード種別,薬品コード,...
            // パターン2 (お薬手帳連番付): 201,RP番号,RP内連番,薬品名称,用量,単位名,薬品コード種別,薬品コード,...
            // パターン3 (院外処方せん): 201,RP番号,RP内連番,情報区分,薬品コード種別,薬品コード,薬品名称,用量,力価フラグ,単位名,...
            final parsedDrug = _parseRecord201(parts, lastRpNumber);
            if (parsedDrug != null) {
              lastRpNumber = parsedDrug.rpNumber;
              rpDrugs.putIfAbsent(parsedDrug.rpNumber, () => []).add(parsedDrug);
            }
            break;

          case '281':
          case '291':
            // 薬品補足レコード (281,RP番号,薬品連番,薬品補足区分,薬品補足内容,...)
            if (parts.length > 2) {
              final rp = parts[1].isNotEmpty ? parts[1] : lastRpNumber;
              final list = rpDrugs[rp];
              if (list != null && list.isNotEmpty) {
                for (int i = 2; i < parts.length; i++) {
                  if (parts[i].isNotEmpty && !_isNumericOrCode(parts[i])) {
                    list.last.supplement = [list.last.supplement, parts[i]]
                        .where((s) => s != null && s.isNotEmpty)
                        .join(' ');
                    break;
                  }
                }
              }
            }
            break;

          case '301':
            // 301: 用法レコード（電子版お薬手帳）
            // パターンA: 301,RP番号,用法名称,調剤数量,調剤単位,剤型区分,用法コード種別,用法コード,...
            // パターンB: 301,RP番号,用法名称,調剤数量,剤型区分,用法コード種別,用法コード,...
            if (parts.length > 2) {
              final rp = parts[1].isNotEmpty ? parts[1] : lastRpNumber;
              lastRpNumber = rp;
              final usageName = parts[2];
              String qtyAndUnit = '';
              String? category;

              if (parts.length > 3 && parts[3].isNotEmpty) {
                final qty = parts[3];
                if (parts.length > 4 && parts[4].isNotEmpty) {
                  // parts[4] が「日分」「回分」「全量」等の単位か、それとも剤型コード(1,2,3)か判定
                  if (RegExp(r'^\d+$').hasMatch(parts[4])) {
                    category = _mapCategoryCode(parts[4]);
                    final defaultUnit = (category == '外用') ? '全量' : (category == '頓服' ? '回分' : '日分');
                    qtyAndUnit = '$qty$defaultUnit';
                  } else {
                    qtyAndUnit = '$qty${parts[4]}';
                    if (parts.length > 5 && parts[5].isNotEmpty) {
                      category = _mapCategoryCode(parts[5]);
                    }
                  }
                } else {
                  qtyAndUnit = '$qty日分';
                }
              }

              // 用法文字列から外用・内服・頓服を補助判定
              category ??= _inferCategoryFromText('$usageName $qtyAndUnit');
              if (category != null) {
                rpCategory[rp] = category;
              }

              final fullUsage = [usageName, qtyAndUnit].where((s) => s.isNotEmpty).join(' ');
              if (fullUsage.isNotEmpty) {
                rpUsage[rp] = fullUsage;
              }
            }
            break;

          case '311':
            // 311: 用法補足レコード (311,RP番号,用法補足連番,用法補足区分,用法補足内容,...)
            if (parts.length > 2) {
              final rp = parts[1].isNotEmpty ? parts[1] : lastRpNumber;
              for (int i = 2; i < parts.length; i++) {
                if (parts[i].isNotEmpty && !_isNumericOrCode(parts[i])) {
                  final existing = rpUsage[rp] ?? '';
                  rpUsage[rp] = [existing, parts[i]].where((s) => s.isNotEmpty).join(' ');
                  break;
                }
              }
            }
            break;
        }
        continue;
      }

      // JAHIS以外の単純カンマ区切り（薬品名, 用法）の場合
      if (!isJahisFormat && parts.length >= 2) {
        final possibleName = parts[0];
        final possibleDosage = parts[1];
        if (possibleName.isNotEmpty && !possibleName.contains(':') && !possibleName.contains('http')) {
          directMedications.add(PrescriptionMedication(
            name: possibleName,
            dosage: possibleDosage.isNotEmpty ? possibleDosage : '指示通り服用',
            category: _inferCategoryFromText('$possibleName $possibleDosage'),
            efficacy: MedicationEfficacyHelper.getEfficacy(possibleName),
          ));
        }
      }
    }

    // JAHIS RPグループから PrescriptionMedication リストを組み立て
    final List<PrescriptionMedication> medications = [];
    for (final entry in rpDrugs.entries) {
      final rp = entry.key;
      final drugs = entry.value;
      final usage = rpUsage[rp] ?? '';
      final rpCat = rpCategory[rp];

      for (final d in drugs) {
        final cat = rpCat ?? _inferCategoryFromText('${d.name} ${d.amountUnit} $usage') ?? '内服';
        final dosageParts = <String>[
          if (d.amountUnit.isNotEmpty) '1日/1回量:${d.amountUnit}',
          if (usage.isNotEmpty) usage,
          if (d.supplement != null && d.supplement!.isNotEmpty) d.supplement!,
        ];
        final dosageStr = dosageParts.isNotEmpty ? dosageParts.join(' / ') : '医師・薬剤師の指示通り';

        medications.add(PrescriptionMedication(
          name: d.name,
          dosage: dosageStr,
          category: cat,
          efficacy: MedicationEfficacyHelper.getEfficacy(d.name),
        ));
      }
    }

    if (medications.isEmpty && directMedications.isNotEmpty) {
      medications.addAll(directMedications);
    }

    // もし上記で薬品が取れなかった場合、一般的な改行テキストから抽出
    if (medications.isEmpty) {
      for (final line in lines) {
        if (line.contains('クリニック') || line.contains('病院') || line.contains('医院') || line.contains('皮フ科') || line.contains('皮膚科')) {
          hospitalName ??= line;
        } else if (line.contains('薬局')) {
          pharmacyName ??= line;
        } else if (line.contains('錠') ||
            line.contains('カプセル') ||
            line.contains('散') ||
            line.contains('軟膏') ||
            line.contains('ローション') ||
            line.contains('クリーム') ||
            line.contains('テープ') ||
            line.contains('点眼') ||
            line.contains('mg') ||
            line.contains('包') ||
            line.contains('%')) {
          medications.add(PrescriptionMedication(
            name: line,
            dosage: '医師・薬剤師の指示通り服用',
            category: _inferCategoryFromText(line) ?? '内服',
            efficacy: MedicationEfficacyHelper.getEfficacy(line),
          ));
        }
      }
    }

    // 病院名が空で薬局名がある場合は薬局名をタイトルに補完、両方なければデフォルト
    final resolvedHospitalName = (hospitalName != null && hospitalName.isNotEmpty)
        ? hospitalName
        : ((pharmacyName != null && pharmacyName.isNotEmpty) ? pharmacyName : '処方医療機関');

    return PrescriptionRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: date,
      hospitalName: resolvedHospitalName,
      department: department,
      doctorName: doctorName,
      pharmacyName: pharmacyName,
      pharmacistName: pharmacistName,
      cost: cost,
      medications: medications,
      notes: 'QRコード読み取りデータより自動登録',
    );
  }

  /// 11レコード・51レコードから医療機関・薬局名称を抽出
  static String? _extractInstitutionName(List<String> parts) {
    // 1番目または4番目など、数値・都道府県コード・郵便番号・電話番号以外の最初の文字列を名称として採用
    for (int i = 1; i < parts.length; i++) {
      final val = parts[i];
      if (val.isEmpty) continue;
      if (_isNumericOrCode(val)) continue;
      return val;
    }
    return null;
  }

  /// 201（薬品レコード）から薬品名称・分量・単位を全JAHISバージョン横断で抽出
  static _JahisDrugEntry? _parseRecord201(List<String> parts, String fallbackRp) {
    if (parts.length < 3) return null;
    final rp = parts[1].isNotEmpty ? parts[1] : fallbackRp;

    // 薬品名称の位置を探す（index 2 以降で数値・コードではない最初のフィールド）
    int nameIdx = -1;
    for (int i = 2; i < parts.length; i++) {
      final candidate = parts[i];
      if (candidate.isEmpty) continue;
      if (!_isNumericOrCode(candidate)) {
        nameIdx = i;
        break;
      }
    }

    if (nameIdx == -1) return null;
    final drugName = parts[nameIdx];

    // 薬品名称の直後から分量（数値）と単位を探す
    String amount = '';
    String unit = '';
    if (nameIdx + 1 < parts.length) {
      final next1 = parts[nameIdx + 1];
      if (RegExp(r'^\d+(\.\d+)?$').hasMatch(next1)) {
        amount = next1;
        if (nameIdx + 2 < parts.length) {
          final next2 = parts[nameIdx + 2];
          // 院外処方せん規格では [用量, 力価フラグ(1or2), 単位名] の順になる場合がある
          if (RegExp(r'^[12]$').hasMatch(next2) &&
              nameIdx + 3 < parts.length &&
              parts[nameIdx + 3].isNotEmpty &&
              !RegExp(r'^\d+$').hasMatch(parts[nameIdx + 3])) {
            unit = parts[nameIdx + 3];
          } else if (!RegExp(r'^\d+$').hasMatch(next2)) {
            unit = next2;
          }
        }
      }
    }

    if (unit == 'Ｃ' || unit == 'C') unit = 'カプセル';

    return _JahisDrugEntry(
      rpNumber: rp,
      name: drugName,
      amountUnit: '$amount$unit',
    );
  }

  /// 数値のみ、または都道府県コード・点数表・レセ電コード・電話番号・郵便番号かどうかを判定
  static bool _isNumericOrCode(String val) {
    // 純粋な数値・小数、ハイフン付き数字（郵便番号・電話番号）、または1文字の区分フラグ
    if (RegExp(r'^[\d\.\-]+$').hasMatch(val)) return true;
    // YJコード等の英数字コード (例: 620004992, 1111111F1020 等、7桁以上の英数字のみ)
    if (val.length >= 7 && RegExp(r'^[A-Z0-9]+$').hasMatch(val)) return true;
    return false;
  }

  static String? _mapCategoryCode(String code) {
    switch (code.trim()) {
      case '1':
        return '内服';
      case '2':
        return '頓服';
      case '3':
        return '外用';
      case '4':
        return '注射';
      default:
        return null;
    }
  }

  static String? _inferCategoryFromText(String text) {
    if (text.contains('外用') ||
        text.contains('塗布') ||
        text.contains('軟膏') ||
        text.contains('ローション') ||
        text.contains('クリーム') ||
        text.contains('貼付') ||
        text.contains('テープ') ||
        text.contains('パップ') ||
        text.contains('点眼') ||
        text.contains('点鼻') ||
        text.contains('うがい')) {
      return '外用';
    }
    if (text.contains('頓服') || text.contains('痛い時') || text.contains('頭痛時') || text.contains('発熱時')) {
      return '頓服';
    }
    if (text.contains('内服') || text.contains('食後') || text.contains('食前') || text.contains('就寝前') || text.contains('起床時')) {
      return '内服';
    }
    return null;
  }

  /// "20260415", "2026/04/15", または和暦 "R080415", "R8.4.15" 等の文字列をDateTimeに変換
  static DateTime? _parseDateString(String str) {
    try {
      final s = str.trim().toUpperCase();

      // 和暦対応 (R: 令和, H: 平成, S: 昭和) + 6桁数字 (例: R020410, R080415)
      final eraMatch = RegExp(r'^([RHS])(\d{1,2})[\/\-\.]?(\d{1,2})[\/\-\.]?(\d{1,2})$').firstMatch(
        s.length == 7 && RegExp(r'^[RHS]\d{6}$').hasMatch(s)
            ? '${s.substring(0, 1)}${s.substring(1, 3)}/${s.substring(3, 5)}/${s.substring(5, 7)}'
            : s,
      );
      if (eraMatch != null) {
        final era = eraMatch.group(1)!;
        final eraYear = int.parse(eraMatch.group(2)!);
        final month = int.parse(eraMatch.group(3)!);
        final day = int.parse(eraMatch.group(4)!);
        int year = eraYear;
        if (era == 'R') year = 2018 + eraYear;
        if (era == 'H') year = 1988 + eraYear;
        if (era == 'S') year = 1925 + eraYear;
        return DateTime(year, month, day);
      }

      // 西暦8桁 (例: 20260415)
      final clean = s.replaceAll(RegExp(r'[\/\-\.年月日]'), '');
      if (clean.length == 8 && RegExp(r'^\d{8}$').hasMatch(clean)) {
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

class _JahisDrugEntry {
  final String rpNumber;
  final String name;
  final String amountUnit;
  String? supplement;

  _JahisDrugEntry({
    required this.rpNumber,
    required this.name,
    required this.amountUnit,
  });
}
