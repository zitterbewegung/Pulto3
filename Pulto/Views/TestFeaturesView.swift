import SwiftUI

struct TestFeaturesView: View {
    var body: some View {
        NavigationSplitView {
            List {
                NavigationLink("Point Cloud Rendering") {
                    PointCloudTestView()
                }
                
                NavigationLink("Data Processing") {
                    DataProcessingTestView()
                }
                
                NavigationLink("Real-time Streaming") {
                    StreamingTestView()
                }
                
                NavigationLink("Jupyter Integration") {
                    JupyterTestView()
                }
            }
            .navigationTitle("Test Features")
        } detail: {
            Text("Select a test from the sidebar")
                .font(.title2)
                .foregroundColor(.secondary)
        }
    }
}