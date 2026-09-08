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
    final prompt = """
ユーザーの入力テキストから以下の情報を抽出し、必ず指定されたJSONフォーマットのみを出力してください。マークダウンブロック（```json）は含めないでください。
1. condition_score: 体調スコア (1-10の整数、不明ならnull)
2. symptoms: 症状のリスト (文字列の配列、なければ空配列)
3. medications: 服用した薬のリスト。各薬は {"name": "薬の名前", "time": "HH:MM"} の形式（時間は24時間表記）。時間が不明な場合は "time": null。なければ空配列。
4. weight: 体重（数値、kg、不明ならnull）
5. steps: 歩数（整数、不明ならnull）
6. bodyFat: 体脂肪率（数値、%、不明ならnull）
7. bmi: BMI（数値、不明なら計算するかnull）
8. bmr: 基礎代謝（整数、kcal、不明ならnull）
9. calories: 消費カロリー（整数、kcal、アクティブと安静時の合計など、不明ならnull）
10. sleepHours: 睡眠時間（数値、時間、例: 7.5、不明ならnull）
11. workouts: 筋トレなどの運動リスト。各運動は {"name": "種目名", "weight": 重さ(kg, 数値), "reps": 回数(整数), "sets": セット数(整数)}。不明な数値項目は0。なければ空配列。

入力テキスト:
"$userInput"

フォーマット:
{
  "condition_score": 8,
  "symptoms": ["頭痛", "吐き気"],
  "medications": [{"name": "ロキソニン", "time": "08:00"}],
  "weight": 65.2,
  "steps": 5000,
  "bodyFat": 20.5,
  "bmi": 22.1,
  "bmr": 1500,
  "calories": 400,
  "sleepHours": 7.5,
  "workouts": [
    {"name": "ベンチプレス", "weight": 50, "reps": 10, "sets": 3}
  ]
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

  Future<Map<String, dynamic>> extractHealthDataFromImage(List<int> imageBytes, String mimeType, {String? extraInput}) async {
    final prompt = '''
あなたはプロの医療・健康アシスタントであり、処方箋や薬袋、お薬手帳のQRコードなどの読み取りのプロです。
添付された画像から「薬の名前」や「健康に関する情報」を抽出し、以下のJSONフォーマットで返してください。
もしJAHIS標準のQRコード画像であれば、そこから薬の情報を抽出してください。
ユーザーからの追加コメント: "${extraInput ?? '特になし'}"

出力フォーマット（JSON）:
{
  "condition_score": 1〜10の整数 (指定がなければnull),
  "symptoms": ["症状1"],
  "medications": [
    { "name": "薬の名前1", "time": "08:30" }
  ],
  "weight": 小数（指定がなければnull）,
  "steps": 整数（指定がなければnull）,
  "bodyFat": 小数（指定がなければnull）,
  "bmi": 小数（指定がなければnull）,
  "bmr": 整数（指定がなければnull）,
  "calories": 整数（指定がなければnull）,
  "sleepHours": 小数（指定がなければnull）,
  "workouts": []
}
Markdownのコードブロック(```json)は含めず、純粋なJSON文字列のみを出力してください。
''';

    try {
      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart(mimeType, Uint8List.fromList(imageBytes)),
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
