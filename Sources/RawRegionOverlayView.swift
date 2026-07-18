import SwiftUI
import CoreGraphics

/// 「まだ生っぽい」グリッドセルの上に斜線ハッチングを重ねて描画する。
/// 色弱の方でも判別できるよう、色だけに頼らずパターン(斜線)を主な合図にしている。
/// 薄いアンバー色の塗りも足しているが、これは補助的なもの。
///
/// グリッドをそのまま四角形として描くとセルの境界がガタガタになるため、
/// isRaw の判定結果を小さなアルファ画像(マスク)に変換し、それを高品質補間で
/// 画面サイズまで拡大している。こうすると隣り合うセルの判定値の間がなめらかに
/// 補間され、実際の色の境界により近い滑らかな輪郭になる。
struct RawRegionOverlayView: View {
    let grid: DonenessGrid

    var body: some View {
        GeometryReader { geo in
            if let maskImage = Self.makeMaskImage(grid: grid) {
                let mask = Image(decorative: maskImage, scale: 1)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: geo.size.width, height: geo.size.height)

                ZStack {
                    Rectangle()
                        .fill(Color.orange.opacity(0.35))
                        .mask(mask)

                    HatchPatternView()
                        .mask(mask)
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// isRaw グリッドを、アルファチャンネルのみの小さな画像に変換する。
    /// (isRaw=true のセル → 不透明 = 表示、false → 透明 = 非表示)
    private static func makeMaskImage(grid: DonenessGrid) -> CGImage? {
        guard grid.columns > 0, grid.rows > 0, grid.isRaw.contains(true) else { return nil }

        // アルファ専用(色情報なし)フォーマットはCGColorSpaceとの組み合わせが無効になり
        // CGImage生成が失敗しやすいため、色はダミーの白・アルファだけ使うRGBA画像にする。
        var pixels = [UInt8](repeating: 0, count: grid.columns * grid.rows * 4)
        for i in 0..<(grid.columns * grid.rows) where grid.isRaw[i] {
            let offset = i * 4
            pixels[offset] = 255
            pixels[offset + 1] = 255
            pixels[offset + 2] = 255
            pixels[offset + 3] = 255
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(
            width: grid.columns,
            height: grid.rows,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: grid.columns * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }
}

private struct HatchPatternView: View {
    private let hatchSpacing: CGFloat = 7
    private let hatchLineWidth: CGFloat = 1.6

    var body: some View {
        Canvas { context, size in
            var hatchPath = Path()
            let diagonalCount = Int((size.width + size.height) / hatchSpacing) + 1
            for i in 0..<diagonalCount {
                let offset = CGFloat(i) * hatchSpacing
                hatchPath.move(to: CGPoint(x: offset, y: 0))
                hatchPath.addLine(to: CGPoint(x: offset - size.height, y: size.height))
            }
            context.stroke(hatchPath, with: .color(.white.opacity(0.9)), lineWidth: hatchLineWidth)
        }
    }
}
