import Foundation

/// Thin Swift façade your app calls to start/stop the embedded Carnets (Jupyter) server.
/// Requires an Objective-C bridge named `CarnetsLauncher` with:
/// + (BOOL)startAtPath:(NSString *)root port:(NSInteger)port error:(NSError **)error;
/// + (void)stop;
enum CarnetsCore {

    /// Start the embedded Jupyter server bound to 127.0.0.1:port.
    /// - Parameters:
    ///   - root: A writable directory (e.g. Documents/) used as HOME/Jupyter dirs.
    ///   - port: TCP port to bind (default 8888).
    /// - Returns: Base URL of the server (e.g. http://127.0.0.1:8888).
    @discardableResult
    static func startLocalJupyterServer(root: URL, port: Int = 8888) throws -> URL {
        #if os(visionOS)
        // Keep behavior explicit: we don't embed the server on visionOS.
        throw NSError(domain: "CarnetsCore",
                      code: -1000,
                      userInfo: [NSLocalizedDescriptionKey: "Embedded Jupyter is disabled on visionOS"])
        #else
        // Ensure expected writable dirs exist
        let jupyterDir = root.appendingPathComponent(".jupyter", isDirectory: true)
        let ipyDir     = root.appendingPathComponent(".ipython", isDirectory: true)
        try FileManager.default.createDirectory(at: root,       withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: jupyterDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: ipyDir,     withIntermediateDirectories: true)

        // Minimal environment Carnets/Jupyter commonly expect
        setenv("HOME", root.path, 1)
        setenv("JUPYTER_DATA_DIR", jupyterDir.path, 1)
        setenv("IPYTHONDIR", ipyDir.path, 1)
        // If your fork needs more (e.g., PYTHONHOME/PYTHONPATH), set them here.

        // Invoke the Obj-C launcher (implemented in CarnetsLauncher.m)
        var nsError: NSError?
        let ok = CarnetsLauncher.startAtPath(root.path, port: port, error: &nsError)
        if !ok {
            throw nsError ?? NSError(domain: "CarnetsCore",
                                     code: -1,
                                     userInfo: [NSLocalizedDescriptionKey: "Failed to start Carnets embedded server"])
        }

        let url = URL(string: "http://127.0.0.1:\(port)")!
        _isRunning = true
        _currentURL = url
        return url
        #endif
    }

    /// Request a graceful stop (if your launcher supports it).
    static func stopLocalJupyterServer() {
        #if !os(visionOS)
        CarnetsLauncher.stop()
        _isRunning = false
        // keep _currentURL so the UI can show last-known endpoint; clear if you prefer
        #endif
    }

    /// Best-effort state flag (updated when we call start/stop).
    static var isRunning: Bool { _isRunning }

    /// Last URL returned by `startLocalJupyterServer`, if any.
    static var currentURL: URL? { _currentURL }

    // MARK: - Private state
    private static var _isRunning: Bool = false
    private static var _currentURL: URL?
}
