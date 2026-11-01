import AppKit
import SwiftUI

/// Renders the main views to PNGs and exits. Used to eyeball layout without
/// launching the UI:  FOCUS_SNAPSHOT=/tmp/shots  dist/Focus.app/Contents/MacOS/Focus
@MainActor
enum Snapshot {
    static func runIfRequested() -> Bool {
        guard let dir = ProcessInfo.processInfo.environment["FOCUS_SNAPSHOT"] else { return false }
        let base = URL(fileURLWithPath: dir)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)

        render(MainWindowView().frame(width: 380, height: 268),
               to: base.appendingPathComponent("main.png"))
        render(MainWindowView().frame(width: 220, height: 268),
               to: base.appendingPathComponent("main-narrow.png"))
        render(MainWindowView().frame(width: 520, height: 480),
               to: base.appendingPathComponent("main-large.png"))
        render(SettingsView(), to: base.appendingPathComponent("settings.png"))
        render(StatisticsView().frame(width: 760, height: 620),
               to: base.appendingPathComponent("statistics.png"))
        render(HowItWorksView(), to: base.appendingPathComponent("howitworks.png"))
        render(WelcomeView {}, to: base.appendingPathComponent("welcome.png"))
        render(BreakWindowView().frame(width: 900, height: 620),
               to: base.appendingPathComponent("break.png"))
        print("snapshots written to \(base.path)")
        return true
    }

    private static func render<V: View>(_ view: V, to url: URL) {
        let renderer = ImageRenderer(content: view.preferredColorScheme(.light))
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:]) else {
            print("could not render \(url.lastPathComponent)")
            return
        }
        try? data.write(to: url)
    }
}
