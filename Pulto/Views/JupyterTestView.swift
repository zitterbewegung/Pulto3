import SwiftUI

struct JupyterTestView: View {
    @StateObject private var jupyterClient = EnhancedJupyterClient()
    @State private var codeToExecute = "import numpy as np\nprint('Hello from Jupyter!')"
    @State private var executionResults: [String] = []
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Jupyter Integration Test")
                .font(.title)
                .padding()
            
            // Connection Status
            HStack {
                Circle()
                    .fill(jupyterClient.isConnected ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                
                Text(jupyterClient.isConnected ? "Connected" : "Disconnected")
                    .fontWeight(.medium)
                
                Spacer()
                
                Button(jupyterClient.isConnected ? "Disconnect" : "Connect") {
                    if jupyterClient.isConnected {
                        jupyterClient.disconnectFromKernel()
                    } else {
                        connectToJupyter()
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            // Code Editor
            VStack(alignment: .leading) {
                Text("Python Code:")
                    .font(.headline)
                
                TextEditor(text: $codeToExecute)
                    .font(.monospaced(.body)())
                    .frame(height: 120)
                    .border(Color.gray.opacity(0.3))
            }
            .padding()
            
            // Execution Controls
            HStack(spacing: 15) {
                Button("Execute Code") {
                    executeCode()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!jupyterClient.isConnected)
                
                Button("Execute Batch") {
                    executeBatchCode()
                }
                .buttonStyle(.bordered)
                .disabled(!jupyterClient.isConnected)
                
                Button("Clear Results") {
                    executionResults.removeAll()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            
            // Execution Results
            VStack(alignment: .leading) {
                Text("Execution Results:")
                    .font(.headline)
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(jupyterClient.executionResults.values), id: \.messageId) { result in
                            ExecutionResultView(result: result)
                        }
                    }
                }
                .frame(height: 200)
                .background(Color.black.opacity(0.05))
                .cornerRadius(8)
            }
            .padding()
        }
        .padding()
    }
    
    private func connectToJupyter() {
        Task {
            try await jupyterClient.connectToKernel(serverURL: "http://localhost:8888")
        }
    }
    
    private func executeCode() {
        Task {
            do {
                let result = try await jupyterClient.executeCode(codeToExecute)
                await MainActor.run {
                    executionResults.append("Executed: \(result.code)")
                }
            } catch {
                await MainActor.run {
                    executionResults.append("Error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func executeBatchCode() {
        let batchCode = [
            "import matplotlib.pyplot as plt",
            "import numpy as np",
            "x = np.linspace(0, 10, 100)",
            "y = np.sin(x)",
            "plt.plot(x, y)",
            "plt.title('Sine Wave')",
            "plt.show()"
        ]
        
        Task {
            do {
                let results = try await jupyterClient.executeBatch(batchCode)
                await MainActor.run {
                    executionResults.append("Batch executed: \(results.count) commands")
                }
            } catch {
                await MainActor.run {
                    executionResults.append("Batch error: \(error.localizedDescription)")
                }
            }
        }
    }
}

struct ExecutionResultView: View {
    let result: EnhancedJupyterClient.ExecutionResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("[\(result.executionCount ?? 0)]")
                    .font(.caption)
                    .fontWeight(.bold)
                
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(statusColor)
                
                Spacer()
                
                Text(result.timestamp.formatted(.dateTime.hour().minute().second()))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(result.code)
                .font(.monospaced(.caption)())
                .foregroundColor(.primary)
            
            if !result.outputs.isEmpty {
                ForEach(Array(result.outputs.enumerated()), id: \.offset) { _, output in
                    if let textOutput = output.content["data"] as? [String: String],
                       let plainText = textOutput["text/plain"] {
                        Text(plainText)
                            .font(.monospaced(.caption)())
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(4)
    }
    
    private var statusText: String {
        switch result.status {
        case .queued: return "Queued"
        case .running: return "Running"
        case .completed: return "Completed"
        case .error(let message): return "Error: \(message)"
        }
    }
    
    private var statusColor: Color {
        switch result.status {
        case .queued: return .orange
        case .running: return .blue
        case .completed: return .green
        case .error: return .red
        }
    }
}