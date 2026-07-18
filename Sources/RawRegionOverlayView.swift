import SwiftUI

/// 「まだ生っぽい」グリッドセルの上に斜線ハッチングを重ねて描画する。
/// 色弱の方でも判別できるよう、色だけに頼らずパターン(斜線)を主な合図にしている。
/// 薄いアンバー色の塗りも足しているが、これは補助的なもの。
struct RawRegionOverlayView: View {
    let grid: DonenessGrid

    private let hatchSpacing: CGFloat = 7
    private let hatchLineWidth: CGFloat = 1.6

    var body: some View {
        Canvas { context, size in
            guard grid.columns > 0, grid.rows > 0 else { return }

            let cellWidth = size.width / CGFloat(grid.columns)
            let cellHeight = size.height / CGFloat(grid.rows)

            var rawRegionPath = Path()
            for row in 0..<grid.rows {
                for col in 0..<grid.columns {
                    guard grid.isRaw[row * grid.columns + col] else { continue }
                    let rect = CGRect(
                        x: CGFloat(col) * cellWidth,
                        y: CGFloat(row) * cellHeight,
                        width: cellWidth,
                        height: cellHeight
                    )
                    rawRegionPath.addRect(rect)
                }
            }

            guard !rawRegionPath.isEmpty else { return }

            // 補助的な薄いアンバー塗り(色だけに頼らないための"追加"情報)
            context.fill(rawRegionPath, with: .color(.orange.opacity(0.22)))

            // 主な合図: 斜線ハッチング。塗り範囲でクリップしてから斜線を引く。
            context.clip(to: rawRegionPath)

            var hatchPath = Path()
            let diagonalCount = Int((size.width + size.height) / hatchSpacing) + 1
            for i in 0..<diagonalCount {
                let offset = CGFloat(i) * hatchSpacing
                hatchPath.move(to: CGPoint(x: offset, y: 0))
                hatchPath.addLine(to: CGPoint(x: offset - size.height, y: size.height))
            }
            context.stroke(hatchPath, with: .color(.white.opacity(0.9)), lineWidth: hatchLineWidth)
        }
        .allowsHitTesting(false)
    }
}
