import Foundation

final class BookmarkStore: ObservableObject {
    @Published var bookmarkedURL: URL?

    private let key = "securityScopedBookmark"

    init() {
        if let data = UserDefaults.standard.data(forKey: key) {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &isStale) {
                if isStale {
                    UserDefaults.standard.removeObject(forKey: key)
                } else {
                    bookmarkedURL = url
                }
            }
        }
    }

    func saveBookmark(for url: URL) {
        do {
            let data = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(data, forKey: key)
            bookmarkedURL = url
        } catch {
            print("Failed to save bookmark: \(error)")
        }
    }
}
