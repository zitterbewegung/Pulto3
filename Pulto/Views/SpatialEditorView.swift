import SwiftUI
import Charts

// MARK: - Data Models

struct ToyShape: Identifiable {
    var color: String
    var type: String
    var count: Double
    var id = UUID()
}

let stackedBarData: [ToyShape] = [
    .init(color: "Green", type: "Cube", count: 2),
    .init(color: "Green", type: "Sphere", count: 0),
    .init(color: "Green", type: "Pyramid", count: 1),
    .init(color: "Purple", type: "Cube", count: 1),
    .init(color: "Purple", type: "Sphere", count: 1),
    .init(color: "Purple", type: "Pyramid", count: 1),
    .init(color: "Pink", type: "Cube", count: 1),
    .init(color: "Pink", type: "Sphere", count: 2),
    .init(color: "Pink", type: "Pyramid", count: 0),
    .init(color: "Yellow", type: "Cube", count: 1),
    .init(color: "Yellow", type: "Sphere", count: 1),
    .init(color: "Yellow", type: "Pyramid", count: 2)
]

// MARK: - ViewModel

@MainActor // Ensures all code runs on the main thread
class SpatialEditorViewModel: ObservableObject {
    // Window A States
    @Published var windowAOffset: CGSize = .zero
    @Published var windowARotation: Angle = .degrees(0)

    // Window B States
    @Published var windowBOffset: CGSize = CGSize(width: -500, height: 0) // Start off-screen to the left
    @Published var windowBRotation: Angle = .degrees(0)

    // Control Window States
    @Published var controlOffset: CGSize = CGSize(width: 0, height: 0)
    @Published var controlRotation: Angle = .degrees(0)

    // Visibility States
    @Published var showWindowA: Bool = true
    @Published var showWindowB: Bool = false

    // Window Dimensions and Settings
    let windowWidth: CGFloat = 400
    let windowHeight: CGFloat = 300
    let gap: CGFloat = 20
    let animationDuration: Double = 0.5

    init() {
        loadWindowStates()
    }

    // MARK: - Control Functions

    func showSpatialWindowA() {
        withAnimation(.easeInOut(duration: animationDuration)) {
            showWindowA = true
        }
        saveWindowStates()
    }

    func hideWindowA() {
        withAnimation(.easeInOut(duration: animationDuration)) {
            showWindowA = false
        }
        saveWindowStates()
    }

    func showSpatialWindowB() {
        withAnimation(.easeInOut(duration: animationDuration)) {
            showWindowB = true
            snapWindowBToLeftOfWindowA()
        }
        saveWindowStates()
    }

    func hideWindowB() {
        withAnimation(.easeInOut(duration: animationDuration)) {
            showWindowB = false
            windowBOffset = CGSize(width: -500, height: 0) // Move Window B off-screen
        }
        saveWindowStates()
    }

    /// Snaps Window B to the left of Window A with animation.
    func snapWindowBToLeftOfWindowA() {
        withAnimation(.easeInOut(duration: animationDuration)) {
            let offsetX = -windowWidth - gap
            windowBOffset = CGSize(width: offsetX, height: 0)
        }
    }

    // MARK: - State Persistence

    /// Loads the window states from UserDefaults.
    func loadWindowStates() {
        // Window A
        let windowAOffsetWidth = UserDefaults.standard.object(forKey: "windowAOffsetWidth") as? CGFloat ?? 0
        let windowAOffsetHeight = UserDefaults.standard.object(forKey: "windowAOffsetHeight") as? CGFloat ?? 0
        windowAOffset = CGSize(width: windowAOffsetWidth, height: windowAOffsetHeight)

        let rotationA = UserDefaults.standard.double(forKey: "windowARotation")
        windowARotation = .degrees(rotationA)

        // Window B
        let windowBOffsetWidth = UserDefaults.standard.object(forKey: "windowBOffsetWidth") as? CGFloat ?? -500
        let windowBOffsetHeight = UserDefaults.standard.object(forKey: "windowBOffsetHeight") as? CGFloat ?? 0
        windowBOffset = CGSize(width: windowBOffsetWidth, height: windowBOffsetHeight)

        let rotationB = UserDefaults.standard.double(forKey: "windowBRotation")
        windowBRotation = .degrees(rotationB)

        // Control Window
        let controlOffsetWidth = UserDefaults.standard.object(forKey: "controlOffsetWidth") as? CGFloat ?? 0
        let controlOffsetHeight = UserDefaults.standard.object(forKey: "controlOffsetHeight") as? CGFloat ?? 0
        controlOffset = CGSize(width: controlOffsetWidth, height: controlOffsetHeight)

        let controlRotationValue = UserDefaults.standard.double(forKey: "controlRotation")
        controlRotation = .degrees(controlRotationValue)

        // Visibility States
        showWindowA = UserDefaults.standard.object(forKey: "showWindowA") as? Bool ?? true
        showWindowB = UserDefaults.standard.object(forKey: "showWindowB") as? Bool ?? false

        print("Loaded states - WindowA: \(windowAOffset), WindowB: \(windowBOffset), Control: \(controlOffset)")
    }

