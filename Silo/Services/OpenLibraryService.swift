import Foundation

struct LibraryBook: Identifiable {
    let id: String
    let title: String
    let author: String

    var shortTitle: String {
        title.count > 42 ? String(title.prefix(39)) + "..." : title
    }
}

@MainActor
class OpenLibraryService {
    static let shared = OpenLibraryService()

    func searchBooks(subject: String) async throws -> [LibraryBook] {
        let q = "IB \(subject) study guide".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        let url = URL(string: "https://openlibrary.org/search.json?q=\(q)&limit=3&fields=key,title,author_name,cover_i")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let resp = try JSONDecoder().decode(OLSearchResp.self, from: data)
        return resp.docs.map { doc in
            LibraryBook(id: doc.key, title: doc.title, author: doc.author_name?.first ?? "Unknown")
        }
    }
}

private struct OLSearchResp: Codable { let docs: [OLDoc] }
private struct OLDoc: Codable {
    let key: String
    let title: String
    let author_name: [String]?
}
