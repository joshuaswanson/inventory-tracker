import Foundation

struct PhoneFormatter {
    static func format(_ phone: String) -> String {
        // Remove all non-digit characters
        let digits = phone.filter { $0.isNumber }

        // Handle different lengths
        switch digits.count {
        case 0:
            return ""
        case 1...3:
            return digits
        case 4...6:
            // Format as XXX-XXXX (local)
            let areaCode = String(digits.prefix(3))
            let remaining = String(digits.dropFirst(3))
            return "\(areaCode)-\(remaining)"
        case 7:
            // Format as XXX-XXXX (7 digit local)
            let prefix = String(digits.prefix(3))
            let line = String(digits.dropFirst(3))
            return "\(prefix)-\(line)"
        case 10:
            // Format as (XXX) XXX-XXXX (US/Canada)
            let areaCode = String(digits.prefix(3))
            let prefix = String(digits.dropFirst(3).prefix(3))
            let line = String(digits.dropFirst(6))
            return "(\(areaCode)) \(prefix)-\(line)"
        case 11 where digits.hasPrefix("1"):
            // Format as +1 (XXX) XXX-XXXX (US/Canada with country code)
            let areaCode = String(digits.dropFirst(1).prefix(3))
            let prefix = String(digits.dropFirst(4).prefix(3))
            let line = String(digits.dropFirst(7))
            return "+1 (\(areaCode)) \(prefix)-\(line)"
        default:
            // For other lengths, try to format reasonably
            if digits.count > 10 {
                // Likely has country code
                let countryCodeLength = digits.count - 10
                let countryCode = String(digits.prefix(countryCodeLength))
                let remaining = String(digits.dropFirst(countryCodeLength))
                let areaCode = String(remaining.prefix(3))
                let prefix = String(remaining.dropFirst(3).prefix(3))
                let line = String(remaining.dropFirst(6))
                return "+\(countryCode) (\(areaCode)) \(prefix)-\(line)"
            }
            return phone
        }
    }

    static func stripFormatting(_ phone: String) -> String {
        return phone.filter { $0.isNumber || $0 == "+" }
    }
}
