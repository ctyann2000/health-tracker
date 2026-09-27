import 'health_record.dart';

/// 種目の過去履歴データポイント（推移グラフ・個人記録用）
class ExerciseHistoryPoint {
  final DateTime date;
  final double maxWeight;
  final double best1RM;
  final double bestSetVolume;
  final List<WorkoutSet> sets;

  ExerciseHistoryPoint({
    required this.date,
    required this.maxWeight,
    required this.best1RM,
    required this.bestSetVolume,
    required this.sets,
  });
}

/// トレーニング種目の定義およびマスターデータ
class WorkoutExerciseDefinition {
  final String id;
  final String name;
  final String category; // 'マシン', 'ダンベル', 'バーベル', '自重', 'ケーブル'
  final String primaryMuscle; // '肩', '胸', '背中', '脚', '腕', '腹・体幹'
  final String secondaryMuscle; // '上腕三頭筋', '上腕二頭筋', '大臀筋', '前腕', '僧帽筋' など
  final int defaultRestSeconds; // デフォルトインターバル（秒）
  final String instructions; // フォームのやり方・ステップ解説
  final List<String> tips; // コツ・意識するポイント

  const WorkoutExerciseDefinition({
    required this.id,
    required this.name,
    required this.category,
    required this.primaryMuscle,
    required this.secondaryMuscle,
    this.defaultRestSeconds = 120, // 基本2分
    required this.instructions,
    this.tips = const [],
  });

