import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'package:shared_preferences/shared_preferences.dart';

class GeminiService {
  String? _customApiKey;
  
  final List<String> _fallbackModels = [
    'gemini-flash-lite-latest', // 最新Liteモデル自動追従
    'gemini-2.5-flash-lite',    // 2.5 Lite
    'gemini-2.0-flash-lite',    // 2.0 Lite
    'gemini-1.5-flash',         // 安定版 Flash
    'gemini-2.0-flash',         // 2.0 Flash
    'gemini-3.5-flash-lite',    // 3.5 Lite
    'gemini-flash-latest',      // Flash latest
  ];

  String get defaultModel => _fallbackModels.first;
  List<String> get fallbackModels => List.unmodifiable(_fallbackModels);

  GeminiService();

  /// 有効なAPIキーを取得（カスタム設定 > dart-define > .env の順）
  Future<String> getApiKey() async {
    if (_customApiKey != null && _customApiKey!.isNotEmpty) {
      return _customApiKey!;
    }
    // 1. GitHub Actions等でビルド時にBase64埋め込みされたキーを最優先デコード
    const b64Key = String.fromEnvironment('GEMINI_API_KEY_B64');
    if (b64Key.isNotEmpty) {
      try {
        final decoded = utf8.decode(base64.decode(b64Key)).trim();
        if (decoded.isNotEmpty) {
          _customApiKey = decoded;
          return decoded;
        }
      } catch (_) {}
    }

    // 2. 平文のビルド環境変数
    const envKey = String.fromEnvironment('GEMINI_API_KEY');
    if (envKey.isNotEmpty) {
      _customApiKey = envKey;
      return envKey;
    }

    // 3. 端末のSharedPreferences（手動上書き設定がある場合）
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString('custom_gemini_api_key');
    if (savedKey != null && savedKey.isNotEmpty) {
      _customApiKey = savedKey;
      return savedKey;
    }

    try {
      final dotKey = dotenv.env['GEMINI_API_KEY'];
      if (dotKey != null && dotKey.isNotEmpty) {
        return dotKey;
      }
    } catch (_) {}

    return '';
  }

