import Foundation

enum UnitOfMeasure: String, Codable, CaseIterable, Identifiable {
    case each = "Each"
    case box = "Box"
    case caseUnit = "Case"
    case pack = "Pack"
    case bottle = "Bottle"
    case bag = "Bag"
    case roll = "Roll"
    case gallon = "Gallon"
    case liter = "Liter"
    case pound = "Pound"
    case ounce = "Ounce"
    case gram = "Gram"
    case kilogram = "Kilogram"
    case dozen = "Dozen"
    case pair = "Pair"
    case set = "Set"

    var id: String { rawValue }

    var abbreviation: String {
        switch self {
        case .each: return "ea"
        case .box: return "box"
        case .caseUnit: return "cs"
        case .pack: return "pk"
        case .bottle: return "btl"
        case .bag: return "bag"
        case .roll: return "roll"
        case .gallon: return "gal"
        case .liter: return "L"
        case .pound: return "lb"
        case .ounce: return "oz"
        case .gram: return "g"
        case .kilogram: return "kg"
        case .dozen: return "dz"
        case .pair: return "pr"
        case .set: return "set"
        }
    }
}
