import SwiftUI
import WebKit
import os

#if os(iOS) || os(visionOS)
private typealias JupyterPlatformViewRepresentable = UIViewRepresentable
#elseif os(macOS)
private typealias JupyterPlatformViewRepresentable = NSViewRepresentable
#endif

fileprivate let jupyterLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "JupyterApp", category: "JupyterLite")

private struct JupyterWebView: JupyterPlatformViewRepresentable {
    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: JupyterWebView
        init(_ parent: JupyterWebView) { self.parent = parent }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            jupyterLog.error("WKWebView navigation failed: \(error.localizedDescription, privacy: .public)")
            parent.onError?(error)
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            jupyterLog.error("WKWebView navigation failed: \(error.localizedDescription, privacy: .public)")
            parent.onError?(error)
        }
    }

    var url: URL
    var onError: ((Error) -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    #if os(iOS) || os(visionOS)
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: makeConfiguration())
        webView.navigationDelegate = context.coordinator
        load(into: webView)
        return webView
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // no-op; caller can trigger reload via a new url if needed
    }
    #elseif os(macOS)
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: makeConfiguration())
        webView.navigationDelegate = context.coordinator
        load(into: webView)
        return webView
    }
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // no-op
    }
    #endif

    private func makeConfiguration() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        #if os(iOS) || os(visionOS)
        config.allowsAirPlayForMediaPlayback = true
        #endif
        return config
    }

    private func load(into webView: WKWebView) {
        jupyterLog.info("Loading JupyterLite URL: \(url.absoluteString, privacy: .public)")
        if url.isFileURL {
            let dir = url.deletingLastPathComponent()
            jupyterLog.debug("Detected file URL. Allowing read access to directory: \(dir.path, privacy: .public)")
            webView.loadFileURL(url, allowingReadAccessTo: dir)
        } else {
            jupyterLog.debug("Detected remote URL. Loading via URLRequest.")
            webView.load(URLRequest(url: url))
        }
    }
}

struct JupyterLiteWindow: View {
    @State private var resolvedURL: URL? = nil
    @State private var lastError: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
        }
        .onAppear(perform: resolveIfNeeded)
    }

    @ViewBuilder private var content: some View {
        if let url = resolvedURL {
            JupyterWebView(url: url) { error in
                lastError = error.localizedDescription
            }
        } else {
            VStack(spacing: 12) {
                Text("JupyterLite not found in app bundle")
                    .font(.title3).bold()
                if let lastError { Text(lastError).font(.footnote).foregroundStyle(.secondary) }
                Text("Place your built JupyterLite output folder (containing index.html) into the app target's resources. Common subfolder names I will search: 'Pulto/dist', 'dist', 'jupyterlite', 'jupyter-lite', 'JupyterLite', 'Web', 'www'.")
                    .multilineTextAlignment(.center)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if let remote = remoteFallbackURL() {
                    Link("Open configured remote Jupyter: \(remote.absoluteString)", destination: remote)
                        .font(.callout)
                }
            }
            .padding(24)
        }
    }

    @ViewBuilder private var toolbar: some View {
        HStack {
            Text("JupyterLite")
                .font(.headline)
            Spacer()
            Button(action: reload) {
                Image(systemName: "arrow.clockwise")
            }
            .help("Reload")
        }
        .padding(8)
        .background(.ultraThinMaterial)
    }

    private func reload() {
        lastError = nil
        resolvedURL = nil
        resolveIfNeeded()
    }

    private func resolveIfNeeded() {
        jupyterLog.debug("Resolving JupyterLite URL…")
        if resolvedURL != nil { return }
        if let local = findLocalJupyterLiteIndex() {
            jupyterLog.info("Resolved local JupyterLite index at: \(local.path, privacy: .public)")
            resolvedURL = local
            return
        }
        if let remote = remoteFallbackURL() {
            jupyterLog.info("Resolved remote JupyterLite URL: \(remote.absoluteString, privacy: .public)")
            resolvedURL = remote
            return
        }
        jupyterLog.warning("No JupyterLite location resolved (no local index.html found and no remote fallback set).")
        // else leave nil to show guidance
    }

    private func remoteFallbackURL() -> URL? {
        if let s = UserDefaults.standard.string(forKey: "defaultJupyterURL"), let url = URL(string: s), !s.isEmpty {
            return url
        }
        return nil
    }

    private func findLocalJupyterLiteIndex() -> URL? {
        // Try common subdirectories first
        jupyterLog.debug("Searching for JupyterLite index.html in common subdirectories…")
        let candidates = ["Pulto/dist", "Pulto/Dist", "dist", "Dist", "jupyterlite", "jupyter-lite", "JupyterLite", "Web", "www"]
        for sub in candidates {
            jupyterLog.debug("Checking subdirectory: \(sub, privacy: .public)")
            if let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: sub) {
                jupyterLog.info("Found index.html in subdirectory: \(sub, privacy: .public)")
                return url
            }
        }
        // Try at bundle root
        if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
            jupyterLog.info("Found index.html at bundle root.")
            return url
        }
        // As a last resort, try to locate any folder containing index.html by enumerating known resource URLs
        // (kept minimal to avoid heavy enumeration)
        jupyterLog.warning("Could not find index.html in known locations.")
        return nil
    }
}

#Preview {
    JupyterLiteWindow()
}

