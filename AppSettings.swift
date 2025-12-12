import Foundation
import AppKit

enum PopupSizePreset: String, CaseIterable {
    case small
    case smallMid
    case mid
    case large

    var contentSize: NSSize {
        switch self {
        case .small:
            return NSSize(width: 360, height: 520)
        case .smallMid:
            return NSSize(width: 390, height: 580)
        case .mid:
            return NSSize(width: 420, height: 640)
        case .large:
            return NSSize(width: 480, height: 740)
        }
    }

    var index: Int {
        switch self {
        case .small: return 0
        case .smallMid: return 1
        case .mid: return 2
        case .large: return 3
        }
    }

    static func from(index: Int) -> PopupSizePreset {
        switch max(0, min(3, index)) {
        case 0: return .small
        case 1: return .smallMid
        case 2: return .mid
        default: return .large
        }
    }
}

final class AppSettings: ObservableObject {
    private enum Keys {
        static let popupSizePreset = "popupSizePreset"
        static let retainPopupFocus = "retainPopupFocus"
    }

    @Published var popupSizePreset: PopupSizePreset {
        didSet {
            UserDefaults.standard.set(popupSizePreset.rawValue, forKey: Keys.popupSizePreset)
        }
    }

    @Published var retainPopupFocus: Bool {
        didSet {
            UserDefaults.standard.set(retainPopupFocus, forKey: Keys.retainPopupFocus)
        }
    }

    init() {
        if let raw = UserDefaults.standard.string(forKey: Keys.popupSizePreset),
           let preset = PopupSizePreset(rawValue: raw) {
            self.popupSizePreset = preset
        } else {
            self.popupSizePreset = .mid
        }

        if UserDefaults.standard.object(forKey: Keys.retainPopupFocus) == nil {
            self.retainPopupFocus = true
        } else {
            self.retainPopupFocus = UserDefaults.standard.bool(forKey: Keys.retainPopupFocus)
        }
    }
}
