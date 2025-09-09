//
//  CarnetsCore.swift
//  
//
//  Created by Joshua Herman on 9/9/25.
//


import Foundation

public enum CarnetsCore {
    /// Start the embedded Jupyter server bound to 127.0.0.1:port.
    /// - Returns: The server base URL you can give to JupyterKit/NotebookManager.
    @discardableResult
    public static func startLocalJupyterServer(root: URL, port: Int = 8888) throws -> URL {
        // IMPORTANT:
        // This function must initialize the embedded Python runtime and
        // launch Jupyter NotebookApp inside the process (Tornado server).
        //
        // Your fork already contains the bootstrap + launcher logic.
        // Wire that code here. For now, we stub the call and return the URL.
        //
        // e.g., something like:
        // PythonBootstrap.initializeIfNeeded(withSitePackagesAt: ...)
        // JupyterLauncher.launch(root: root, port: port)
        //
        // Make sure you set HOME, JUPYTER_DATA_DIR, etc., if your fork requires.
        setenv("HOME", root.path, 1)
        setenv("JUPYTER_DATA_DIR", root.appendingPathComponent(".jupyter").path, 1)
        setenv("IPYTHONDIR", root.appendingPathComponent(".ipython").path, 1)

        // TODO: call into your fork’s launcher entrypoint.
        // For example, if you add a tiny ObjC/Swift helper in Carnets that exposes:
        // CarnetsLauncher.startJupyter(at:root.path, port: port)
        //
        // When that’s wired, remove the warning below.
        NSLog("[CarnetsCore] WARNING: startLocalJupyterServer() is stubbed — wire your fork’s launcher here.")

        return URL(string: "http://127.0.0.1:\(port)")!
    }

    public static func stopLocalJupyterServer() {
        // TODO: If your fork exposes a stop API, call it here.
        NSLog("[CarnetsCore] WARNING: stopLocalJupyterServer() is stubbed — wire your fork’s stop call here.")
    }
}