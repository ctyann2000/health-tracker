/// 薬品名から一般的な効能・効果（お薬の効用）を自動判定・補完するヘルパー
class MedicationEfficacyHelper {
  /// 薬品名から推定される一般的な効能・効果を取得
  static String getEfficacy(String medName, [String? currentEfficacy]) {
    if (currentEfficacy != null && currentEfficacy.trim().isNotEmpty) {
      return currentEfficacy.trim();
    }
    final name = medName.toLowerCase();

    // --- 頭痛・片頭痛治療薬 ---
    if (name.contains('ナラトリプタン') || name.contains('アマージ')) {
      return '片頭痛発作の治療（頭痛や吐き気などの痛みを鎮める）';
    }
    if (name.contains('エレトリプタン') || name.contains('レルパックス')) {
      return '片頭痛発作の治療（頭痛発作を速やかに緩和する）';
    }
    if (name.contains('ゾルミトリプタン') || name.contains('ゾーミッグ')) {
      return '片頭痛発作の治療（頭痛および吐き気などの随伴症状を改善）';
    }
    if (name.contains('スマトリプタン') || name.contains('イミグラン')) {
      return '片頭痛・群発頭痛発作の治療（急性の激しい頭痛を鎮める）';
    }
    if (name.contains('リザトリプタン') || name.contains('マクサルト')) {
      return '片頭痛発作の速効治療（片頭痛の痛みを速やかに抑える）';
    }
    if (name.contains('ミグシス') || name.contains('ロメリジン')) {
      return '片頭痛の予防（脳血管の過度な収縮・拡張を抑えて発作を予防する）';
    }
    if (name.contains('レイボー') || name.contains('ラスミジタン')) {
      return '片頭痛発作の治療（痛みの伝達を抑えて頭痛を改善）';
    }

    // --- 筋弛緩・こり・緊張 ---
    if (name.contains('エペリゾン') || name.contains('ミオナール')) {
      return '筋肉のこり・緊張を緩和（首・肩のこりや腰痛、筋緊張性頭痛を和らげる）';
    }
    if (name.contains('チザニジン') || name.contains('テルネリン')) {
      return '筋肉のつっぱりやつり、こわばりをほぐす（中枢性筋弛緩薬）';
    }
    if (name.contains('クロルフェネシン') || name.contains('リンラキサー')) {
      return '腰背痛や肩関節周囲炎による筋肉の痛みを和らげる';
    }

    // --- 鎮痛・消炎・解熱 ---
    if (name.contains('ロキソプロフェン') || name.contains('ロキソニン')) {
      return '痛み・炎症・発熱を速やかに抑える（解熱鎮痛消炎薬）';
    }
    if (name.contains('アセトアミノフェン') || name.contains('カロナール')) {
      return '熱を下げ、頭痛や痛みを穏やかに和らげる（胃に優しい解熱鎮痛薬）';
    }
    if (name.contains('セレコキシブ') || name.contains('セレコックス')) {
      return '関節や腰、痛風などの痛み・炎症を抑える（胃腸障害が少ない消炎鎮痛薬）';
    }
    if (name.contains('イブプロフェン') || name.contains('ブルフェン')) {
      return '痛みや炎症、発熱を抑える（非ステロイド性消炎鎮痛薬）';
    }
    if (name.contains('ジクロフェナク') || name.contains('ボルタレン')) {
      return '強い痛みや炎症、腫れを強力に鎮める（消炎鎮痛薬）';
    }
    if (name.contains('トラマドール') || name.contains('トラムセット') || name.contains('トアラセット')) {
      return '強い慢性疼痛や通常の鎮痛薬で効かない痛みを抑える';
    }

    // --- 胃腸・消化器保護 ---
    if (name.contains('レバミピド') || name.contains('ムコスタ')) {
      return '胃粘膜を保護・修復する（胃炎・胃潰瘍、鎮痛薬による胃荒れ防止）';
    }
    if (name.contains('テプレノン') || name.contains('セルベックス')) {
      return '胃の粘液を増やして胃粘膜を守る';
    }
    if (name.contains('ファモチジン') || name.contains('ガスター')) {
      return '胃酸の分泌を抑える（胃痛・胸やけ・胃潰瘍・逆流性食道炎）';
    }
    if (name.contains('ランソプラゾール') ||
        name.contains('タケプロン') ||
        name.contains('オメプラゾール') ||
        name.contains('エソメプラゾール') ||
        name.contains('ネキシウム') ||
        name.contains('ボノプラザン') ||
        name.contains('タケキャブ')) {
      return '胃酸の分泌を強力に抑制する（逆流性食道炎・胃潰瘍の治療）';
    }
    if (name.contains('ビオフェルミン') ||
        name.contains('ミヤbm') ||
        name.contains('ビオスリー') ||
        name.contains('ラックビー')) {
      return '腸内環境を整え、お腹の調子を整える（整腸剤）';
    }

    // --- 循環器・血圧・心臓 ---
    if (name.contains('アムロジピン') || name.contains('ノルバスク') || name.contains('アムロジン')) {
      return '血圧を下げる（血管を広げて心臓への負担を減らす）';
    }
    if (name.contains('カンデサルタン') ||
        name.contains('ブロプレス') ||
        name.contains('テルミサルタン') ||
        name.contains('ミカルディス') ||
        name.contains('オルメサルタン') ||
        name.contains('オルメテック') ||
        name.contains('バルサルタン') ||
        name.contains('ディオバン')) {
      return '血圧を安定して下げる（血管を収縮させる物質を抑える降圧薬）';
    }
    if (name.contains('ビソプロロール') || name.contains('メインテート')) {
      return '脈拍を安定させ、血圧を下げる（頻脈・不整脈・高血圧）';
    }

    // --- 代謝・脂質・コレステロール ---
    if (name.contains('アトルバスタチン') ||
        name.contains('リピトール') ||
        name.contains('ロスバスタチン') ||
        name.contains('クレストール') ||
        name.contains('ピタバスタチン') ||
        name.contains('リバロ')) {
      return '悪玉（LDL）コレステロールを下げる（脂質異常症・動脈硬化の改善）';
    }
    if (name.contains('メトホルミン') || name.contains('メトグルコ')) {
      return '血糖値を下げる（インスリンの効き目を改善する糖尿病薬）';
    }

    // --- アレルギー・抗ヒスタミン ---
    if (name.contains('フェキソフェナジン') ||
        name.contains('アレグラ') ||
        name.contains('セチリジン') ||
        name.contains('ジルテック') ||
        name.contains('レボセチリジン') ||
        name.contains('ザイザル') ||
        name.contains('ロラタジン') ||
        name.contains('クラリチン') ||
        name.contains('ビラノア') ||
        name.contains('デザレックス') ||
        name.contains('ルパフィン')) {
      return 'くしゃみ・鼻水・目のかゆみ・湿疹を抑える（抗アレルギー薬）';
    }

    // --- 外用薬・保湿・皮膚 ---
    if (name.contains('ヘパリン類似物質') || name.contains('ヒルドイド')) {
      return '皮膚の水分保持・血行促進（乾燥肌の改善・保湿ケア）';
    }
    if (name.contains('ワセリン') || name.contains('プロペト')) {
      return '皮膚の表面を保護し、水分の蒸発を防ぐ';
    }

    // --- 漢方薬 ---
    if (name.contains('川芎茶調散') || name.contains('せんきゅうちゃちょうさん')) {
      return '頭痛・感冒などの痛みを和らげる（頭痛に効果的な漢方薬）';
    }
    if (name.contains('五苓散') || name.contains('ごれいさん')) {
      return '体内の水分循環を整え、気圧頭痛・むくみ・めまいを改善';
    }
    if (name.contains('葛根湯') || name.contains('かっこんとう')) {
      return '体を温めて発汗を促し、風邪初期の悪寒や首肩のこりを緩和';
    }
    if (name.contains('釣藤散') || name.contains('ちょうとうさん')) {
      return '高血圧傾向や慢性の頭痛・めまい・肩こりを鎮める';
    }
    if (name.contains('呉茱萸湯') || name.contains('ごしゅゆとう')) {
      return '冷えを伴う激しい片頭痛や吐き気を改善する';
    }
    if (name.contains('抑肝散') || name.contains('よくかんさん')) {
      return '神経の高ぶりやイライラ、不眠、筋肉の緊張を和らげる';
    }

    return '';
  }
}
