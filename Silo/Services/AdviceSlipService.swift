import Foundation

struct AdviceSlip {
    let id: Int
    let advice: String
}

@MainActor
class AdviceSlipService {
    static let shared = AdviceSlipService()

    func fetch() async throws -> AdviceSlip {
        let url = URL(string: "https://api.adviceslip.com/advice")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let resp = try JSONDecoder().decode(AdviceResp.self, from: data)
        return AdviceSlip(id: resp.slip.id, advice: resp.slip.advice)
    }
}

private struct AdviceResp: Codable { let slip: SlipData }
private struct SlipData: Codable { let id: Int; let advice: String }
