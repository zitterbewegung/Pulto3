import SwiftUI
import WebKit

public struct JupyterWebView: UIViewRepresentable {
    let url: URL

    public init(url: URL) { self.url = url }

    public func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.preferences.javaScriptEnabled = true
        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.allowsBackForwardNavigationGestures = true
        wv.load(URLRequest(url: url))
        return wv
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {}
}
