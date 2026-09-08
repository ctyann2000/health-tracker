class WorkoutAnalyzer {
  // 部位の列挙
  static const String chest = '胸';
  static const String back = '背中';
  static const String legs = '脚';
  static const String shoulders = '肩';
  static const String arms = '腕';
  static const String core = '腹・体幹';

  // キーワードから部位を判定する簡易辞書
  static final Map<String, String> _muscleKeywords = {
    // 胸
    'ベンチプレス': chest,
    'ダンベルフライ': chest,
    'チェストプレス': chest,
    'プッシュアップ': chest,
    '腕立て': chest,
    'ペックフライ': chest,
    'ディップス': chest,
    
    // 背中
    'デッドリフト': back,
    'ラットプルダウン': back,
    'チンニング': back,
    '懸垂': back,
    'ローイング': back,
    'ベントオーバーロー': back,
    
    // 脚
    'スクワット': legs,
    'レッグプレス': legs,
    'レッグエクステンション': legs,
    'レッグカール': legs,
    'ランジ': legs,
    'カーフレイズ': legs,
    
    // 肩
    'ショルダープレス': shoulders,
    'サイドレイズ': shoulders,
    'フロントレイズ': shoulders,
    'リアレイズ': shoulders,
    'ミリタリープレス': shoulders,
    
    // 腕
    'アームカール': arms,
    'ダンベルカール': arms,
    'ハンマーカール': arms,
    'トライセプス': arms,
    'フレンチプレス': arms,
    
    // 腹・体幹
    'クランチ': core,
    'プランク': core,
    'シットアップ': core,
    '腹筋': core,
    'アブローラー': core,
  };

  /// 種目名からメインの部位を判定する
  static String getMuscleGroup(String workoutName) {
    // スペースや記号を無視して比較しやすくする
    final normalizedName = workoutName.replaceAll(' ', '').replaceAll('　', '').toLowerCase();
    
    for (var entry in _muscleKeywords.entries) {
      if (normalizedName.contains(entry.key)) {
        return entry.value;
      }
    }
    
    // マッチしない場合は「その他/全身」扱いとして体幹または適当な部位に割り当てるか、
    // バランスよく表示するためにデフォルトを返す
    return 'その他';
  }
}
