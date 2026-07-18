# 引き継ぎメモ (Windows → Mac)

このプロジェクトはWindows環境上のClaude Codeで、**Xcodeも実機カメラも無い状態**で
ソースコードだけを書いた状態です。一度もビルド・実行されていません。
この文書は、Mac上のClaude Codeが最初に読む前提の引き継ぎメモです。

## プロジェクトの目的

色弱の方向けに、肉を焼いているときカメラをかざすと「まだ生っぽい部分」に
斜線ハッチングを重ねて可視化するiOSアプリ。色だけでなく模様(斜線)を主な
合図にしているのがポイント。

## 今の実装状況

- SwiftUI + AVFoundationのアプリ本体一式は `Sources/` にある(6ファイル)
- 判定ロジックは `DonenessAnalyzing` というprotocol越しに呼ばれる設計。
  今入っているのは `HeuristicDonenessAnalyzer`(色相ベースのルール判定)のみで、
  学習済みAIモデルではない
- 詳細な設計意図・各ファイルの役割は `README.md` に記載済み

## 今すぐMacでやるべきこと(優先順)

1. **Xcodeプロジェクトの作成とビルド確認**
   - README.md の「1. Xcodeプロジェクトの作成」〜「4. 実機で実行」の手順通りに進める
   - 一度もコンパイルされていないコードなので、**最初のビルドでエラーが出る前提で挑む**こと。
     特に以下は要注意箇所:
     - `DonenessAnalyzer.swift` の `CIContext(options: [.workingColorSpace: NSNull()])` —
       `CIContextOption` の型推論がうまくいかない場合は明示的にキャストが必要かも
     - `CIContext.render(_:toBitmap:rowBytes:bounds:format:colorSpace:)` の引数名・型が
       Xcodeのバージョンによって微妙に違う可能性がある
     - `ContentView.swift` の `#Preview { }` マクロは比較的新しいXcode(15+)が前提
     - `Canvas` (RawRegionOverlayView.swift) は iOS 15+ が前提。プロジェクトのDeployment
       Targetがそれより低いと使えない
   - **Simulatorにはカメラが無いので、実機(iPhone)接続が必須**。Apple ID(無料でOK)での
     Xcodeサインインが必要

2. **色相しきい値のチューニング**
   - `HeuristicDonenessAnalyzer` 内の `hueRanges` / `minSaturation` / `minValue` / `maxValue`
     は完全に未検証の当てずっぽうの値
   - 実際に肉を焼きながらカメラをかざし、生の部分にちゃんとハッチングが乗るか、
     逆に焼けた部分やお皿・コンロなど無関係なものを誤検出していないかを見て、
     値を調整する
   - グリッド解像度(`CameraManager.gridColumns/gridRows` = 40×30)やフレーム間引き
     (`analyzeEveryNFrames` = 3)も、実機での発熱・fps・検出の粗さを見ながら調整が必要

3. **(将来やること・今回は未着手)AIモデルへの差し替え**
   - README.md の「将来、本物のAIモデルに差し替えるには」セクションに手順あり
   - 生〜焼けた肉の写真を集める → Create MLでセグメンテーションモデルを学習 →
     `DonenessAnalyzing` に準拠した `CoreMLDonenessAnalyzer` を新規実装 →
     `CameraManager.swift` の `analyzer` の初期化を差し替えるだけでOKな設計にしてある

## 追記 (Mac上のClaude Code → Xcode内のClaude への引き継ぎ)

Mac上のClaude Code(ターミナル側)がここまで進めた:

- `xcodegen`(コマンドラインツール)で `MeatCam.xcodeproj` を自動生成済み。
  `project.yml` がその設定ファイル。`Sources/` の6ファイルは登録済み、
  カメラ権限の説明文もビルド設定経由で設定済み(`NSCameraUsageDescription`)。
- ビルドで実際に1件エラーが出た: `CameraManager.swift` の
  `@Published var grid: DonenessGrid = .empty(columns: Self.gridColumns, ...)` で
  「covariant 'Self' type cannot be referenced from a stored property initializer」。
  `Self.gridColumns` → `CameraManager.gridColumns` に修正済み。
- Simulator向け・実機アーキテクチャ向け(未署名)の両方で `xcodebuild` によるビルドは
  **成功**を確認済み。コード自体はこれ以上のエラーは無いはず。
- **未着手・Xcode側のClaudeにお願いしたいこと**:
  1. Signing & Capabilities で Team(Apple ID)を設定
  2. 実機(iPhone)を接続してビルド・実行(⌘R)
  3. 実機で肉を焼いてカメラをかざし、`DonenessAnalyzer.swift` の
     `hueRanges` / `minSaturation` / `minValue` / `maxValue`、および
     `CameraManager.swift` の `gridColumns`/`gridRows`/`analyzeEveryNFrames` を
     実際の見え方に合わせて調整
  4. `project.yml` / `MeatCam.xcodeproj` / 修正済み `CameraManager.swift` はまだ
     git未コミットの状態。区切りの良いところでコミットしてほしい

## 元の会話で決まっていたこと(前提として引き継いでほしい)

- 判定方式は「AIモデルで」という要望だったが、学習データが無いため今回は
  色相ヒューリスティックを暫定実装とし、後で本物のモデルに差し替えられる設計にした
- ハイライトの見せ方は「斜線パターンで囲む」を選択(色だけに頼らないため)。
  補助的に薄いオレンジの塗りも足しているが、主な合図はあくまで斜線
- 対応OSはiOS、Androidは対象外
