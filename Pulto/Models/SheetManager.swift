//
//  SheetManager.swift
//  Pulto
//
//  Single sheet management system - prevents nested sheets
//

import SwiftUI

// MARK: - Sheet Types
enum SheetType: String, CaseIterable {
    case workspaceDialog = "workspace"
    case templateGallery = "templates"
    case notebookImport = "notebook"
    case classifierSheet = "classifier"
    case settings = "settings"
    case appleSignIn = "signin"
    case welcome = "welcome"
    case createProject = "create"
    case projectBrowser = "browser"
    case dataImport = "data"
    case chartRecommender = "chart"
    case userProfile = "profile"
    case jupyterConnection = "jupyter"
    case activeWindows = "activeWindows"
    
    var displayName: String {
        switch self {
        case .workspaceDialog: return "Workspace Dialog"
        case .templateGallery: return "Template Gallery"
        case .notebookImport: return "Notebook Import"
        case .classifierSheet: return "File Classifier"
        case .settings: return "Settings"
        case .appleSignIn: return "Apple Sign In"
        case .welcome: return "Welcome"
        case .createProject: return "Create Project"
        case .projectBrowser: return "Project Browser"
        case .dataImport: return "Data Import"
        case .chartRecommender: return "Chart Recommender"
        case .userProfile: return "User Profile"
        case .jupyterConnection: return "Jupyter Connection"
        case .activeWindows: return "Active Windows"
        }
    }
}

// MARK: - Sheet Data Container
struct SheetData {
    let type: SheetType
    let data: AnyHashable?
    
    init(type: SheetType, data: AnyHashable? = nil) {
        self.type = type
        self.data = data
    }
}

// MARK: - Single Sheet Manager
@MainActor
class SheetManager: ObservableObject {
    @Published private var currentSheetData: SheetData?
    
    // Current active sheet
    var currentSheet: SheetType? {
        currentSheetData?.type
    }
    
    // Check if any sheet is presented
    var isPresenting: Bool {
        currentSheetData != nil
    }
    
    // Check if a specific sheet type is active
    func isSheetActive(_ type: SheetType) -> Bool {
        currentSheetData?.type == type
    }
    
    // Present a sheet (replaces any existing sheet)
    func presentSheet(_ type: SheetType, data: AnyHashable? = nil) {
        currentSheetData = SheetData(type: type, data: data)
    }
    
    // Dismiss current sheet
    func dismissSheet() {
        currentSheetData = nil
    }
    
    // Replace current sheet with new one
    func replaceSheet(with type: SheetType, data: AnyHashable? = nil) {
        currentSheetData = SheetData(type: type, data: data)
    }
    
    // Get the sheet data
    func getSheetData() -> SheetData? {
        currentSheetData
    }
    
    // Get binding for specific sheet type
    func binding(for type: SheetType) -> Binding<Bool> {
        Binding(
            get: { self.isSheetActive(type) },
            set: { isPresented in
                if isPresented {
                    self.presentSheet(type)
                } else if self.isSheetActive(type) {
                    self.dismissSheet()
                }
            }
        )
    }
    
    // Get binding for sheet presentation
    var isPresentingBinding: Binding<Bool> {
        Binding(
            get: { self.isPresenting },
            set: { isPresented in
                if !isPresented {
                    self.dismissSheet()
                }
            }
        )
    }
    
    // Helper methods that child sheets can use to navigate
    func dismissAndPresent(_ type: SheetType, data: AnyHashable? = nil) {
        // Add a small delay to ensure smooth transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.presentSheet(type, data: data)
        }
    }
    
    // Alias methods for compatibility
    func dismissAllAndPresent(_ type: SheetType, data: AnyHashable? = nil) {
        presentSheet(type, data: data)
    }
    
    func dismissAllSheets() {
        dismissSheet()
    }
}

// MARK: - Single Sheet View Modifier
struct SingleSheetModifier: ViewModifier {
    @ObservedObject var sheetManager: SheetManager
    let sheetContent: (SheetType, AnyHashable?) -> AnyView
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: sheetManager.isPresentingBinding) {
                if let sheetData = sheetManager.getSheetData() {
                    sheetContent(sheetData.type, sheetData.data)
                        .environmentObject(sheetManager) // Pass sheet manager to child views
                }
            }
    }
}

// MARK: - View Extension
extension View {
    func singleSheetManager(_ manager: SheetManager, @ViewBuilder content: @escaping (SheetType, AnyHashable?) -> AnyView) -> some View {
        modifier(SingleSheetModifier(sheetManager: manager, sheetContent: content))
    }
}

// MARK: - Sheet Navigation Helper
struct SheetNavHelper: View {
    let title: String
    let icon: String?
    let targetSheet: SheetType
    let data: AnyHashable?
    @EnvironmentObject var sheetManager: SheetManager
    
    init(_ title: String, icon: String? = nil, targetSheet: SheetType, data: AnyHashable? = nil) {
        self.title = title
        self.icon = icon
        self.targetSheet = targetSheet
        self.data = data
    }
    
    var body: some View {
        Button(action: {
            sheetManager.replaceSheet(with: targetSheet, data: data)
        }) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
        }
    }
}