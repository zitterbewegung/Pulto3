import SwiftUI
import WebKit

#if os(macOS)
typealias PlatformViewRepresentable = NSViewRepresentable
#else
typealias PlatformViewRepresentable = UIViewRepresentable
#endif

/// A SwiftUI wrapper around WKWebView to host JupyterLite (Pyodide) sites.
/// Provides a simple JS bridge named `pultoBridge` for save/load interactions.
struct JupyterLiteView: PlatformViewRepresentable {
    /// URL to load (hosted HTTPS site or bundled file URL)
    let url: URL
    /// When true, attempts to create a new notebook when the page finishes loading
    let createNewOnAppear: Bool
    /// Optional callbacks for host app integration
    var onSaveNotebook: ((String, String) -> Void)? // (name, contentJSON)
    var onRequestOpenNotebook: (() -> Void)? // Host can present a file picker and inject content back
    var pendingInjection: Binding<(name: String, json: String)?> 

    init(url: URL,
         createNewOnAppear: Bool = false,
         pendingInjection: Binding<(name: String, json: String)?> = .constant(nil),
         onSaveNotebook: ((String, String) -> Void)? = nil,
         onRequestOpenNotebook: (() -> Void)? = nil) {
        self.url = url
        self.createNewOnAppear = createNewOnAppear
        self.onSaveNotebook = onSaveNotebook
        self.onRequestOpenNotebook = onRequestOpenNotebook
        self.pendingInjection = pendingInjection
    }

    #if os(macOS)
    func makeNSView(context: Context) -> WKWebView { makeWebView(context: context) }
    func updateNSView(_ nsView: WKWebView, context: Context) {
        if let payload = pendingInjection.wrappedValue {
            context.coordinator.injectNotebookJSON(payload.json, name: payload.name)
            DispatchQueue.main.async { pendingInjection.wrappedValue = nil }
        }
    }
    #else
    func makeUIView(context: Context) -> WKWebView { makeWebView(context: context) }
    func updateUIView(_ uiView: WKWebView, context: Context) {
        if let payload = pendingInjection.wrappedValue {
            context.coordinator.injectNotebookJSON(payload.json, name: payload.name)
            DispatchQueue.main.async { pendingInjection.wrappedValue = nil }
        }
    }
    #endif

    private func makeWebView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.userContentController.add(context.coordinator, name: "pultoBridge")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.bounces = false
        context.coordinator.parent = self
        context.coordinator.webView = webView
        context.coordinator.pendingInjection = pendingInjection

        let req = URLRequest(url: url)
        webView.load(req)
        return webView
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        weak var webView: WKWebView?
        var parent: JupyterLiteView?
        var pendingInjection: Binding<(name: String, json: String)?> = .constant(nil)

        // MARK: - JS Bridge Handling
        // Expected messages from the page:
        // { type: 'saveNotebook', name: 'My.ipynb', content: '{...json...}' }
        // { type: 'requestOpenNotebook' }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "pultoBridge" else { return }
            if let dict = message.body as? [String: Any], let type = dict["type"] as? String {
                switch type {
                case "saveNotebook":
                    let name = (dict["name"] as? String) ?? "Untitled.ipynb"
                    let content = (dict["content"] as? String) ?? "{}"
                    if let onSave = parent?.onSaveNotebook {
                        onSave(name, content)
                    } else {
                        // Default save to Documents/PultoNotebooks
                        defaultSave(name: name, content: content)
                    }
                    // Optionally notify page of success
                    evaluateJS("window.pultoOnSave && window.pultoOnSave(true)")
                case "requestOpenNotebook":
                    if let onOpen = parent?.onRequestOpenNotebook {
                        onOpen()
                    } else {
                        // No host picker provided; reply not supported
                        evaluateJS("window.pultoOnOpen && window.pultoOnOpen(null)")
                    }
                default:
                    break
                }
            }
        }

        // Provide a way for the host to inject a notebook JSON back into the page
        func injectNotebookJSON(_ json: String, name: String = "Injected.ipynb") {
            let escaped = json.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            let js = "window.pultoReceiveNotebook && window.pultoReceiveNotebook(\"\(name)\", \"\(escaped)\");"
            evaluateJS(js)
        }

        private func defaultSave(name: String, content: String) {
            do {
                let fm = FileManager.default
                let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
                let dir = docs.appendingPathComponent("PultoNotebooks", isDirectory: true)
                try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
                let url = dir.appendingPathComponent(name)
                try content.data(using: .utf8)?.write(to: url)
                print("[JupyterLite] Saved notebook to: \(url.path)")
            } catch {
                print("[JupyterLite] Save failed: \(error)")
            }
        }

        private func evaluateJS(_ js: String) {
            webView?.evaluateJavaScript(js, completionHandler: { _, error in
                if let error { print("[JupyterLite] JS eval error: \(error)") }
            })
        }

        // MARK: - Navigation
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Try to create a new notebook if requested
            if parent?.createNewOnAppear == true {
                // Attempt a JupyterLab command; if unavailable, this is a no-op
                let js = "(async () => { try { if (window.jupyterapp) { await window.jupyterapp.commands.execute('notebook:create-new'); } } catch(e) { console.warn('pulto create-new failed', e); } })();"
                evaluateJS(js)
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("JupyterLiteView navigation failed: \(error)")
        }
    }
}

#if DEBUG
#Preview {
    JupyterLiteView(url: URL(string: "https://jupyterlite.github.io/demo/latest")!, createNewOnAppear: false)
}
#endif
