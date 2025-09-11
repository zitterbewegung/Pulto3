import Foundation

/// Embedded Jupyter (Carnets) feature flagging
/// - Compile-time: Define CARNETS_EMBEDDED in Build Settings -> Other Swift Flags (-D CARNETS_EMBEDDED)
/// - Runtime: Set UserDefaults key "EnableEmbeddedJupyter" (Bool) to true to allow starting the embedded server.

/// Thin Swift façade your app calls to start/stop the embedded Carnets (Jupyter) server.
/// Requires an Objective-C bridge named `CarnetsLauncher` with:
/// + (BOOL)startAtPath:(NSString *)root port:(NSInteger)port error:(NSError **)error;
/// + (void)stop;
enum CarnetsCore {

    /// UserDefaults key to enable embedded Jupyter at runtime
    private static let featureFlagKey = "EnableEmbeddedJupyter"

    /// Returns true if embedded Jupyter is enabled by both compile-time and runtime flags
    static func isEmbeddedEnabled() -> Bool {
        #if CARNETS_EMBEDDED
        return UserDefaults.standard.bool(forKey: featureFlagKey)
        #else
        return false
        #endif
    }

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
        // Feature flag gate: compile-time and runtime must both allow embedded Jupyter
        #if !CARNETS_EMBEDDED
        throw NSError(domain: "CarnetsCore",
                      code: -2001,
                      userInfo: [NSLocalizedDescriptionKey: "Embedded Jupyter disabled by feature flag (CARNETS_EMBEDDED not defined)"])
        #else
        guard isEmbeddedEnabled() else {
            throw NSError(domain: "CarnetsCore",
                          code: -2002,
                          userInfo: [NSLocalizedDescriptionKey: "Embedded Jupyter disabled by runtime flag (EnableEmbeddedJupyter=false)"])
        }
        #endif

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

        // Optional: Configure embedded Python runtime paths from bundled resources
        if let resourcesURL = Bundle.main.url(forResource: "CarnetsResources", withExtension: "bundle") {
            let pythonRoot = resourcesURL.appendingPathComponent("python", isDirectory: true)
            // Set PYTHONHOME to the bundled python root if it exists
            if FileManager.default.fileExists(atPath: pythonRoot.path) {
                setenv("PYTHONHOME", pythonRoot.path, 1)

                // Prefer site-packages alongside stdlib
                let sitePackages = pythonRoot.appendingPathComponent("site-packages", isDirectory: true)
                if FileManager.default.fileExists(atPath: sitePackages.path) {
                    let pyPath = "\(pythonRoot.path):\(sitePackages.path)"
                    setenv("PYTHONPATH", pyPath, 1)
                } else {
                    setenv("PYTHONPATH", pythonRoot.path, 1)
                }
            }
        }

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
        #if CARNETS_EMBEDDED
        guard isEmbeddedEnabled() else { return }
        CarnetsLauncher.stop()
        _isRunning = false
        #else
        // No-op when embedded Jupyter is disabled at compile time
        #endif
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