  /// プリセット種目マスターデータベース
  static const List<WorkoutExerciseDefinition> defaultExercises = [
    // --- 肩 (Shoulders) ---
    WorkoutExerciseDefinition(
      id: 'seated_shoulder_press_machine',
      name: 'シーテッドショルダープレス (マシン)',
      category: 'マシン',
      primaryMuscle: '肩',
      secondaryMuscle: '上腕三頭筋',
      defaultRestSeconds: 120,
      instructions:
          '1. シートの高さを調節し、グリップが耳または肩の高さに来るように座ります。\n'
          '2. 胸を張り、背中を背もたれに密着させてグリップをしっかりと握ります。\n'
          '3. 息を吐きながら、肘を伸ばしきる直前まで頭上へ押し上げます。\n'
          '4. 息を吸いながら、負荷を感じつつゆっくりと元の位置へ降ろします。',
      tips: [
        '肩甲骨を寄せすぎず、自然な軌道で上下させましょう。',
        '顎が上がらないよう軽く引き、体幹に力を入れます。',
        'トップで肘をロック（伸ばし切り）せず、筋肉の緊張を保ちます。',
      ],
    ),
    WorkoutExerciseDefinition(
      id: 'dumbbell_shoulder_press',
      name: 'ダンベルショルダープレス',
      category: 'ダンベル',
      primaryMuscle: '肩',
      secondaryMuscle: '上腕三頭筋',
      defaultRestSeconds: 120,
      instructions:
          '1. ベンチに座り、ダンベルを肩の高さで保持します（手のひらは正面）。\n'
          '2. 息を吐きながら、弧を描くようにダンベルを頭上へ押し上げます。\n'
          '3. 頂点で一瞬静止し、コントロールしながらゆっくり下ろします。',
      tips: ['腰を反らしすぎないよう腹筋を意識します。', 'ダンベル同士をぶつけないように制御します。'],
    ),
    WorkoutExerciseDefinition(
      id: 'side_lateral_raise',
      name: 'サイドレイズ (ダンベル)',
      category: 'ダンベル',
      primaryMuscle: '肩',
      secondaryMuscle: '僧帽筋',
      defaultRestSeconds: 90,
      instructions:
          '1. 両手にダンベルを持ち、軽く前傾姿勢をとります。\n'
          '2. 肘を軽く曲げたまま、小指側を少し上に向けながら真横に持ち上げます。\n'
          '3. 肩の高さまで上げたら、重力に逆らうようにゆっくり降ろします。',
      tips: ['反動を使わずに三角筋中部で持ち上げる意識を持ちます。', '肩をすくめないよう注意します。'],
    ),

    // --- 胸 (Chest) ---
    WorkoutExerciseDefinition(
      id: 'chest_press_machine',
      name: 'チェストプレス (マシン)',
      category: 'マシン',
      primaryMuscle: '胸',
      secondaryMuscle: '上腕三頭筋',
      defaultRestSeconds: 120,
      instructions:
          '1. バーが胸のトップ（乳頭の高さ）に来るようにシート高さを調節します。\n'
          '2. 肩甲骨を寄せて胸を張り、しっかりとバーを握ります。\n'
          '3. 息を吐きながら胸の力で押し出し、吸いながらゆっくり戻します。',
      tips: [
        '肩が前に出ないよう、胸を常に張った状態をキープします。',
        '戻すときにウェイトが着地する手前で切り返します。',
      ],
    ),
    WorkoutExerciseDefinition(
      id: 'barbell_bench_press',
      name: 'ベンチプレス (バーベル)',
      category: 'バーベル',
      primaryMuscle: '胸',
      secondaryMuscle: '上腕三頭筋',
      defaultRestSeconds: 150,
      instructions:
          '1. ベンチに仰向けになり、肩幅より少し広めの手幅でバーを握ります。\n'
          '2. アーチ（胸椎の伸展）を作り、肩甲骨を寄せ下げます。\n'
          '3. 胸の中央へ向けてコントロールしながらバーを下ろし、力強く押し上げます。',
      tips: ['足の裏全体を床につけて下半身から力を伝達します。', '手首が過度に反らないよう握り込みます。'],
    ),
    WorkoutExerciseDefinition(
      id: 'pec_deck_fly',
      name: 'ペックフライ (マシン)',
      category: 'マシン',
      primaryMuscle: '胸',
      secondaryMuscle: '肩 (前部)',
      defaultRestSeconds: 90,
      instructions:
          '1. パッドが胸の高さになるようにシートを調節します。\n'
          '2. 肘を軽く曲げてキープし、大きな樽を抱きしめるように腕を閉じます。\n'
          '3. 最大収縮を感じたら、胸のストレッチを感じながらゆっくり開きます。',
      tips: ['大胸筋の収縮とストレッチを強く意識しましょう。'],
    ),

    // --- 背中 (Back) ---
    WorkoutExerciseDefinition(
      id: 'lat_pulldown_cable',
      name: 'ラットプルダウン (ケーブル)',
      category: 'ケーブル',
      primaryMuscle: '背中',
      secondaryMuscle: '上腕二頭筋',
      defaultRestSeconds: 120,
      instructions:
          '1. 太ももがパッドにしっかり固定されるようシートを調整します。\n'
          '2. 肩幅より広めにバーを握り、胸を斜め上に向けて張ります。\n'
          '3. 肘を腰に引きつけるイメージで、鎖骨付近までバーを引き下ろします。\n'
          '4. 広背筋の伸びを感じながら、ゆっくりとコントロールしてバーを戻します。',
      tips: [
        '腕の力ではなく、肩甲骨を下げる（下制）動きから引き始めます。',
        '体を後ろに倒しすぎないようにします。',
      ],
    ),
    WorkoutExerciseDefinition(
      id: 'seated_cable_row',
      name: 'シーテッドローイング (マシン/ケーブル)',
      category: 'マシン',
      primaryMuscle: '背中',
      secondaryMuscle: '上腕二頭筋',
      defaultRestSeconds: 120,
      instructions:
          '1. 足をプレートに置き、膝を軽く曲げて座ります。\n'
          '2. 背筋を伸ばしたままハンドルをおへそに向かって引きます。\n'
          '3. 引ききったところで肩甲骨をギュッと寄せ、背中の収縮を意識します。',
      tips: ['背中を丸めないよう骨盤を立てて動作します。'],
    ),
    WorkoutExerciseDefinition(
      id: 'barbell_deadlift',
      name: 'デッドリフト (バーベル)',
      category: 'バーベル',
      primaryMuscle: '背中',
      secondaryMuscle: 'ハムストリングス',
      defaultRestSeconds: 180,
      instructions:
          '1. バーベルの真上に土踏まずが来るように立ち、腰幅程度に足を開きます。\n'
          '2. 股関節を引いて前傾し、肩幅でバーを握ります。\n'
          '3. 背筋を真っ直ぐ保ち、床を蹴るように一気に立ち上がります。',
      tips: ['腰を絶対に丸めないこと。腹圧をしっかりかけて体幹を固めます。'],
    ),

    // --- 脚 (Legs) ---
    WorkoutExerciseDefinition(
      id: 'leg_press_machine',
      name: 'レッグプレス (マシン)',
      category: 'マシン',
      primaryMuscle: '脚',
      secondaryMuscle: '大臀筋',
      defaultRestSeconds: 150,
      instructions:
          '1. シートに深く腰掛け、骨盤を密着させてフットプレートに足を置きます。\n'
          '2. セーフティを解除し、膝が直角になる程度までゆっくりプレートを降ろします。\n'
          '3. かかとを中心に力を入れ、膝を伸ばしきる直前まで押し戻します。',
      tips: ['膝が内側に入らないよう、つま先と同じ方向を向けます。', '腰がシートから浮かないようグリップを握り締めます。'],
    ),
    WorkoutExerciseDefinition(
      id: 'barbell_squat',
      name: 'スクワット (バーベル)',
      category: 'バーベル',
      primaryMuscle: '脚',
      secondaryMuscle: '体幹',
      defaultRestSeconds: 180,
      instructions:
          '1. 僧帽筋の上部にバーを担ぎ、胸を張ってラックから外します。\n'
          '2. 股関節から折り曲げるように腰を後ろに引きつつ沈み込みます。\n'
          '3. 太ももが床と平行になるまで下がったら、力強く立ち上がります。',
      tips: ['重心はかかと寄り、膝がつま先より前に出すぎないようにします。'],
    ),
    WorkoutExerciseDefinition(
      id: 'leg_extension_machine',
      name: 'レッグエクステンション (マシン)',
      category: 'マシン',
      primaryMuscle: '脚',
      secondaryMuscle: '大腿四頭筋',
      defaultRestSeconds: 90,
      instructions:
          '1. 膝の関節とマシンの回転軸を合わせ、足首の前にパッドが来るよう調整します。\n'
          '2. 息を吐きながら膝を伸ばし、大腿四頭筋を強く収縮させます。\n'
          '3. トップで1秒キープし、ゆっくり負荷に耐えながら戻します。',
      tips: ['反動を使わず、太ももの前の筋肉の張りを意識します。'],
    ),
    WorkoutExerciseDefinition(
      id: 'leg_curl_machine',
      name: 'レッグカール (マシン)',
      category: 'マシン',
      primaryMuscle: '脚',
      secondaryMuscle: 'ハムストリングス',
      defaultRestSeconds: 90,
      instructions:
          '1. うつ伏せまたは座位で、アキレス腱の少し上にパッドをセットします。\n'
          '2. かかとをお尻に引き寄せるように膝を曲げます。\n'
          '3. もも裏の収縮を感じてから、ゆっくりと戻します。',
      tips: ['お尻が浮かないようにしっかりグリップを持ちます。'],
    ),

    // --- 腕 (Arms) ---
    WorkoutExerciseDefinition(
      id: 'dumbbell_bicep_curl',
      name: 'ダンベルアームカール',
      category: 'ダンベル',
      primaryMuscle: '腕',
      secondaryMuscle: '前腕',
      defaultRestSeconds: 90,
      instructions:
          '1. 両手にダンベルを持ち、背筋を伸ばして立ちます。\n'
          '2. 肘の位置を固定し、力こぶ（上腕二頭筋）を意識してダンベルを巻き上げます。\n'
          '3. 頂点で収縮させ、ゆっくり下ろします。',
      tips: ['肘が前後にブレないよう体側に固定します。'],
    ),
    WorkoutExerciseDefinition(
      id: 'cable_triceps_pushdown',
      name: 'トライセプスプッシュダウン (ケーブル)',
      category: 'ケーブル',
      primaryMuscle: '腕',
      secondaryMuscle: '上腕三頭筋',
      defaultRestSeconds: 90,
      instructions:
          '1. ロープまたはバーを握り、肘を体側に固定します。\n'
          '2. 肘から先だけを動かし、下に向かって押し下げます。\n'
          '3. 二の腕裏の収縮を感じたら、肘の位置を変えずにゆっくり戻します。',
      tips: ['肩をすくめず、二の腕の裏側（三頭筋）に負荷を集中させます。'],
    ),

    // --- 腹・体幹 (Core) ---
    WorkoutExerciseDefinition(
      id: 'ab_crunch_machine',
      name: 'アブドミナルクランチ (マシン)',
      category: 'マシン',
      primaryMuscle: '腹・体幹',
      secondaryMuscle: '腹直筋',
      defaultRestSeconds: 90,
      instructions:
          '1. シートに座り、足とハンドルを固定します。\n'
          '2. 息を吐きながら背中を丸め、おへそを覗き込むように体を曲げます。\n'
          '3. 腹筋の力で元に戻します。',
      tips: ['腰から折るのではなく、みぞおちから丸める意識が重要です。'],
    ),
    WorkoutExerciseDefinition(
      id: 'plank_core',
      name: 'プランク (自重)',
      category: '自重',
      primaryMuscle: '腹・体幹',
      secondaryMuscle: '全身',
      defaultRestSeconds: 60,
      instructions:
          '1. うつ伏せから両肘とつま先で体を支えます。\n'
          '2. 頭からかかとまでが一直線になる姿勢をキープします。\n'
          '3. 呼吸を止めずに姿勢を維持します。',
      tips: ['腰が反ったり、お尻が高く上がらないように注意します。'],
    ),
  ];

  /// 名前から定義を検索する（部分一致対応）
  static WorkoutExerciseDefinition? findByName(String name) {
    final clean = name.replaceAll(' ', '').replaceAll('　', '').toLowerCase();
    for (var ex in defaultExercises) {
      final exClean = ex.name.replaceAll(' ', '').replaceAll('　', '').toLowerCase();
      if (clean.contains(exClean) || exClean.contains(clean)) {
        return ex;
      }
    }
    return null;
  }
}
