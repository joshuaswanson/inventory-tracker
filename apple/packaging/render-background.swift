import AppKit
import SwiftUI

private struct Background: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.941, green: 0.992, blue: 0.980), .white],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack(spacing: 6) {
                Text("Drag Inventory Tracker into Applications")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color(red: 0.082, green: 0.369, blue: 0.459))
                Text("Then open it from your Applications folder")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(red: 0.392, green: 0.455, blue: 0.545))
            }
            .position(x: 330, y: 62)
            Image(systemName: "arrow.right")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Color(red: 0.031, green: 0.569, blue: 0.698))
                .position(x: 330, y: 198)
        }
        .frame(width: 660, height: 400)
    }
}

@MainActor
private func save(scale: CGFloat, to path: String) {
    let renderer = ImageRenderer(content: Background())
    renderer.scale = scale
    guard let image = renderer.cgImage,
          let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
        fatalError("Couldn't render \(path)")
    }
    try! data.write(to: URL(fileURLWithPath: path))
}

MainActor.assumeIsolated {
    let folder = CommandLine.arguments[1]
    save(scale: 1, to: "\(folder)/dmg-background.png")
    save(scale: 2, to: "\(folder)/dmg-background@2x.png")
}
