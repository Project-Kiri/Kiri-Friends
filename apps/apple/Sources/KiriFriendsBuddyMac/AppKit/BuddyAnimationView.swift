// BuddyAnimationView.swift
// AppKit NSView wrapping a WKWebView that renders the buddy's animated
// SVG. Eye tracking is wired through native → JS via
// `evaluateJavaScript` so the upstream SVG eye-tracking IDs (`eyes-js`,
// `body-js`, `shadow-js`) update without needing a JS bridge handler.

import AppKit
import KiriFriendsMacBuddyKit
import WebKit

public final class BuddyAnimationView: NSView {
    public static let defaultSize = NSSize(width: 220, height: 220)

    private let webView: WKWebView
    private var currentState: MacBuddyState = .idle
    private var loadedTheme: LoadedTheme?
    private var eyeTracking: BuddyEyeTrackingConfiguration

    public init(eyeTracking: BuddyEyeTrackingConfiguration = .clawd) {
        self.eyeTracking = eyeTracking

        let configuration = WKWebViewConfiguration()
        configuration.suppressesIncrementalRendering = false
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        self.webView = WKWebView(frame: .zero, configuration: configuration)
        super.init(frame: NSRect(origin: .zero, size: Self.defaultSize))

        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        updateAccessibilityLabel()
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.setValue(false, forKey: "drawsBackground")
        addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        loadHTML()
        Task { [weak self] in
            await self?.loadDefaultTheme()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public override var isOpaque: Bool { false }
    public override var wantsUpdateLayer: Bool { true }

    /// Switches the buddy to a different theme at runtime. The animation
    /// view re-emits the current state into the new theme as soon as the
    /// descriptor is loaded.
    public func setTheme(_ theme: LoadedTheme) {
        loadedTheme = theme
        if let configuration = theme.descriptor.eyeTracking?.asConfiguration {
            eyeTracking = configuration
        }
        emitCurrentState()
    }

    /// Updates the displayed SVG to match `state`. Triggered by the
    /// state-store subscription on the main actor.
    public func setState(_ state: MacBuddyState) {
        guard state != currentState else { return }
        currentState = state
        updateAccessibilityLabel()
        emitCurrentState()
    }

    private func updateAccessibilityLabel() {
        setAccessibilityLabel("Kiri Buddy is \(currentState.accessibilityDescription)")
    }

    private func loadDefaultTheme() async {
        guard let theme = await BuddyThemeAssets.bundledTheme(
            identifier: BuddyThemeAssets.bundledThemeIdentifier
        ) else {
            return
        }
        await MainActor.run {
            self.setTheme(theme)
        }
    }

    private func emitCurrentState() {
        guard let theme = loadedTheme else { return }
        guard let filename = theme.descriptor.primaryFile(for: currentState) else { return }
        let url = theme.assetURL(filename: filename)
        let path = url.path.replacingOccurrences(of: "'", with: "\\'")
        let script = "window.kiriBuddy.loadSvg('file://\(path)');"
        webView.evaluateJavaScript(script)
    }

    /// Native-driven eye tracking. Pass cursor position in screen
    /// coordinates relative to the window's frame origin (already
    /// converted to the view's local space).
    public func setEyeTarget(localCursor: CGPoint) {
        let normalizedX = (localCursor.x - bounds.midX) / max(bounds.width / 2, 1)
        let normalizedY = (localCursor.y - bounds.midY) / max(bounds.height / 2, 1)
        let script = "window.kiriBuddy.setEyeTarget(\(normalizedX), \(normalizedY));"
        webView.evaluateJavaScript(script)
    }

    private func loadHTML() {
        let html = BuddyAnimationHTML.render(config: eyeTracking)
        let baseURL = BuddyThemeAssets.bundledThemesDirectory
        webView.loadHTMLString(html, baseURL: baseURL)
    }
}

enum BuddyAnimationHTML {
    static func render(config: BuddyEyeTrackingConfiguration) -> String {
        """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
          html, body {
            margin: 0;
            padding: 0;
            background: transparent;
            overflow: hidden;
            -webkit-user-select: none;
            user-select: none;
          }
          #stage {
            width: 100vw;
            height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
          }
          #stage svg {
            width: 100%;
            height: 100%;
            display: block;
          }
        </style>
        </head>
        <body>
          <div id="stage"></div>
          <script>
            (function () {
              const stage = document.getElementById('stage');
              const parser = new DOMParser();
              const eye = {
                maxOffset: \(config.maxOffset),
                bodyScale: \(config.bodyScale),
                shadowStretch: \(config.shadowStretch),
                shadowShift: \(config.shadowShift),
                targetX: 0,
                targetY: 0
              };

              function clearStage() {
                while (stage.firstChild) {
                  stage.removeChild(stage.firstChild);
                }
              }

              function applyEyeTracking() {
                const eyes = stage.querySelector('#eyes-js');
                const body = stage.querySelector('#body-js');
                const shadow = stage.querySelector('#shadow-js');
                const dx = Math.max(-1, Math.min(1, eye.targetX));
                const dy = Math.max(-1, Math.min(1, eye.targetY));
                const offsetX = dx * eye.maxOffset;
                const offsetY = dy * eye.maxOffset;
                if (eyes) {
                  eyes.setAttribute('transform', `translate(${offsetX}, ${offsetY})`);
                }
                if (body) {
                  const lean = offsetX * eye.bodyScale;
                  body.setAttribute('transform', `translate(${lean}, 0)`);
                }
                if (shadow) {
                  const stretchX = 1 + Math.abs(offsetX) * eye.shadowStretch;
                  const shiftX = offsetX * eye.shadowShift;
                  shadow.setAttribute('transform', `translate(${shiftX}, 0) scale(${stretchX}, 1)`);
                }
              }

              async function loadSvg(url) {
                try {
                  const response = await fetch(url);
                  const text = await response.text();
                  const doc = parser.parseFromString(text, 'image/svg+xml');
                  const svgNode = doc.querySelector('svg');
                  if (!svgNode) {
                    return;
                  }
                  const imported = document.importNode(svgNode, true);
                  clearStage();
                  stage.appendChild(imported);
                  applyEyeTracking();
                } catch (err) {
                  clearStage();
                  const pre = document.createElement('pre');
                  pre.style.color = 'red';
                  pre.textContent = String(err);
                  stage.appendChild(pre);
                }
              }

              function setEyeTarget(x, y) {
                eye.targetX = x;
                eye.targetY = y;
                applyEyeTracking();
              }

              window.kiriBuddy = { loadSvg, setEyeTarget };
            })();
          </script>
        </body>
        </html>
        """
    }
}
