nonisolated enum UnitOfMeasure: String, CaseIterable, Identifiable {
    case each, box, `case`, pack, bottle, bag, roll, gallon, liter, pound, ounce, gram, kilogram, dozen, pair, set

    var id: String { rawValue }
    var label: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }

    var abbreviation: String {
        switch self {
        case .each: "ea"
        case .box: "bx"
        case .case: "cs"
        case .pack: "pk"
        case .bottle: "btl"
        case .bag: "bag"
        case .roll: "rl"
        case .gallon: "gal"
        case .liter: "L"
        case .pound: "lb"
        case .ounce: "oz"
        case .gram: "g"
        case .kilogram: "kg"
        case .dozen: "dz"
        case .pair: "pr"
        case .set: "set"
        }
    }
}
