import SwiftUI
import WebKit
import Network
import Foundation

final class JupyterLiteController: ObservableObject {
    fileprivate weak var webView: WKWebView?

    func reload() {
        webView?.reload()
    }

    func exportCurrentNotebook() {
        // Try to trigger JupyterLite export via JS APIs; fallback to browser download
        let js = """
        (async function() {
          try {
            // Attempt JupyterLab doc manager save and export
            const app = window.jupyterapp || window.jupyterlite_app || window.jupyterLiteApp || window.jupyterLite || window.jupyter;
            if (app && app.commands) {
              // Try to execute the built-in export command if available
              const cmds = app.commands;
              if (cmds.hasCommand && cmds.hasCommand('docmanager:save')) {
                await cmds.execute('docmanager:save');
              }
              if (cmds.hasCommand && cmds.hasCommand('notebook:download')) {
                await cmds.execute('notebook:download');
                return 'download-triggered';
              }
            }
            // Fallback: find a download button in DOM and click
            const el = document.querySelector('[data-command="notebook:download"], button[title*="Download"], button[aria-label*="Download"]');
            if (el) { el.click(); return 'download-triggered'; }
            return 'no-export-command';
          } catch (e) {
            return 'error:' + (e && e.message ? e.message : String(e));
          }
        })();
        """
        webView?.evaluateJavaScript(js, completionHandler: { result, error in
            if let error = error { print("JupyterLite export JS error: \(error)") }
            if let result = result { print("JupyterLite export result: \(result)") }
        })
    }

    func importNotebook(named name: String, data: Data) {
        let base64 = data.base64EncodedString()
        let escapedName = name.replacingOccurrences(of: "\\", with: "_").replacingOccurrences(of: "'", with: "_")
        let js = """
        (async function() {
          try {
            const name = '""" + escapedName + """';
            const b64 = '""" + base64 + """';
            const bytes = Uint8Array.from(atob(b64), c => c.charCodeAt(0));
            const blob = new Blob([bytes], { type: 'application/x-ipynb+json' });
            // Try to use the contents manager API if present
            const app = window.jupyterapp || window.jupyterlite_app || window.jupyterLiteApp || window.jupyterLite || window.jupyter;
            if (app && app.serviceManager && app.serviceManager.contents) {
              const cm = app.serviceManager.contents;
              const text = await blob.text();
              const model = { type: 'notebook', format: 'text', content: JSON.parse(text) };
              const path = name.endsWith('.ipynb') ? name : (name + '.ipynb');
              await cm.save(path, model);
              if (app.commands && app.commands.execute) {
                try { await app.commands.execute('docmanager:open', { path }); } catch(e) {}
              }
              return 'saved:' + path;
            }
            // Fallback: create a link and simulate user upload by downloading into FS scope
            const a = document.createElement('a');
            a.download = name.endsWith('.ipynb') ? name : (name + '.ipynb');
            a.href = URL.createObjectURL(blob);
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            return 'download-fallback';
          } catch (e) {
            return 'error:' + (e && e.message ? e.message : String(e));
          }
        })();
        """
        webView?.evaluateJavaScript(js, completionHandler: { result, error in
            if let error = error { print("JupyterLite import JS error: \(error)") }
            if let result = result { print("JupyterLite import result: \(result)") }
        })
    }
}

