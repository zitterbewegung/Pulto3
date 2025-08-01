import SwiftUI
import RealityKit
import Charts

                case .charts:
                    ChartGeneratorView(windowID: id)
                        .environmentObject(windowManager)

// ... existing code ...