    /// Saves the window states to UserDefaults.
    func saveWindowStates() {
        // Window A
        UserDefaults.standard.set(windowAOffset.width, forKey: "windowAOffsetWidth")
        UserDefaults.standard.set(windowAOffset.height, forKey: "windowAOffsetHeight")
        UserDefaults.standard.set(windowARotation.degrees, forKey: "windowARotation")

        // Window B
        UserDefaults.standard.set(windowBOffset.width, forKey: "windowBOffsetWidth")
        UserDefaults.standard.set(windowBOffset.height, forKey: "windowBOffsetHeight")
        UserDefaults.standard.set(windowBRotation.degrees, forKey: "windowBRotation")

        // Control Window
        UserDefaults.standard.set(controlOffset.width, forKey: "controlOffsetWidth")
        UserDefaults.standard.set(controlOffset.height, forKey: "controlOffsetHeight")
        UserDefaults.standard.set(controlRotation.degrees, forKey: "controlRotation")

        // Visibility States
        UserDefaults.standard.set(showWindowA, forKey: "showWindowA")
        UserDefaults.standard.set(showWindowB, forKey: "showWindowB")

        print("Saved states - WindowA: \(windowAOffset), WindowB: \(windowBOffset), Control: \(controlOffset)")
    }

    // MARK: - Debug Functions

    /// Resets all saved positions to default values
    func resetPositions() {
        windowAOffset = .zero
        windowBOffset = CGSize(width: -500, height: 0)
        controlOffset = .zero
        windowARotation = .degrees(0)
        windowBRotation = .degrees(0)
        controlRotation = .degrees(0)
        showWindowA = true
        showWindowB = false
        saveWindowStates()
    }
}

// MARK: - SpatialEditorView

struct SpatialEditorView: View {
    @StateObject private var viewModel = SpatialEditorViewModel()

    // Gesture States
    @State private var draggingOffsetA: CGSize = .zero
    @State private var draggingOffsetB: CGSize = .zero
    @State private var draggingOffsetControl: CGSize = .zero

    var body: some View {
        ZStack {
            // Window A
            if viewModel.showWindowA {
                WindowAView()
                    .frame(width: viewModel.windowWidth, height: viewModel.windowHeight)
                    .background(Color.blue.opacity(0.8))
                    .cornerRadius(15)
                    .offset(x: viewModel.windowAOffset.width + draggingOffsetA.width,
                            y: viewModel.windowAOffset.height + draggingOffsetA.height)
                    .rotationEffect(viewModel.windowARotation)
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                draggingOffsetA = gesture.translation
                            }
                            .onEnded { gesture in
                                viewModel.windowAOffset.width += gesture.translation.width
                                viewModel.windowAOffset.height += gesture.translation.height
                                draggingOffsetA = .zero
                                viewModel.saveWindowStates()
                            }
                    )
                    .simultaneousGesture(
                        RotationGesture()
                            .onChanged { angle in
                                viewModel.windowARotation = angle
                            }
                            .onEnded { angle in
                                viewModel.windowARotation = angle
                                viewModel.saveWindowStates()
                            }
                    )
                    .zIndex(1) // Ensure Window A is on top if overlapping occurs
            }

