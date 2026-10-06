import Foundation

enum ToolsOption {
    static let all: [(value: String, label: String)] = [
        ("none", "No tools needed"),
        ("provided", "Tools provided"),
        ("bring_own", "Bring your own tools"),
    ]

    static func label(_ raw: String?) -> String? {
        switch raw {
        case "provided": return "Tools provided"
        case "bring_own": return "Bring your own tools"
        case "none": return "No tools needed"
        default: return nil
        }
    }
}
