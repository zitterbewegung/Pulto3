import Foundation
import JupyterKit

final class PultoSettings: ObservableObject {
    @Published var preferredUI: JupyterUI {
        didSet { UserDefaults.standard.set(preferredUI.rawValue, forKey: "preferredUI") }
    }
    init() {
        if let raw = UserDefaults.standard.string(forKey: "preferredUI"),
           let v = JupyterUI(rawValue: raw) {
            preferredUI = v
        } else {
            preferredUI = .lab
        }
    }
}