  /// APIキーを端末のSharedPreferencesに保存
  Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      await prefs.remove('custom_gemini_api_key');
      _customApiKey = null;
    } else {
      await prefs.setString('custom_gemini_api_key', trimmed);
      _customApiKey = trimmed;
    }
  }

  /// 保存されたAPIキーを削除
  Future<void> clearApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('custom_gemini_api_key');
    _customApiKey = null;
  }

  /// Google APIから現在利用可能なモデル一覧を動的取得
  Future<List<Map<String, dynamic>>> fetchAvailableModels() async {
    final key = await getApiKey();
    if (key.isEmpty) {
      throw Exception('Gemini APIキーが設定されていません。設定画面からキーをご入力ください。');
    }
    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$key');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final models = data['models'] as List<dynamic>? ?? [];
      return models.map((m) => Map<String, dynamic>.from(m as Map)).toList();
    } else {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }

  /// 利用可能なFlash/Lite系モデルを抽出して返却
  Future<List<Map<String, dynamic>>> fetchLiteModels() async {
    final all = await fetchAvailableModels();
    return all.where((m) {
      final name = (m['name'] as String? ?? '').toLowerCase();
      final methods = (m['supportedGenerationMethods'] as List<dynamic>?) ?? [];
      final canGenerate = methods.contains('generateContent');
      return canGenerate && (name.contains('flash-lite') || name.contains('flash-latest'));
    }).toList();
  }
  
  Future<GenerateContentResponse> _generateWithFallback(List<Content> content) async {
    final key = await getApiKey();
    if (key.isEmpty) {
      throw Exception('Gemini APIキーが未設定です。設定タブからAPIキーをご登録ください。');
    }

    final errors = <String>[];
    for (int i = 0; i < _fallbackModels.length; i++) {
      final modelName = _fallbackModels[i];
      try {
        final model = GenerativeModel(model: modelName, apiKey: key);
        return await model.generateContent(content);
      } catch (e) {
        print('Gemini API Error with $modelName: $e');
        errors.add('$modelName: $e');
      }
    }
    throw Exception('全モデル試行失敗:\n${errors.join('\n')}');
  }

  Future<Map<String, dynamic>> extractHealthData(String userInput) async {
    final now = DateTime.now();
    final todayStr = "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    final prompt = """
現在の日付（基準日）: $todayStr
ユーザーの入力テキストから健康情報を抽出し、AI Health Coachとしての寄り添いメッセージと共に指定されたJSONフォーマットのみを出力してください。マークダウンブロック（```json）は含めないでください。

【抽出および応答指示】
1. date: 記録対象の日付（"YYYY-MM-DD"形式の文字列）。入力テキスト中に「昨日」「一昨日」「9月8日」「2026/09/08」「3日前」などの日付表現がある場合は、基準日（$todayStr）から正確に計算してその日付を設定してください。日付の指定が全くない場合は null。
2. reply: ユーザーの症状、体調、運動・トレーニング、お薬の服用に対して、AIヘルスコーチとして寄り添う温かい共感やアドバイス、励ましのメッセージ（2〜3文程度、自然で親切な日本語）。
   - 否定や取り消し（例:「頭痛も肩こりもないよ」）に対しては、「頭痛や肩こりはないのですね！安心いたしました。記録から症状を取り消し、お薬の服用のみの状態に修正いたしました。」のように訂正を受け止めたメッセージにしてください。
   - 定期服薬の報告に対しては、「お薬の服用記録をつけました。毎日しっかり続けられていて素晴らしいです！」のように寄り添ってください。
3. condition_score: 体調スコア (1-10の整数。ユーザーが数値を指定している場合はその値。ユーザーが「頭痛がひどい」「熱がある」など明示的に不調を訴えている場合のみ3〜4などを推定。不調の訴えがない場合や否定している場合は不当にスコアを下げず、null または 7〜8 としてください)。
4. symptoms: 症状のリスト (文字列の配列、なければ空配列 []。例: ["頭痛"])
   - 【最重要・厳禁ルール】: ユーザー本人が「頭痛がする」「肩がこる」「だるい」など、直接・明示的に自覚症状を訴えた場合のみ抽出してください。
   - 【禁止事項】: 服用した薬（例: ミグシス、エペリゾン、川芎茶調散、降圧剤、ビタミン剤等）の効能・適応症から推測して、「薬を飲んだからこの症状があるはずだ」と勝手に症状を作り出して記録することは絶対に禁止です（定期服薬や予防薬であるため、症状がない場合が多いため）。薬を飲んだとだけ言っている場合は必ず symptoms は [] にしてください。
5. remove_symptoms: ユーザーが「頭痛もない」「肩こりもない」「痛くない」「熱はない」「取り消して」「間違えた」「治った」など、症状を否定・取り消し・解除した症状のリスト（文字列の配列、なければ空配列 []。例: ["頭痛", "肩こり"]）。
6. clear_all_symptoms: ユーザーが「症状はない」「症状を全部消して」のように全ての症状の取り消しを指示している場合は true、そうでなければ false。
7. medications: 服用した薬のリスト。各薬は {"name": "薬の名前", "time": "HH:MM"} の形式（時間は24時間表記）。時間が不明な場合は "time": null。なければ空配列 []。
8. weight: 体重（数値、kg、不明ならnull）
9. steps: 歩数（整数、不明ならnull）
10. bodyFat: 体脂肪率（数値、%、不明ならnull）
11. bmi: BMI（数値、不明なら計算するかnull）
12. bmr: 基礎代謝（整数、kcal、不明ならnull）
13. calories: 消費カロリー（整数、kcal、アクティブと安静時の合計など、不明ならnull）
14. sleepHours: 睡眠時間（数値、時間、例: 7.5、不明ならnull）
15. workouts: 筋トレなどの運動リスト。各運動は {"name": "種目名", "weight": 重さ(kg, 数値), "reps": 回数(整数), "sets": セット数(整数)}。不明な数値項目は0。なければ空配列 []。
16. prescription: 処方箋・医療機関での処方情報がある場合のみ以下のオブジェクト（なければnull）。
    - hospital_name: 病院・クリニック名（例: 栗田皮フ科、不明ならnull）
    - department: 診療科（例: 皮膚科、不明ならnull）
    - doctor_name: 医師名（不明ならnull）
    - pharmacy_name: 薬局名（例: オリーブ薬局、不明ならnull）
    - cost: 自己負担額・医療費（整数、円、不明ならnull）
    - medications: 処方薬の詳細リスト。各薬は {"name": "薬品名", "dosage": "用法用量・規格", "category": "外用/内服/頓服", "efficacy": "効能・効果のわかりやすい解説", "side_effects": "主な副作用", "precautions": "注意事項"}。

入力テキスト:
"$userInput"

フォーマット:
{
  "date": null,
  "reply": "お薬の服用を記録しました。毎日しっかり続けられていて素晴らしいです！",
  "condition_score": null,
  "symptoms": [],
  "remove_symptoms": [],
  "clear_all_symptoms": false,
  "medications": [
    {"name": "ミグシス", "time": null}
  ],
  "weight": null,
  "steps": null,
  "bodyFat": null,
  "bmi": null,
  "bmr": null,
  "calories": null,
  "sleepHours": null,
  "workouts": [],
  "prescription": null
}
""";

    try {
      final content = [Content.text(prompt)];
      final response = await _generateWithFallback(content);
      final text = response.text ?? '{}';
      
      try {
        final cleanText = text.replaceAll('```json', '').replaceAll('```', '').trim();
        return jsonDecode(cleanText);
      } catch (parseError) {
        return {'error': 'Parse error', 'raw': text};
      }
    } catch (e) {
      print('All Gemini APIs Failed: $e');
      return {'error': 'API error', 'message': e.toString()};
    }
  }

  static String resolveMimeType(List<int> bytes, String? fallback) {
    if (bytes.length >= 4) {
      if (bytes[0] == 0xFF && bytes[1] == 0xD8) return 'image/jpeg';
      if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return 'image/png';
      if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return 'image/gif';
      if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) return 'image/webp';
    }
    if (fallback != null && fallback.isNotEmpty && fallback.contains('/')) {
      return fallback;
    }
    return 'image/jpeg';
  }

  Future<Map<String, dynamic>> extractHealthDataFromImage(List<int> imageBytes, String mimeType, {String? extraInput}) async {
    final effectiveMimeType = resolveMimeType(imageBytes, mimeType);
    final now = DateTime.now();
    final todayStr = "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    final prompt = '''
あなたはプロの医療・健康管理AIアシスタントです。
現在の日付（基準日）: $todayStr
画像から「処方箋・薬袋・お薬手帳のQRコード」および「体重計・体組成計の液晶画面・ヘルスケア測定アプリのスクリーンショット（体重、体脂肪率、BMI、骨量、筋肉量、基礎代謝、歩数等）」の情報を高精度に抽出し、以下のJSONフォーマットのみで返してください。

【読み取り指示】
1. date: 記録対象の日付（"YYYY-MM-DD"形式）。画像内の測定日時・調剤日・処方日、またはユーザー追加コメントに日付の指定（昨日、9月8日等）があればその日付を設定、なければ null。
2. reply: ユーザーの症状、体調、画像の内容（処方箋や測定値）に対して、AIヘルスコーチとして寄り添う温かい共感やアドバイス、アドバイスメッセージ（2〜3文程度、自然で親切な日本語）。
3. condition_score: 1〜10の整数 (指定または症状・体調が推測できれば設定、明らかな体調不良時は3〜4等、好調なら7〜8等、不明ならnull)
3. 体重計・体組成計の画面や測定アプリのスクショの場合:
   - 体重(kg)の数値を weight に格納 (例: 68.4)
   - 体脂肪率(%)の数値を bodyFat に格納 (例: 19.8)
   - BMIの数値を bmi に格納 (例: 22.5)
   - 基礎代謝(kcal)の数値を bmr に格納 (例: 1520)
   - 歩数があれば steps に格納
   - 消費カロリーがあれば calories に格納
4. 処方箋や薬袋・お薬手帳の場合:
   - 薬品名とおおよその服用時間を medications に格納
   - ユーザーのコメントや処方箋に病名・自覚症状が明記されている場合のみ symptoms に格納（薬品の効能から推測して勝手に症状を作り出すことは禁止）
   - 処方情報全体を prescription に構造化して格納:
     - hospital_name: 病院・クリニック名（例: 栗田皮フ科）
     - department: 診療科（例: 皮膚科）
     - doctor_name: 医師名
     - pharmacy_name: 調剤薬局名（例: オリーブ薬局幕張本郷店）
     - cost: 医療費の合計・自己負担額（数値、円）
     - medications: 各薬品の詳細。name(薬品名), dosage(用法用量・総量), category(外用/内服/頓服), efficacy(効能・効果の解説), side_effects(主な副作用), precautions(注意事項)
5. ユーザーからの追加コメント: "${extraInput ?? '特になし'}"

出力フォーマット（JSON）:
{
  "reply": "処方箋とお薬の情報を確認し、お薬手帳に記録しました。お体に気をつけて、用法用量を守ってお大事になさってくださいね。",
  "condition_score": 1〜10の整数 (指定または体調が推測できれば設定、不明ならnull),
  "symptoms": ["症状名"],
  "medications": [
    { "name": "薬の名前", "time": "08:30" }
  ],
  "weight": 小数 (kg、不明ならnull),
  "steps": 整数 (不明ならnull),
  "bodyFat": 小数 (%%、不明ならnull),
  "bmi": 小数 (不明ならnull),
  "bmr": 整数 (kcal、不明ならnull),
  "calories": 整数 (kcal、不明ならnull),
  "sleepHours": 小数 (時間、不明ならnull),
  "workouts": [],
  "prescription": {
    "hospital_name": "医療法人社団 栗田会 栗田皮フ科",
    "department": "皮膚科",
    "doctor_name": "栗田 依幸",
    "pharmacy_name": "オリーブ薬局幕張本郷店",
    "cost": 1180,
    "medications": [
      {
        "name": "リンデロン-Vローション",
        "dosage": "◆外用 塗布◆ 総量:20mL",
        "category": "外用",
        "efficacy": "ステロイド外用薬で皮膚の赤みやかゆみを抑えます。",
        "side_effects": "刺激感、長期連用時の皮膚菲薄化など",
        "precautions": "目の周囲を避け、指示された部位のみ使用"
      }
    ]
  }
}
Markdownのコードブロック(```json)は含めず、純粋なJSON文字列のみを出力してください。
''';

    try {
      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart(effectiveMimeType, Uint8List.fromList(imageBytes)),
        ])
      ];
      final response = await _generateWithFallback(content);
      final text = response.text ?? '{}';
      
      try {
        final cleanText = text.replaceAll('```json', '').replaceAll('```', '').trim();
        return jsonDecode(cleanText);
      } catch (parseError) {
        return {'error': 'Parse error', 'raw': text};
      }
    } catch (e) {
      print('All Gemini APIs Failed: $e');
      return {'error': 'API error', 'message': e.toString()};
    }
  }
}
