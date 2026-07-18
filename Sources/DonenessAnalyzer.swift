import CoreImage
import CoreVideo
import Foundation

/// カメラの1フレームを解析し、「まだ生っぽい」領域を粗いグリッドで返す。
/// 実装を差し替えられるよう protocol にしてある。今は色相ベースの
/// ヒューリスティック実装 (HeuristicDonenessAnalyzer) のみ提供しているが、
/// 将来 Create ML/Core ML で学習したモデルを使う実装 (例: CoreMLDonenessAnalyzer)
/// を同じ protocol で作れば、ContentView 側は変更なしに差し替えられる。
protocol DonenessAnalyzing {
    /// - Returns: フレーム全体を `columns` x `rows` のグリッドに区切り、
    ///   各セルが「生っぽい」かどうかを示す DonenessGrid。
    func analyze(pixelBuffer: CVPixelBuffer, columns: Int, rows: Int) -> DonenessGrid
}

/// 解析結果のグリッド。isRaw[row * columns + col] で各セルの判定を持つ。
struct DonenessGrid {
    let columns: Int
    let rows: Int
    let isRaw: [Bool]

    static func empty(columns: Int, rows: Int) -> DonenessGrid {
        DonenessGrid(columns: columns, rows: rows, isRaw: Array(repeating: false, count: columns * rows))
    }
}

/// 色相(Hue)・彩度(Saturation)・明度(Value)から「生の赤み」を判定する
/// ヒューリスティック実装。学習済みモデルを使わない代わりに、すぐ動く。
///
/// 目安:
///   - 生っぽい赤身: 赤〜赤紫のHue、そこそこ以上のSaturation
///   - 焼けた面: 茶色〜灰色でSaturationが低め、または暗め
///
/// 実際の食材・照明条件でズレが出やすい部分なので、`hueRangeDegrees` /
/// `minSaturation` / `minValue` は実機でテストしながら調整してほしい。
final class HeuristicDonenessAnalyzer: DonenessAnalyzing {
    /// 「生」とみなす色相の範囲(度)。0/360 付近の赤をまたぐので2区間で表現。
    // 肌色はHue 20-40°(オレンジ寄り)に出やすいため、そこを避けて純粋な赤寄りに絞る。
    private let hueRanges: [ClosedRange<CGFloat>] = [0...15, 345...360]
    // 肌色は彩度が低め(~0.3-0.4)になりやすいので、境界で誤検出しないよう高めに設定。
    private let minSaturation: CGFloat = 0.45
    // 暗い(明度が低い)ピクセルはRGB間のわずかなノイズでも彩度が異常に高く
    // 算出されやすく、影や暗い被写体を誤検出する原因になる。閾値を上げて除外する。
    private let minValue: CGFloat = 0.30
    private let maxValue: CGFloat = 0.97 // 反射でほぼ白飛びしている部分は判定から除外

    private let ciContext = CIContext(options: [CIContextOption.workingColorSpace: NSNull()])
    private let colorSpace = CGColorSpaceCreateDeviceRGB()

    func analyze(pixelBuffer: CVPixelBuffer, columns: Int, rows: Int) -> DonenessGrid {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let extent = ciImage.extent
        guard extent.width > 0, extent.height > 0 else {
            return .empty(columns: columns, rows: rows)
        }

        // columns x rows の小さなバッファに縮小してから解析することで、
        // フル解像度を毎フレーム舐めるコストを避ける。
        let scaleX = CGFloat(columns) / extent.width
        let scaleY = CGFloat(rows) / extent.height
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        var buffer = [UInt8](repeating: 0, count: columns * rows * 4)
        let bounds = CGRect(x: 0, y: 0, width: columns, height: rows)

        buffer.withUnsafeMutableBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return }
            ciContext.render(
                scaled,
                toBitmap: baseAddress,
                rowBytes: columns * 4,
                bounds: bounds,
                format: .RGBA8,
                colorSpace: colorSpace
            )
        }

        var isRaw = [Bool](repeating: false, count: columns * rows)
        for row in 0..<rows {
            for col in 0..<columns {
                let i = (row * columns + col) * 4
                let r = CGFloat(buffer[i]) / 255.0
                let g = CGFloat(buffer[i + 1]) / 255.0
                let b = CGFloat(buffer[i + 2]) / 255.0
                let (h, s, v) = Self.rgbToHSV(r: r, g: g, b: b)
                isRaw[row * columns + col] = Self.isRawColor(
                    h: h, s: s, v: v,
                    hueRanges: hueRanges, minSaturation: minSaturation,
                    minValue: minValue, maxValue: maxValue
                )
            }
        }

        return DonenessGrid(columns: columns, rows: rows, isRaw: isRaw)
    }

    private static func isRawColor(
        h: CGFloat, s: CGFloat, v: CGFloat,
        hueRanges: [ClosedRange<CGFloat>], minSaturation: CGFloat,
        minValue: CGFloat, maxValue: CGFloat
    ) -> Bool {
        guard s >= minSaturation, v >= minValue, v <= maxValue else { return false }
        return hueRanges.contains { $0.contains(h) }
    }

    private static func rgbToHSV(r: CGFloat, g: CGFloat, b: CGFloat) -> (h: CGFloat, s: CGFloat, v: CGFloat) {
        let maxV = max(r, g, b)
        let minV = min(r, g, b)
        let delta = maxV - minV

        var h: CGFloat = 0
        if delta > 0.0001 {
            if maxV == r {
                h = 60 * (((g - b) / delta).truncatingRemainder(dividingBy: 6))
            } else if maxV == g {
                h = 60 * (((b - r) / delta) + 2)
            } else {
                h = 60 * (((r - g) / delta) + 4)
            }
            if h < 0 { h += 360 }
        }

        let s = maxV == 0 ? 0 : delta / maxV
        let v = maxV
        return (h, s, v)
    }
}
