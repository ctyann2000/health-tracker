# 🏥 HealthApp - Personal AI Health Tracker

**HealthApp** は、最新の Google Gemini AI を活用した、**完全個人専用・高機能ローカル完結型ヘルスケアアプリ** です。  
外部クラウド（Firebase等）を一切介さず、健康・服薬・トレーニングデータを端末内（ローカルストレージ）のみで安全に管理します。

🌐 **公開URL (GitHub Pages)**: [https://ctyann2000.github.io/health-tracker/](https://ctyann2000.github.io/health-tracker/)

---

## ✨ 主な特徴

### 1. 🤖 最新Gemini AIモデルへの自動追従（Flash-Lite Engine）
- **`gemini-flash-lite-latest`** を最優先に採用。Googleの最新Liteモデルへ自動追従し、高速・高精度・低負荷なデータ解析を実現。
- 万が一のレート制限時には `gemini-3.5-flash-lite` → `3.1` → `2.5` への多段フォールバックで安定稼働。
- アプリ内から Google API を直接叩き、利用可能なLiteモデル一覧をリアルタイム確認可能。

### 2. 💬 対話 ＆ 画像からのスマート健康記録
- **自然言語入力**: 「今日頭痛でロキソニンを朝8時に飲んだ。体重65.2kg、ベンチプレス50kg 10回3セット」と話しかけるだけで、体調スコア・お薬・体重・筋トレを自動抽出して記録。
- **処方箋・お薬手帳の画像解析**: 処方箋や薬袋の写真、お薬手帳のQRコード（JAHIS準拠）をアップロードするだけで、薬の名前や服用タイミングを自動認識。

### 3. 🛡️ 完全プライベート・ローカルストレージ設計
- GoogleログインやFirebase等の外部通信は一切排除。
- すべての健康データはお使いの端末（ブラウザのローカルストレージ / SharedPreferences）内にのみ保存。
- 設定画面から **JSON形式でのワンクリック・バックアップ（エクスポート）** および **復元（インポート）** が可能。

### 4. 💎 プレミアム・グラスモーフィズム UI
- 白基調の透明感あふれるすりガラス（BackdropFilter）デザイン。
- 美しいグラデーションと滑らかなアニメーション（`flutter_animate`）。
- **fl_chart** による体重推移グラフ、筋トレ総負荷量（Volume）チャート、部位別レーダーチャートを搭載。

---

## 📱 ご利用方法

1. ブラウザで [https://ctyann2000.github.io/health-tracker/](https://ctyann2000.github.io/health-tracker/) にアクセスします。
2. スマホのブラウザメニューから **「ホーム画面に追加」** を選択すると、通常のネイティブアプリ同様にフルスクリーンでご利用いただけます。
3. **「設定」タブ ＞「APIキー設定」** からご自身の Gemini API キーを登録することで、AI解析機能が有効になります。

---

## 🛠️ 技術スタック
- **Framework**: Flutter 3.x (Web / PWA)
- **Language**: Dart
- **AI / LLM**: Google Generative AI (Gemini 3.5 Flash-Lite / latest)
- **Charts**: `fl_chart`
- **State Management**: `provider`
- **Design**: Material 3 + Custom Glassmorphism UI
- **CI/CD**: GitHub Actions (`deploy.yml`) -> GitHub Pages
