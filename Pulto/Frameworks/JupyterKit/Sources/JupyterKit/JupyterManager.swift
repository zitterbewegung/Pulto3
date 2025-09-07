import Foundation

public enum JupyterUI: String, CaseIterable, Codable { case lab, notebook }

public final class JupyterManager: ObservableObject {
    @Published public var url: URL?
    @Published public var isRunning = false

    private var process: Process?
    private var port: Int = 0

    // Default to app Documents folder; caller can override with a security-scoped URL
    public init() {}

    public func startIfNeeded(ui: JupyterUI, root: URL?) async {
        if url != nil { return }
        do {
            let work = root ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            try configurePythonEnv(workDir: work)
            port = try allocatePort()
            try launch(ui: ui, workDir: work)
            try await waitUntilReady()
            await MainActor.run {
                self.url = URL(string: "http://127.0.0.1:\(self.port)/" + (ui == .lab ? "lab" : "tree"))!
                self.isRunning = true
            }
        } catch {
            print("Jupyter start failed: \(error)")
        }
    }

    public func stop() {
        process?.terminate()
        process = nil
        url = nil
        isRunning = false
    }

    private func configurePythonEnv(workDir: URL) throws {
        // Expect python-stdlib & site-packages under main app bundle Resources/Jupyter
        guard let appRes = Bundle.main.resourceURL?.appendingPathComponent("Jupyter") else {
            throw NSError(domain: "JupyterKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing Resources/Jupyter"])
        }
        setenv("PYTHONUNBUFFERED", "1", 1)
        setenv("PYTHONHOME", appRes.appendingPathComponent("python-stdlib").path, 1)
        let sp = appRes.appendingPathComponent("site-packages").path
        setenv("PYTHONPATH", f"{sp}:{appRes.path}", 1)
        setenv("JUPYTER_CONFIG_DIR", Bundle.module.resourcePath!, 1)
        setenv("JUPYTER_RUNTIME_DIR", workDir.path, 1)
        setenv("JUPYTER_DATA_DIR", workDir.path, 1)
    }

    private func allocatePort() throws -> Int {
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(0).bigEndian
        addr.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        var a = addr
        let ok = withUnsafePointer(to: &a) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { ptr in
                bind(fd, ptr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        } == 0
        guard ok else { close(fd); throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        var len: socklen_t = socklen_t(MemoryLayout<sockaddr_in>.size)
        getsockname(fd, withUnsafeMutablePointer(to: &a) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { $0 }
        }, &len)
        let p = Int(UInt16(bigEndian: a.sin_port))
        close(fd)
        return p
    }

    private func launch(ui: JupyterUI, workDir: URL) throws {
        guard let bootstrap = Bundle.module.path(forResource: "bootstrap", ofType: "py") else {
            throw NSError(domain: "JupyterKit", code: 3, userInfo: [NSLocalizedDescriptionKey: "bootstrap.py not found"])
        }
        let python = "/usr/libexec/py" // adjust if your embedded interpreter lives elsewhere
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: python)
        proc.arguments = [bootstrap, "--port", "\(port)", "--notebook-dir", workDir.path, "--ui", ui.rawValue]
        proc.environment = ProcessInfo.processInfo.environment
        proc.standardOutput = Pipe()
        proc.standardError = Pipe()
        try proc.run()
        self.process = proc
    }

    private func waitUntilReady(timeout: TimeInterval = 30) async throws {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if let health = URL(string: "http://127.0.0.1:\(port)/api") {
                if (try? Data(contentsOf: health, options: [.uncached])) is Data { return }
            }
            try await Task.sleep(nanoseconds: 300_000_000)
        }
        throw NSError(domain: "JupyterKit", code: 2, userInfo: [NSLocalizedDescriptionKey: "Server timeout"])
    }

    deinit { stop() }
}
