import SwiftUI

struct StreamingTestView: View {
    @StateObject private var streamingManager = RealTimeStreamingManager()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Real-time Streaming Test")
                .font(.title)
                .padding()
            
            // Status Display
            VStack(spacing: 10) {
                HStack {
                    Text("Status:")
                    Text(statusText)
                        .foregroundColor(statusColor)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Active Streams:")
                    Text("\(streamingManager.dataStreams.count)")
                }
                
                HStack {
                    Text("Processed Points:")
                    Text("\(streamingManager.processedDataPoints)")
                }
                
                HStack {
                    Text("Total Points:")
                    Text("\(streamingManager.totalDataPoints)")
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            // Controls
            HStack(spacing: 20) {
                Button(streamingManager.isStreaming ? "Stop Streaming" : "Start Streaming") {
                    if streamingManager.isStreaming {
                        streamingManager.stopStreaming()
                    } else {
                        startTestStreaming()
                    }
                }
                .buttonStyle(.borderedProminent)
                
                if streamingManager.isStreaming {
                    Button(streamingManager.streamingStatus == .paused ? "Resume" : "Pause") {
                        if streamingManager.streamingStatus == .paused {
                            streamingManager.resumeStreaming()
                        } else {
                            streamingManager.pauseStreaming()
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            
            // Stream Details
            if !streamingManager.dataStreams.isEmpty {
                Text("Active Data Streams")
                    .font(.headline)
                    .padding(.top)
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(streamingManager.dataStreams.values), id: \.id) { stream in
                            HStack {
                                Circle()
                                    .fill(stream.isActive ? Color.green : Color.red)
                                    .frame(width: 8, height: 8)
                                
                                VStack(alignment: .leading) {
                                    Text(stream.name)
                                        .fontWeight(.medium)
                                    Text("Frequency: \(stream.frequency, specifier: "%.1f") Hz")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text("Buffer: \(stream.buffer.size)/\(stream.buffer.capacity)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .frame(height: 150)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
            }
        }
        .padding()
    }
    
    private var statusText: String {
        switch streamingManager.streamingStatus {
        case .idle: return "Idle"
        case .connecting: return "Connecting..."
        case .streaming: return "Streaming"
        case .paused: return "Paused"
        case .error(let message): return "Error: \(message)"
        }
    }
    
    private var statusColor: Color {
        switch streamingManager.streamingStatus {
        case .idle: return .secondary
        case .connecting: return .orange
        case .streaming: return .green
        case .paused: return .yellow
        case .error: return .red
        }
    }
    
    private func startTestStreaming() {
        let configs = [
            DataStreamConfig.sensorData,
            DataStreamConfig.financialData,
            DataStreamConfig.scientificData
        ]
        
        streamingManager.startStreaming(streamConfigs: configs)
    }
}