/// 薬品名の正規化（名寄せ・一般名化）および同一薬品判定ユーティリティ
class MedicationNormalizer {
  /// 代表的な先発品・一般名・同効薬のグループ化マッピング（正規化キー -> 代表名）
  static const Map<String, String> _aliasDictionary = {
    // 頭痛・片頭痛薬
    'アマージ': 'ナラトリプタン',
    'ナラトリプタン': 'ナラトリプタン',
    'レルパックス': 'エレトリプタン',
    'エレトリプタン': 'エレトリプタン',
    'ゾーミッグ': 'ゾルミトリプタン',
    'ゾルミトリプタン': 'ゾルミトリプタン',
    'イミグラン': 'スマトリプタン',
    'スマトリプタン': 'スマトリプタン',
    'マクサルト': 'リザトリプタン',
    'リザトリプタン': 'リザトリプタン',
    'ミグシス': 'ミグシス',
    'ロメリジン': 'ミグシス',
    'レイボー': 'ラスミジタン',
    'ラスミジタン': 'ラスミジタン',

    // 筋弛緩薬
    'ミオナール': 'エペリゾン',
    'エペリゾン': 'エペリゾン',
    'テルネリン': 'チザニジン',
    'チザニジン': 'チザニジン',
    'リンラキサー': 'クロルフェネシン',
    'クロルフェネシン': 'クロルフェネシン',

    // 鎮痛・消炎薬
    'ロキソニン': 'ロキソプロフェン',
    'ロキソプロフェン': 'ロキソプロフェン',
    'カロナール': 'カロナール',
    'アセトアミノフェン': 'カロナール',
    'セレコックス': 'セレコキシブ',
    'セレコキシブ': 'セレコキシブ',
    'ブルフェン': 'イブプロフェン',
    'イブプロフェン': 'イブプロフェン',
    'ボルタレン': 'ジクロフェナク',
    'ジクロフェナク': 'ジクロフェナク',

    // 漢方薬
    '川芎茶調散': '川芎茶調散',
    'センキュウチャチョウサン': '川芎茶調散',
    '葛根湯': '葛根湯',
    'カッコントウ': '葛根湯',
    '五苓散': '五苓散',
    'ゴレイサン': '五苓散',
    '釣藤散': '釣藤散',
    'チョウトウサン': '釣藤散',
    '呉茱萸湯': '呉茱萸湯',
    'ゴシュユトウ': '呉茱萸湯',

    // 外用薬・保湿剤
    'ヒルドイド': 'ヒルドイド',
    'ヘパリン類似物質': 'ヒルドイド',

    // 胃腸薬
    'ムコスタ': 'レバミピド',
    'レバミピド': 'レバミピド',
    'ガスター': 'ファモチジン',
    'ファモチジン': 'ファモチジン',
    'タケプロン': 'ランソプラゾール',
    'ランソプラゾール': 'ランソプラゾール',
    'ネキシウム': 'エソメプラゾール',
    'エソメプラゾール': 'エソメプラゾール',
    'タケキャブ': 'ボノプラザン',
    'ボノプラザン': 'ボノプラザン',
    'セルベックス': 'テプレノン',
    'テプレノン': 'テプレノン',
    'ビオフェルミン': 'ビオフェルミン',
  };

