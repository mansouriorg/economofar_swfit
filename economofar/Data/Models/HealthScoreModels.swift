import Foundation

// MARK: - API response of /api/health-score

struct HealthComponent: Decodable, Identifiable, Equatable {
    let key: String
    let title: String
    let score: Int?
    let weight: Int
    let detail: String
    let tip: String?

    var id: String {
        key
    }

    private enum CodingKeys: String, CodingKey {
        case key
        case title
        case score
        case weight
        case detail
        case tip
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        key = try container.decode(String.self, forKey: .key)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? key
        score = try container.decodeIfPresent(Int.self, forKey: .score)
        weight = try container.decodeIfPresent(Int.self, forKey: .weight) ?? 0
        detail = try container.decodeIfPresent(String.self, forKey: .detail) ?? ""
        tip = try container.decodeIfPresent(String.self, forKey: .tip)
    }
}

struct HealthScoreReport: Decodable, Equatable {
    let score: Int?
    let level: String
    let availableComponents: Int
    let components: [HealthComponent]
    let tips: [String]

    private enum CodingKeys: String, CodingKey {
        case score
        case level
        case availableComponents
        case components
        case tips
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        score = try container.decodeIfPresent(Int.self, forKey: .score)
        level = try container.decodeIfPresent(String.self, forKey: .level) ?? "none"
        components = try container.decodeIfPresent([HealthComponent].self, forKey: .components) ?? []
        tips = try container.decodeIfPresent([String].self, forKey: .tips) ?? []

        availableComponents = try container.decodeIfPresent(Int.self, forKey: .availableComponents)
            ?? components.filter { $0.score != nil }.count
    }
}

enum HealthLevel: String {
    case excellent
    case good
    case watch
    case fragile
    case unknown = "none"
}

extension HealthScoreReport {
    var levelValue: HealthLevel {
        HealthLevel(rawValue: level) ?? .unknown
    }

    /// Score between 0 and 1 (0 while there is no score).
    var fraction: Double {
        guard let score else { return 0 }
        return Double(min(max(score, 0), 100)) / 100
    }
}
