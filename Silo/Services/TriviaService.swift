import Foundation

struct TriviaQuestion: Identifiable {
    let id = UUID()
    let question: String
    let correctAnswer: String
    let allAnswers: [String]
}

@MainActor
class TriviaService {
    static let shared = TriviaService()

    static func categoryID(for subject: String) -> Int? {
        let s = subject.lowercased()
        if s.contains("math")         { return 19 }
        if s.contains("computer")     { return 18 }
        if s.contains("history")      { return 23 }
        if s.contains("geography")    { return 22 }
        if s.contains("music")        { return 12 }
        if s.contains("film")         { return 11 }
        if s.contains("philosophy")   { return 25 }
        if s.contains("biology") || s.contains("chemistry") ||
           s.contains("physics") || s.contains("science") { return 17 }
        return nil
    }

    func fetchQuestions(subject: String, amount: Int = 5) async throws -> [TriviaQuestion] {
        var urlStr = "https://opentdb.com/api.php?amount=\(amount)&type=multiple&difficulty=medium"
        if let cat = TriviaService.categoryID(for: subject) { urlStr += "&category=\(cat)" }
        guard let url = URL(string: urlStr) else { return [] }
        let (data, _) = try await URLSession.shared.data(from: url)
        let resp = try JSONDecoder().decode(TriviaResp.self, from: data)
        guard resp.response_code == 0 else { return [] }
        return resp.results.map { r in
            let correct = htmlDecode(r.correct_answer)
            let all = ([r.correct_answer] + r.incorrect_answers).map(htmlDecode).shuffled()
            return TriviaQuestion(question: htmlDecode(r.question), correctAnswer: correct, allAnswers: all)
        }
    }

    private func htmlDecode(_ s: String) -> String {
        var r = s
        [("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
         ("&quot;", "\""), ("&#039;", "'"), ("&nbsp;", " ")].forEach { r = r.replacingOccurrences(of: $0.0, with: $0.1) }
        return r
    }
}

private struct TriviaResp: Codable { let response_code: Int; let results: [TriviaResult] }
private struct TriviaResult: Codable { let question: String; let correct_answer: String; let incorrect_answers: [String] }
