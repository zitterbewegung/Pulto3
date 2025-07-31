enum ServerStatus {
        case online
        case offline
        case unknown
        case checking
        
        var color: Color {
            switch self {
            case .online: return .green
            case .offline: return .red
            case .unknown: return .orange
            case .checking: return .blue
            }
        }
        
        var icon: String {
            switch self {
            case .online: return "checkmark.circle.fill"
            case .offline: return "wifi.slash"  // CHANGE: Use offline icon
            case .unknown: return "questionmark.circle.fill"
            case .checking: return "arrow.clockwise.circle.fill"
            }
        }
        
        var description: String {
            switch self {
            case .online: return "Online"
            case .offline: return "Offline"
            case .unknown: return "Unknown"
            case .checking: return "Checking..."
            }
        }
    }