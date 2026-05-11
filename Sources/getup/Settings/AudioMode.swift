import Foundation
import SwiftUI

enum AudioMode: String, Codable, CaseIterable {
    case headphonesOnly
    case always
    case silent

    var displayName: String {
        switch self {
        case .headphonesOnly: return String(localized: "Headphones only")
        case .always:         return String(localized: "Always (any output)")
        case .silent:         return String(localized: "Silent (UI only)")
        }
    }

    /// SwiftUI `LocalizedStringKey` form, used when we need to resolve the label against
    /// a specific `Bundle` (e.g. wizard step 2 rendering in the just-picked language).
    var displayKey: LocalizedStringKey {
        switch self {
        case .headphonesOnly: return "Headphones only"
        case .always:         return "Always (any output)"
        case .silent:         return "Silent (UI only)"
        }
    }
}
