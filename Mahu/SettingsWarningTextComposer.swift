import Foundation

enum SettingsWarningTextComposer {
    static func compose(primary: String?, secondary: String?) -> String? {
        let messages = [primary, secondary]
            .compactMap { $0 }
            .filter { $0.isEmpty == false }

        guard messages.isEmpty == false else {
            return nil
        }

        return messages.joined(separator: "\n\n")
    }
}
