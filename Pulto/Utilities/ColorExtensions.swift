//
//  ColorExtensions.swift
//  Pulto3
//
//  Shared color utilities to eliminate duplication
//

import SwiftUI

// MARK: - SwiftUI Color Extensions
extension Color {
    func toString() -> String {
        switch self {
        case .blue: return "blue"
        case .green: return "green"
        case .purple: return "purple"
        case .orange: return "orange"
        case .red: return "red"
        case .yellow: return "yellow"
        case .pink: return "pink"
        case .cyan: return "cyan"
        case .mint: return "mint"
        case .indigo: return "indigo"
        case .teal: return "teal"
        case .brown: return "brown"
        case .gray: return "gray"
        case .black: return "black"
        case .white: return "white"
        case .clear: return "clear"
        default: return "blue" // fallback
        }
    }
    
    static func fromString(_ string: String) -> Color {
        switch string.lowercased() {
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "orange": return .orange
        case "red": return .red
        case "yellow": return .yellow
        case "pink": return .pink
        case "cyan": return .cyan
        case "mint": return .mint
        case "indigo": return .indigo
        case "teal": return .teal
        case "brown": return .brown
        case "gray": return .gray
        case "black": return .black
        case "white": return .white
        case "clear": return .clear
        default: return .blue // fallback
        }
    }
}

// MARK: - UIColor Extensions
extension UIColor {
    convenience init?(hex: String) {
        let r, g, b: CGFloat
        
        if hex.hasPrefix("#") {
            let start = hex.index(hex.startIndex, offsetBy: 1)
            let hexColor = String(hex[start...])
            
            if hexColor.count == 6 {
                let scanner = Scanner(string: hexColor)
                var hexNumber: UInt64 = 0
                
                if scanner.scanHexInt64(&hexNumber) {
                    r = CGFloat((hexNumber & 0xff0000) >> 16) / 255
                    g = CGFloat((hexNumber & 0x00ff00) >> 8) / 255
                    b = CGFloat(hexNumber & 0x0000ff) / 255
                    
                    self.init(red: r, green: g, blue: b, alpha: 1.0)
                    return
                }
            }
        }
        
        // Default color names
        switch hex.lowercased() {
        case "red": self.init(red: 1, green: 0, blue: 0, alpha: 1)
        case "green": self.init(red: 0, green: 1, blue: 0, alpha: 1)
        case "blue": self.init(red: 0, green: 0, blue: 1, alpha: 1)
        case "yellow": self.init(red: 1, green: 1, blue: 0, alpha: 1)
        case "orange": self.init(red: 1, green: 0.5, blue: 0, alpha: 1)
        case "purple": self.init(red: 0.5, green: 0, blue: 0.5, alpha: 1)
        case "cyan": self.init(red: 0, green: 1, blue: 1, alpha: 1)
        case "magenta": self.init(red: 1, green: 0, blue: 1, alpha: 1)
        case "white": self.init(red: 1, green: 1, blue: 1, alpha: 1)
        case "black": self.init(red: 0, green: 0, blue: 0, alpha: 1)
        case "gray", "grey": self.init(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        case "lightblue": self.init(red: 0.7, green: 0.85, blue: 1, alpha: 1)
        case "teal": self.init(red: 0, green: 0.5, blue: 0.5, alpha: 1)
        default: return nil
        }
    }
}