import Foundation

/// Tab the app opens on at launch. Persisted to UserDefaults, defaults to Home.
enum StartTab: String, CaseIterable, Identifiable {
    case home
    case accounts
    case budget
    case reports

    var id: String { rawValue }

    /// Tag of the matching tab in MainTabView.
    var tabTag: Int {
        switch self {
        case .home: return 0
        case .accounts: return 1
        case .budget: return 2
        case .reports: return 3
        }
    }

    var label: String {
        switch self {
        case .home: return "Home"
        case .accounts: return "Accounts"
        case .budget: return "Budget"
        case .reports: return "Reports"
        }
    }

    static let defaultsKey = "startTab"

    static func resolved(from raw: String?) -> StartTab {
        guard let raw else { return .home }
        // Older builds offered Add Transaction as a start tab. The add flow is
        // now an action from Home, so migrate that persisted value to Home.
        if raw == "addTransaction" { return .home }
        return StartTab(rawValue: raw) ?? .home
    }

    static var persisted: StartTab {
        resolved(from: UserDefaults.standard.string(forKey: defaultsKey))
    }
}
