# MeatCam (working title) — a raw-meat doneness visualizer for the colorblind

An iOS app that overlays diagonal hatching on parts of the camera view that still look raw (strongly red).
It leans on pattern ("hatching") rather than color alone as the main cue, so it's easier to tell apart for
people with red/green color blindness.

This folder only contains Swift source files (the `.xcodeproj` is meant to be created in Xcode).
Since iOS apps can't be built or run on a physical device from Windows, set it up in Xcode on a Mac using
the steps below.

## 1. Create the Xcode project

1. Open Xcode, **File > New > Project**
2. Select **iOS > App**
3. Create it with these settings:
   - Product Name: `MeatCam` (or whatever you prefer)
   - Interface: **SwiftUI**
   - Language: **Swift**
4. **Delete** the generated `ContentView.swift` and the app-name file (e.g. `MeatCamApp.swift`) — they'll be
   replaced by the files in this repo.

## 2. Add the source files

Drag the following files from the `Sources/` folder into Xcode's project navigator (check "Copy items if
needed"):

- `MeatCamApp.swift` — app entry point
- `ContentView.swift` — main screen (camera feed + hatching overlay + legend)
- `CameraManager.swift` — manages the camera capture session, throttles frames before handing them to the analyzer
- `DonenessAnalyzer.swift` — the core "does this look raw?" logic (see below)
- `CameraPreviewView.swift` — SwiftUI wrapper around `AVCaptureVideoPreviewLayer`
- `RawRegionOverlayView.swift` — draws the diagonal hatching

## 3. Set up camera permission

In Xcode's project settings > your target > the **Info** tab, add this key:

- Key: `Privacy - Camera Usage Description` (`NSCameraUsageDescription`)
- Value: something like "This app uses the camera to check doneness."

Without this, requesting camera access will crash the app immediately.

## 4. Run on a device

**The Simulator has no camera, so you must run this on a physical iPhone.**

1. Connect your iPhone to the Mac via USB (or set up wireless debugging over Wi-Fi)
2. Select your iPhone from the device picker at the top of Xcode
3. Build and run (⌘R)
4. Grant camera access on first launch

You'll need to be signed into Xcode with an Apple ID (a free Apple Developer account works fine).

---

## About the detection logic (current implementation = a heuristic)

`HeuristicDonenessAnalyzer` in `DonenessAnalyzer.swift` does the actual detection. How it works:

1. Downscale each camera frame to a coarse 40×30 grid
2. Convert each cell's average color to HSV (hue, saturation, value)
3. Flag a cell as "raw-looking" if it falls in the red-to-magenta hue range with reasonably high saturation and value

This is a hue-based rule set, not a trained AI model. It's expected to misfire under real meat/lighting
conditions, so tune `hueRanges` / `minSaturation` / `minValue` / `maxValue` while testing on a device.

## Swapping in a real AI model later

The detection logic sits behind a `DonenessAnalyzing` protocol, so it can be swapped out without touching
`ContentView` or `CameraManager`.

1. **Collect photos**: shoot dozens to hundreds of photos of meat at various doneness levels, angles, and lighting
2. **Train a segmentation model in Create ML** (bundled with macOS): paint masks over the "raw" regions in
   your photos to build training data, train with the Image Segmentation template → this exports a `.mlmodel`
3. Adding the `.mlmodel` to the Xcode project auto-generates a Swift type for it
4. Create a new `CoreMLDonenessAnalyzer` conforming to `DonenessAnalyzing` that runs that model via
   `VNCoreMLRequest` and converts its output mask into a `DonenessGrid`
5. In `CameraManager.swift`, change `private let analyzer: DonenessAnalyzing = HeuristicDonenessAnalyzer()`
   to `CoreMLDonenessAnalyzer()` — that's the whole swap

## Known limitations / things to tune next

- The heuristic's color thresholds are untuned (need real meat to calibrate against)
- Raw marbling (white fat) or sauce color may trigger false positives
- Highlights from reflections/strong lighting are excluded from detection, but could use more tuning
- No front-camera toggle yet (rear camera only)
