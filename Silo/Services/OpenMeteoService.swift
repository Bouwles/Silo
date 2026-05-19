import Foundation

struct WeatherDay: Identifiable {
    let id = UUID()
    let date: Date
    let weatherCode: Int
    let maxTempC: Double
    let minTempC: Double

    var icon: String {
        switch weatherCode {
        case 0:           return "sun.max.fill"
        case 1, 2:        return "cloud.sun.fill"
        case 3:           return "cloud.fill"
        case 45, 48:      return "cloud.fog.fill"
        case 51, 53, 55:  return "cloud.drizzle.fill"
        case 61, 63, 65:  return "cloud.rain.fill"
        case 71, 73, 75:  return "cloud.snow.fill"
        case 80, 81, 82:  return "cloud.heavyrain.fill"
        case 95, 96, 99:  return "cloud.bolt.rain.fill"
        default:          return "cloud.fill"
        }
    }
}

@MainActor
class OpenMeteoService {
    static let shared = OpenMeteoService()

    func geocode(city: String) async throws -> (Double, Double) {
        let q = city.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? city
        let url = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(q)&count=1&language=en&format=json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let resp = try JSONDecoder().decode(GeoResp.self, from: data)
        guard let r = resp.results?.first else {
            throw NSError(domain: "OpenMeteo", code: 1, userInfo: [NSLocalizedDescriptionKey: "City not found"])
        }
        return (r.latitude, r.longitude)
    }

    func fetchWeather(latitude: Double, longitude: Double, startDate: Date, endDate: Date) async throws -> [WeatherDay] {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let start = fmt.string(from: startDate)
        let end = fmt.string(from: endDate)
        let urlStr = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&daily=weathercode,temperature_2m_max,temperature_2m_min&timezone=auto&start_date=\(start)&end_date=\(end)"
        guard let url = URL(string: urlStr) else { return [] }
        let (data, _) = try await URLSession.shared.data(from: url)
        let resp = try JSONDecoder().decode(WeatherResp.self, from: data)
        return (0..<resp.daily.time.count).compactMap { i in
            guard let date = fmt.date(from: resp.daily.time[i]) else { return nil }
            return WeatherDay(date: date, weatherCode: resp.daily.weathercode[i],
                              maxTempC: resp.daily.temperature_2m_max[i],
                              minTempC: resp.daily.temperature_2m_min[i])
        }
    }
}

private struct GeoResp: Codable { let results: [GeoResult]? }
private struct GeoResult: Codable { let latitude: Double; let longitude: Double }
private struct WeatherResp: Codable { let daily: DailyData }
private struct DailyData: Codable {
    let time: [String]
    let weathercode: [Int]
    let temperature_2m_max: [Double]
    let temperature_2m_min: [Double]
}
