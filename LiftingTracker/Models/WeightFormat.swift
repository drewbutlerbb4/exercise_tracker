import Foundation

/// Reading and writing weights as text. Weights are decimals with up to two
/// places, in the app-wide unit. An empty field is "no value", never 0.
enum WeightFormat {
    static let unitKey = "weightUnit"
    static let defaultUnit = "lb"

    /// "135", "2.5", "22.75"; empty for no value.
    static func string(_ weight: Double?) -> String {
        guard let weight else { return "" }
        let hundredths = (weight * 100).rounded()
        if hundredths.truncatingRemainder(dividingBy: 100) == 0 {
            return String(Int(hundredths / 100))
        }
        var text = String(format: "%.2f", hundredths / 100)
        while text.hasSuffix("0") { text.removeLast() }
        return text
    }

    /// "135 lb"; nil for no value.
    static func labelled(_ weight: Double?, unit: String) -> String? {
        guard weight != nil else { return nil }
        return "\(string(weight)) \(unit)"
    }

    /// Empty or unreadable text is no value.
    static func parse(_ text: String) -> Double? {
        let clean = text.replacingOccurrences(of: ",", with: ".")
        guard !clean.isEmpty, clean != "." else { return nil }
        return Double(clean)
    }

    /// Keeps digits and one decimal separator, at most four whole digits and two decimals.
    static func sanitize(_ text: String) -> String {
        var whole = ""
        var fraction = ""
        var separator: Character?
        for character in text {
            if character.isASCII, character.isNumber {
                if separator == nil {
                    if whole.count < 4 { whole.append(character) }
                } else if fraction.count < 2 {
                    fraction.append(character)
                }
            } else if (character == "." || character == ","), separator == nil {
                separator = character
            }
        }
        guard let separator else { return whole }
        return whole + String(separator) + fraction
    }
}

enum DateFormat {
    /// "Nov 6"
    static func short(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }

    /// "Nov 6, 2026"
    static func long(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day().year())
    }
}
