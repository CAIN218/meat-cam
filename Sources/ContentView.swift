import SwiftUI

struct ContentView: View {
    @StateObject private var camera = CameraManager()

    var body: some View {
        ZStack {
            if camera.isAuthorized {
                CameraPreviewView(session: camera.session)
                    .ignoresSafeArea()

                RawRegionOverlayView(grid: camera.grid)
                    .ignoresSafeArea()

                VStack {
                    legend
                        .padding(.top, 12)
                    Spacer()
                }
            } else if let error = camera.setupError {
                VStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text(error)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            } else {
                ProgressView("カメラを起動しています…")
            }
        }
        .onAppear { camera.configureAndStart() }
        .onDisappear { camera.stop() }
        .background(Color.black)
    }

    private var legend: some View {
        HStack(spacing: 8) {
            HatchSwatch()
                .frame(width: 22, height: 22)
            Text("斜線 = まだ生っぽい部分")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.black.opacity(0.55)))
    }
}

private struct HatchSwatch: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.orange.opacity(0.22))
            RawRegionOverlayView(grid: DonenessGrid(columns: 1, rows: 1, isRaw: [true]))
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(.white.opacity(0.4), lineWidth: 1))
    }
}

#Preview {
    ContentView()
}