            // Window B
            if viewModel.showWindowB {
                WindowBView()
                    .frame(width: viewModel.windowWidth, height: viewModel.windowHeight)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(15)
                    .offset(x: viewModel.windowBOffset.width + draggingOffsetB.width,
                            y: viewModel.windowBOffset.height + draggingOffsetB.height)
                    .rotationEffect(viewModel.windowBRotation)
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                draggingOffsetB = gesture.translation
                            }
                            .onEnded { gesture in
                                viewModel.windowBOffset.width += gesture.translation.width
                                viewModel.windowBOffset.height += gesture.translation.height
                                draggingOffsetB = .zero
                                viewModel.saveWindowStates()
                            }
                    )
                    .simultaneousGesture(
                        RotationGesture()
                            .onChanged { angle in
                                viewModel.windowBRotation = angle
                            }
                            .onEnded { angle in
                                viewModel.windowBRotation = angle
                                viewModel.saveWindowStates()
                            }
                    )
                    .zIndex(0) // Behind Window A
            }

            // Control Window
            let shouldHide = false
            ControlWindowView(viewModel: viewModel)
                .frame(width: 300, height: 200)
                .background(Color.gray.opacity(0.8))
                .cornerRadius(15)
                .offset(x: viewModel.controlOffset.width + draggingOffsetControl.width,
                        y: viewModel.controlOffset.height + draggingOffsetControl.height)
                .rotationEffect(viewModel.controlRotation)
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            draggingOffsetControl = gesture.translation
                        }
                        .onEnded { gesture in
                            viewModel.controlOffset.width += gesture.translation.width
                            viewModel.controlOffset.height += gesture.translation.height
                            draggingOffsetControl = .zero
                            viewModel.saveWindowStates()
                        }
                )
                .simultaneousGesture(
                    RotationGesture()
                        .onChanged { angle in
                            viewModel.controlRotation = angle
                        }
                        .onEnded { angle in
                            viewModel.controlRotation = angle
                            viewModel.saveWindowStates()
                        }
                )
                .zIndex(2) // Always on top
                .opacity(shouldHide ? 0 : 1)
        }
        .edgesIgnoringSafeArea(.all) // Optional: Extend views to edges
    }
}

// MARK: - Window A View

struct WindowAView: View {
    var body: some View {
        VStack {
            Text("Window A")
                .font(.largeTitle)
                .padding()

            Chart {
                ForEach(stackedBarData) { shape in
                    BarMark(
                        x: .value("Shape Type", shape.type),
                        y: .value("Total Count", shape.count)
                    )
                    .foregroundStyle(by: .value("Shape Color", shape.color))
                }
            }
            .padding()
        }
    }
}

// MARK: - Window B View

struct WindowBView: View {
    var body: some View {
        VStack {
            Text("Window B")
                .font(.largeTitle)
                .padding()

            // Add content specific to Window B here
            
            //Text("Additional Content for Window B")
                .padding()
            // PlotlyView() // Commented out as it's not defined
        }
    }
}

// MARK: - Control Window View

struct ControlWindowView: View {
    @ObservedObject var viewModel: SpatialEditorViewModel

    var body: some View {
        VStack(spacing: 15) {
            Text("Control Panel")
                .font(.headline)
                .padding(.top)

            // Toggle Window A
            Button(action: {
                if viewModel.showWindowA {
                    viewModel.hideWindowA()
                } else {
                    viewModel.showSpatialWindowA()
                }
            }) {
                Text(viewModel.showWindowA ? "Hide Window A" : "Show Window A")
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity)
                    .background(viewModel.showWindowA ? Color.red : Color.green)
                    .cornerRadius(8)
            }

            // Toggle Window B
            Button(action: {
                if viewModel.showWindowB {
                    viewModel.hideWindowB()
                } else {
                    viewModel.showSpatialWindowB()
                }
            }) {
                Text(viewModel.showWindowB ? "Hide Window B" : "Show Window B")
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity)
                    .background(viewModel.showWindowB ? Color.red : Color.green)
                    .cornerRadius(8)
            }

            // Reset Positions Button (for debugging)
            Button(action: {
                viewModel.resetPositions()
            }) {
                Text("Reset Positions")
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color.orange)
                    .cornerRadius(8)
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Preview Provider
#Preview {
    SpatialEditorView()
        .frame(width: 600, height: 800)
}
