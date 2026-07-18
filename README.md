# MeatCam (仮) — 色弱の方向け・肉の焼け具合可視化アプリ

カメラをかざすと、まだ生っぽい(赤みが強い)部分に斜線ハッチングを重ねて表示するiOSアプリです。
色そのものではなく「模様(斜線)」を主な合図にしているので、赤/緑の色弱の方でも判別しやすいようにしています。

このフォルダにはSwiftのソースファイルのみ入っています(`.xcodeproj`はXcode上で作る想定です)。
Windows環境ではiOSアプリのビルド・実機確認ができないため、以下の手順でMac上のXcodeにセットアップしてください。

## 1. Xcodeプロジェクトの作成

1. Xcodeを開き、**File > New > Project**
2. **iOS > App** を選択
3. 以下の設定で作成:
   - Product Name: `MeatCam` (お好きな名前でOK)
   - Interface: **SwiftUI**
   - Language: **Swift**
4. 作成されたプロジェクト内の `ContentView.swift` と、アプリ名の `〇〇App.swift`(例: `MeatCamApp.swift`)は**削除**してください(このリポジトリのファイルで置き換えます)。

## 2. ソースファイルの追加

`Sources/` フォルダ内の以下のファイルを、Xcodeのプロジェクトナビゲータにドラッグ&ドロップで追加してください(「Copy items if needed」にチェック)。

- `MeatCamApp.swift` — アプリのエントリポイント
- `ContentView.swift` — メイン画面(カメラ映像 + ハッチング重ね合わせ + 凡例)
- `CameraManager.swift` — カメラのキャプチャセッション管理、フレームを間引きながら解析器に渡す
- `DonenessAnalyzer.swift` — 「生っぽいか」の判定ロジック本体(後述)
- `CameraPreviewView.swift` — `AVCaptureVideoPreviewLayer`をSwiftUIに橋渡しするラッパー
- `RawRegionOverlayView.swift` — 斜線ハッチングの描画

## 3. カメラ権限の設定

Xcodeのプロジェクト設定 > 対象ターゲット > **Info** タブで、以下のキーを追加してください:

- Key: `Privacy - Camera Usage Description` (`NSCameraUsageDescription`)
- Value: `焼け具合を判定するためにカメラを使用します`

これが無いと、カメラへのアクセス要求時に即クラッシュします。

## 4. 実機で実行

**Simulatorにはカメラが無いため、実機(iPhone)での実行が必須です。**

1. iPhoneをMacにUSB接続 (もしくはWi-Fi経由のワイヤレスデバッグ設定)
2. Xcode上部のデバイス選択で自分のiPhoneを選ぶ
3. ビルド実行 (⌘R)
4. 初回起動時にカメラ権限を許可

Apple Developerアカウント(無料アカウントでも可)でのApple IDサインインがXcode側で必要です。

---

## 判定ロジックについて (今の実装 = ヒューリスティック)

`DonenessAnalyzer.swift` の `HeuristicDonenessAnalyzer` が実際の判定を行っています。仕組み:

1. カメラのフレームを 40×30 の粗いグリッドに縮小
2. 各セルの平均色をHSV(色相・彩度・明度)に変換
3. 赤〜赤紫の色相かつ、そこそこ以上の彩度・明度なら「生っぽい」と判定

これは学習済みAIモデルではなく、色相ベースのルールです。実際の肉・照明条件によっては
誤判定が出るはずなので、`hueRanges` / `minSaturation` / `minValue` / `maxValue` の値を
実機でテストしながら調整してください。

## 将来、本物のAIモデルに差し替えるには

判定ロジックは `DonenessAnalyzing` というprotocolの背後に隠してあるので、
`ContentView` や `CameraManager` を触らずに判定部分だけ差し替えられます。

1. **写真を集める**: 生の状態〜よく焼けた状態まで、いろいろな肉・角度・照明で
   数十〜数百枚撮影する
2. **Create ML(Macに標準で入っているアプリ)でセグメンテーションモデルを学習**:
   撮った写真に「生の部分」をマスクで塗って教師データを作り、Image Segmentation
   テンプレートで学習 → `.mlmodel` が書き出される
3. `.mlmodel` をXcodeプロジェクトに追加すると自動でSwiftの型が生成される
4. `DonenessAnalyzing` に準拠した `CoreMLDonenessAnalyzer` を新規作成し、
   `VNCoreMLRequest` でそのモデルを実行、出力マスクを `DonenessGrid` に変換する
5. `CameraManager.swift` の `private let analyzer: DonenessAnalyzing = HeuristicDonenessAnalyzer()`
   を `CoreMLDonenessAnalyzer()` に変更するだけで載せ替え完了

## 既知の制約・今後の調整ポイント

- ヒューリスティックの色閾値は未調整(実際の肉で試して合わせる必要あり)
- 生の霜降り(白い脂身)やソースの色によって誤検出する可能性あり
- 反射光・強い照明下でのハイライト(白飛び)は判定から除外しているが、調整余地あり
- 現状フロントカメラ切り替えUIは無し(背面カメラ固定)
