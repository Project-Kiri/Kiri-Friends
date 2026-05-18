import SwiftUI

#if canImport(UIKit)
import UIKit
private typealias BuddyPlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
private typealias BuddyPlatformImage = NSImage
#endif

public struct BuddyAnimationPlayer: View {
    let request: BuddyAnimationRequest?
    let fallbackAssetName: String?
    let fallbackSymbolName: String
    let reduceMotion: Bool
    let stageSize: CGFloat

    @State private var fallbackBreathes = false

    public init(
        request: BuddyAnimationRequest?,
        fallbackAssetName: String?,
        fallbackSymbolName: String,
        reduceMotion: Bool,
        stageSize: CGFloat
    ) {
        self.request = request
        self.fallbackAssetName = fallbackAssetName
        self.fallbackSymbolName = fallbackSymbolName
        self.reduceMotion = reduceMotion
        self.stageSize = stageSize
    }

    public var body: some View {
        if let request,
           let manifest = BuddyAnimationFrameCatalog.manifest(for: request),
           !manifest.frames.isEmpty {
            animatedFrames(request: request, manifest: manifest)
                .id(request.id)
        } else {
            fallbackImage
        }
    }

    @ViewBuilder
    private func animatedFrames(
        request: BuddyAnimationRequest,
        manifest: BuddyAnimationFrameManifest
    ) -> some View {
        if reduceMotion || manifest.frames.count == 1 {
            frameImage(
                named: manifest.posterFrame,
                request: request,
                manifest: manifest
            )
        } else {
            TimelineView(.animation) { context in
                let frame = frameName(at: context.date, in: manifest)
                frameImage(named: frame, request: request, manifest: manifest)
            }
        }
    }

    @ViewBuilder
    private func frameImage(
        named frameName: String,
        request: BuddyAnimationRequest,
        manifest: BuddyAnimationFrameManifest
    ) -> some View {
        if let url = BuddyAnimationFrameCatalog.frameURL(named: frameName, for: request),
           let image = BuddyPlatformImage(contentsOfFile: url.path) {
            Image(buddyPlatformImage: image)
                .resizable()
                .interpolation(.none)
                .aspectRatio(contentMode: .fit)
                .frame(width: stageSize, height: stageSize)
                .scaleEffect(layoutScale(for: manifest.layout))
                .offset(layoutOffset(for: manifest.layout))
        } else {
            fallbackImage
        }
    }

    private var fallbackImage: some View {
        Group {
            if let fallbackAssetName {
                Image(fallbackAssetName, bundle: .module)
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: fallbackSymbolName)
                    .font(.system(size: stageSize * 0.68))
            }
        }
        .frame(width: stageSize, height: stageSize)
        .scaleEffect(reduceMotion ? 1 : (fallbackBreathes ? 1.025 : 1.0))
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 1.8).repeatForever(autoreverses: true),
            value: fallbackBreathes
        )
        .onAppear { fallbackBreathes = true }
    }

    private func frameName(at date: Date, in manifest: BuddyAnimationFrameManifest) -> String {
        guard manifest.frames.count > 1, manifest.durationMs > 0 else {
            return manifest.posterFrame
        }

        let duration = Double(manifest.durationMs) / 1_000
        let position = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: duration)
        let normalized = max(0, min(1, position / duration))
        let index = Int(normalized * Double(manifest.frames.count)) % manifest.frames.count
        return manifest.frames[index]
    }

    private func layoutScale(for layout: BuddyAnimationLayout) -> CGFloat {
        guard layout.contentBox.width > 0 else { return 1 }
        let ratio = layout.viewBox.width / layout.contentBox.width
        let targetCoverage = max(layout.visibleHeightRatio, 0.72)
        return CGFloat(ratio * targetCoverage)
    }

    private func layoutOffset(for layout: BuddyAnimationLayout) -> CGSize {
        guard layout.viewBox.width > 0, layout.viewBox.height > 0 else { return .zero }

        let contentCenterX = layout.contentBox.x + layout.contentBox.width / 2
        let contentCenterY = layout.contentBox.y + layout.contentBox.height / 2
        let viewCenterX = layout.viewBox.x + layout.viewBox.width / 2
        let viewCenterY = layout.viewBox.y + layout.viewBox.height / 2
        let scale = layoutScale(for: layout)

        let pointsPerUnitX = stageSize / CGFloat(layout.viewBox.width)
        let pointsPerUnitY = stageSize / CGFloat(layout.viewBox.height)
        let x = -CGFloat(contentCenterX - viewCenterX) * pointsPerUnitX * scale
        let y = -CGFloat(contentCenterY - viewCenterY) * pointsPerUnitY * scale

        return CGSize(width: x, height: y)
    }
}

private extension Image {
    #if canImport(UIKit)
    init(buddyPlatformImage image: BuddyPlatformImage) {
        self.init(uiImage: image)
    }
    #elseif canImport(AppKit)
    init(buddyPlatformImage image: BuddyPlatformImage) {
        self.init(nsImage: image)
    }
    #endif
}