final class LocalHTTPServer {
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "LocalHTTPServer")
    private let root: URL
    private(set) var port: UInt16?

    init(rootDirectory: URL) {
        self.root = rootDirectory
    }

    func start() throws {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        listener = try NWListener(using: parameters, on: .any)
        listener?.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                if let nwPort = self.listener?.port {
                    self.port = nwPort.rawValue
                }
            default:
                break
            }
        }
        listener?.newConnectionHandler = { [weak self] connection in
            self?.handle(connection: connection)
        }
        listener?.start(queue: queue)
    }

    func stop() {
        listener?.cancel()
        listener = nil
        port = nil
    }

    private func handle(connection: NWConnection) {
        connection.start(queue: queue)
        receiveRequest(on: connection, accumulated: Data())
    }

    private func receiveRequest(on connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            if let data = data, !data.isEmpty {
                var newAccumulated = accumulated
                newAccumulated.append(data)
                if self.hasCompleteHTTPRequest(newAccumulated) {
                    self.respond(to: connection, requestData: newAccumulated)
                } else {
                    self.receiveRequest(on: connection, accumulated: newAccumulated)
                }
            } else {
                connection.cancel()
            }
        }
    }

    private func hasCompleteHTTPRequest(_ data: Data) -> Bool {
        guard let str = String(data: data, encoding: .utf8) else { return false }
        return str.range(of: "\r\n\r\n") != nil
    }

    private func respond(to connection: NWConnection, requestData: Data) {
        guard let requestString = String(data: requestData, encoding: .utf8),
              let firstLine = requestString.components(separatedBy: "\r\n").first else {
            sendSimpleResponse(connection: connection, status: "400 Bad Request", headers: [:], body: nil)
            return
        }

        let components = firstLine.components(separatedBy: " ")
        guard components.count >= 2 else {
            sendSimpleResponse(connection: connection, status: "400 Bad Request", headers: [:], body: nil)
            return
        }

        let method = components[0]
        var path = components[1]

        guard method == "GET" || method == "HEAD" else {
            sendSimpleResponse(connection: connection, status: "405 Method Not Allowed", headers: ["Allow": "GET, HEAD"], body: nil)
            return
        }

        if path == "/" {
            path = "/index.html"
        }
        // Prevent directory traversal
        if path.contains("..") {
            sendSimpleResponse(connection: connection, status: "403 Forbidden", headers: [:], body: nil)
            return
        }

        let fileURL = root.appendingPathComponent(path.dropFirst())

        var isDir: ObjCBool = false
        if !FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir) || isDir.boolValue {
            sendSimpleResponse(connection: connection, status: "404 Not Found", headers: [:], body: nil)
            return
        }

        guard let fileData = try? Data(contentsOf: fileURL) else {
            sendSimpleResponse(connection: connection, status: "500 Internal Server Error", headers: [:], body: nil)
            return
        }

        let mime = mimeType(for: fileURL.pathExtension.lowercased())

        var headers = [
            "Content-Type": mime,
            "Cache-Control": "no-cache",
            "Connection": "close",
            "Access-Control-Allow-Origin": "*"
        ]

        if method == "HEAD" {
            headers["Content-Length"] = "0"
            sendSimpleResponse(connection: connection, status: "200 OK", headers: headers, body: nil)
        } else {
            headers["Content-Length"] = "\(fileData.count)"
            sendSimpleResponse(connection: connection, status: "200 OK", headers: headers, body: fileData)
        }
    }

    private func sendSimpleResponse(connection: NWConnection, status: String, headers: [String: String], body: Data?) {
        var response = "HTTP/1.1 \(status)\r\n"
        for (key, value) in headers {
            response += "\(key): \(value)\r\n"
        }
        response += "\r\n"

        var responseData = Data(response.utf8)
        if let body = body {
            responseData.append(body)
        }

        connection.send(content: responseData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func mimeType(for ext: String) -> String {
        switch ext {
        case "html":
            return "text/html"
        case "js":
            return "application/javascript"
        case "css":
            return "text/css"
        case "json":
            return "application/json"
        case "wasm":
            return "application/wasm"
        case "svg":
            return "image/svg+xml"
        case "png":
            return "image/png"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "ico":
            return "image/x-icon"
        case "map":
            return "application/json"
        case "txt":
            return "text/plain"
        default:
            return "application/octet-stream"
        }
    }
}

final class JupyterLiteHost: ObservableObject {
    private var server: LocalHTTPServer?
    @Published var url: URL?
    private var fixedPort: UInt16? = 8080

    func start() {
        var distURL: URL? = nil
        if let url = Bundle.main.url(forResource: "dist", withExtension: nil, subdirectory: "JupyterLiteSite") {
            distURL = url
        } else if let url = Bundle.main.url(forResource: "dist", withExtension: nil) {
            distURL = url
        }

        guard let root = distURL else {
            print("JupyterLiteHost: Could not find 'dist' directory in bundle.")
            return
        }

        stop()

        let server = LocalHTTPServer(rootDirectory: root)
        self.server = server

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try server.start()
            } catch {
                print("JupyterLiteHost: Failed to start server: \(error)")
                return
            }

            // Wait a short interval to allow port to be assigned
            Thread.sleep(forTimeInterval: 0.15)

            DispatchQueue.main.async {
                guard let port = server.port else {
                    print("JupyterLiteHost: Server did not start with a port")
                    return
                }
                self.url = URL(string: "http://127.0.0.1:\(port)/index.html")
            }
        }
    }

    func stop() {
        server?.stop()
        server = nil
        url = nil
    }
}

struct JupyterLiteWebView: UIViewRepresentable {
    let url: URL
    let controller: JupyterLiteController

    func makeUIView(context: Context) -> WKWebView {
        let ucc = WKUserContentController()
        let scriptSource = """
        window.pultoBridge = { log: function(msg){ try { console.log('[Pulto]', msg); } catch(e){} } };
        """
        let userScript = WKUserScript(source: scriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        ucc.addUserScript(userScript)

        let config = WKWebViewConfiguration()
        config.userContentController = ucc
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        controller.webView = webView

        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {}

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {}

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {}

        func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
            download.delegate = self
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            decisionHandler(.allow)
        }

        // WKDownloadDelegate
        func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?, WKDownloadDestinationDisposition) -> Void) {
            let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            let destinationURL = docDir?.appendingPathComponent(suggestedFilename) ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(suggestedFilename)
            completionHandler(destinationURL, .allow)
        }

        func downloadDidFinish(_ download: WKDownload) {
            if let url = download.destinationURL {
                print("Download finished: \(url.path)")
            } else {
                print("Download finished but destination URL is unknown")
            }
        }
    }
}

struct JupyterLiteWindow: View {
    @StateObject private var host = JupyterLiteHost()
    @StateObject private var controller = JupyterLiteController()
    @State private var showingImporter = false

    var body: some View {
        Group {
            if let url = host.url {
                JupyterLiteWebView(url: url, controller: controller)
                    .ignoresSafeArea()
            } else {
                ProgressView("Preparing JupyterLite…")
            }
        }
        .task {
            host.start()
        }
        .onDisappear {
            host.stop()
        }
        .fileImporter(isPresented: $showingImporter,
                      allowedContentTypes: [.json, .data, .init(filenameExtension: "ipynb")!],
                      allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                do {
                    let data = try Data(contentsOf: url)
                    controller.importNotebook(named: url.lastPathComponent, data: data)
                } catch {
                    print("Failed to read imported notebook: \(error)")
                }
            case .failure(let error):
                print("Import failed: \(error)")
            }
        }
        .ornament(content: {
            Button("Reload") {
                controller.reload()
            }
            Button("Import") {
                showingImporter = true
            }
            Button("Export") {
                controller.exportCurrentNotebook()
            }
        })
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("Reload") {
                    host.stop()
                    host.start()
                }
            }
        }
    }
}