  /// 薬品名から不要なメーカー名、規格、剤形、塩類表記を除去して代表名を抽出
  static String normalize(String rawName) {
    if (rawName.trim().isEmpty) return '';

    String cleaned = rawName.trim();

    // 1. 全角英数字記号を半角に、前後の空白除去
    cleaned = _toHalfWidth(cleaned).trim();

    // 2. 括弧で囲まれたメーカー名・屋号・補足情報を除去
    // 例: 「KO」「トーワ」「サワイ」, (医療用), 【JG】
    cleaned = cleaned.replaceAll(RegExp(r'「[^」]*」'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\(.*?\)'), '');
    cleaned = cleaned.replaceAll(RegExp(r'（.*?）'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\[.*?\]'), '');
    cleaned = cleaned.replaceAll(RegExp(r'【.*?】'), '');
    cleaned = cleaned.replaceAll(RegExp(r'〈.*?〉'), '');

    // 3. 前置メーカー名や漢方ブランドを除去
    // 例: ツムラ川芎茶調散エキス顆粒 -> 川芎茶調散エキス顆粒
    cleaned = cleaned.replaceFirst(
      RegExp(r'^(ツムラ|クラシエ|コタロー|サワイ|トーワ|日医工|日新|テイコク|ニプロ|タカタ|ケミファ|明治|小林|第一三共|武田|アステラス|大正|興和|大塚|ロート)\s*'),
      '',
    );

    // 4. 漢方エキス表記を前処理
    if (cleaned.contains('エキス')) {
      cleaned = cleaned.replaceAll(RegExp(r'エキス(顆粒|細粒|散|錠)?'), '');
    }

    // 5. 剤形・規格・用量・塩類を後方から除去
    // 例: エペリゾン塩酸塩錠50mg -> エペリゾン
    // 例: ナラトリプタン錠2.5mg -> ナラトリプタン
    // 例: ロキソプロフェンNa錠60mg -> ロキソプロフェン
    // 例: ヒルドイドソフト軟膏0.3% -> ヒルドイド
    // 例: ミグシス錠5mg -> ミグシス
    cleaned = cleaned.replaceAll(
      RegExp(
        r'(塩酸塩|Na|ナトリウム|メシル酸塩|マレイン酸塩|酒石酸塩|水和物|硫酸塩|クエン酸塩|コハク酸塩|臭化水素酸塩|硝酸塩)?'
        r'(ソフト軟膏|油性クリーム|ドライシロップ|徐放錠|腸溶錠|OD錠|OD|錠剤|錠|カプセル|散|顆粒|細粒|シロップ|軟膏|クリーム|ローション|テープ|パップ|点眼液|点眼|吸入液|注)?'
        r'([0-9\.]+\s*(mg|g|mL|ml|%|μg|ug|単位|万単位))?'
        r'.*$',
        caseSensitive: false,
      ),
      '',
    );

    cleaned = cleaned.trim();
    if (cleaned.isEmpty) {
      cleaned = rawName.trim();
    }

    // 6. 辞書マッチング（完全一致または部分一致による代表名変換）
    for (var entry in _aliasDictionary.entries) {
      if (cleaned == entry.key || cleaned.contains(entry.key)) {
        return entry.value;
      }
    }

    return cleaned;
  }

  /// 2つの薬品名が同一のお薬であるかどうかを判定
  /// [existingPrescriptionMeds]: ユーザーのお薬手帳に登録されている処方薬名一覧（任意）
  static bool isSameMedication(String name1, String name2, [List<String>? existingPrescriptionMeds]) {
    final n1 = name1.trim();
    final n2 = name2.trim();
    if (n1.isEmpty || n2.isEmpty) return false;
    if (n1 == n2) return true;

    final norm1 = normalize(n1);
    final norm2 = normalize(n2);

    if (norm1.isNotEmpty && norm1 == norm2) return true;

    // 一方が他方を包含しており、主要な語幹が一致している場合
    // 例: "エペリゾン" vs "エペリゾン塩酸塩錠50mg「トーワ」"
    if (norm1.isNotEmpty && (n2.contains(norm1) || n1.contains(norm2))) {
      return true;
    }

    // 登録済み処方薬リストとの照合
    if (existingPrescriptionMeds != null) {
      for (var pName in existingPrescriptionMeds) {
        final pNorm = normalize(pName);
        if (pNorm.isNotEmpty) {
          final m1 = (norm1 == pNorm || n1.contains(pNorm) || pName.contains(norm1));
          final m2 = (norm2 == pNorm || n2.contains(pNorm) || pName.contains(norm2));
          if (m1 && m2) return true;
        }
      }
    }

    return false;
  }

  /// リストの中から指定された薬品名にマッチする既存の代表名を探す
  /// 見つからなければ新しく normalize した名前を返す
  static String resolveCanonicalName(String rawName, Iterable<String> existingNames) {
    for (var exist in existingNames) {
      if (isSameMedication(rawName, exist)) {
        return normalize(exist);
      }
    }
    return normalize(rawName);
  }

  /// 全角英数記号を半角に変換する内部ヘルパー
  static String _toHalfWidth(String input) {
    const full = '０１２３４５６７８９ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺａｂｃｄｅｆｇｈｉｊｋｌｍｎｏｐｑｒｓｔｕｖｗｘｙｚ（）［］｛｝％．，　';
    const half = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz()[]{}%., ';

    final sb = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final char = input[i];
      final idx = full.indexOf(char);
      if (idx != -1) {
        sb.write(half[idx]);
      } else {
        sb.write(char);
      }
    }
    return sb.toString();
  }
}
