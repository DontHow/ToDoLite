import Foundation

struct HolidayInfo: Codable {
    let date: String
    let name: String
    let isOffDay: Bool
}

actor HolidayService {
    static let shared = HolidayService()

    private var memoryCache: [Int: [String: HolidayInfo]] = [:]
    private let defaults = UserDefaults.standard
    private let cachePrefix = "holiday_cache_"
    private let cacheDatePrefix = "holiday_cache_date_"
    private let cacheDuration: TimeInterval = 7 * 24 * 3600

    func load(year: Int) async -> [String: HolidayInfo] {
        if let cached = memoryCache[year] {
            return cached
        }

        if let cached = loadFromDisk(year: year) {
            memoryCache[year] = cached
            return cached
        }

        guard let url = URL(string: "https://api.jiejiariapi.com/v1/holidays/\(year)") else {
            return [:]
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let result = try JSONDecoder().decode([String: HolidayInfo].self, from: data)
            memoryCache[year] = result
            saveToDisk(year: year, data: result)
            return result
        } catch {
            return [:]
        }
    }

    private func loadFromDisk(year: Int) -> [String: HolidayInfo]? {
        let dateKey = "\(cacheDatePrefix)\(year)"
        let dataKey = "\(cachePrefix)\(year)"
        guard let cachedDate = defaults.object(forKey: dateKey) as? Date,
              Date().timeIntervalSince(cachedDate) < cacheDuration,
              let data = defaults.data(forKey: dataKey),
              let result = try? JSONDecoder().decode([String: HolidayInfo].self, from: data) else {
            return nil
        }
        return result
    }

    private func saveToDisk(year: Int, data: [String: HolidayInfo]) {
        let dateKey = "\(cacheDatePrefix)\(year)"
        let dataKey = "\(cachePrefix)\(year)"
        if let encoded = try? JSONEncoder().encode(data) {
            defaults.set(encoded, forKey: dataKey)
            defaults.set(Date(), forKey: dateKey)
        }
    }
}
