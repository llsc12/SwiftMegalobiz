// i wish tr1fecta a sincere fuck you
// this is a joke musixmatch is cool

import SwiftSoup
import Foundation

/// MusixMatch sucks, they have paid api.
public struct MegalobizAPI {
  
  public static let `default` = Self(session: URLSession.shared)
  let session: URLSession
  
  
  struct Builders {
    static let baseURL = URL(string: "https://www.megalobiz.com")!
    static func search(_ q: String) throws -> URL {
      var search = URLComponents(string: baseURL.appendingPathComponent("search/all").absoluteString)!
      search.queryItems = [URLQueryItem(name: "qry", value: q)]
      guard let url = search.url else { throw MLBuilderError.urlBuildFailed }
      return url
    }
    
    enum MLBuilderError: Error {
      case urlBuildFailed
    }
  }
  
  public init(session: URLSession = URLSession.shared) {
    self.session = session
  }
  
  /// Searches MusixMatch for songs.
  /// - Parameter q: Search query.
  /// - Returns: A list of song objects.
  public func getSongs(for q: String) async throws -> MLSearchResults {
    let url = try Builders.search(q)
    var req = URLRequest(url: url)
    // they block you without a useragent or with generic ones
    req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.4 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
    
    let (data, _) = try await session.data(for: req)
    guard let htmlStr = String(data: data, encoding: .utf8) else { throw MLParseError.htmlToStringFailed }
    let html = try SwiftSoup.parse(htmlStr, url.absoluteString)
    
    // Parsing time, get body
    guard let body = html.body() else { throw MLParseError.couldNotGetBody }
    
    // First, get results box, then get results
    guard
      let resultsBox = try? body.select("#list_entity_container.entity_members_wrapper").first(),
      let results = try? resultsBox.select(".entity_full_member_box")
    else { throw MLParseError.couldNotExtractResults }
    
    let parsedResults: MLSearchResults = results.compactMap { element in
      guard
        let entity = try? element.select(".entity_full_member_name>.pro_part>a.entity_name").first(),
        let title = try? entity.attr("name"),
        let href = try? entity.attr("href"),
        let url = URL(string: href, relativeTo: Builders.baseURL)?.absoluteURL
      else { return nil }
      
      let obj = MLSongItem(title: title, url: url)
      return obj
    }
    
    return parsedResults
  }
  
  
  public enum MLParseError: Error {
    case htmlToStringFailed
    case couldNotGetBody
    case couldNotExtractResults
    case couldNotExtractLyrics
  }
}

public typealias MLSearchResults = [MLSongItem]

/// A song object which lets you see basic metadata and get lyrics.
public struct MLSongItem {
  
  public let title: String
  
  private let url: URL
  
  internal init(title: String, url: URL) {
    self.title = title
    self.url = url
  }
  
  /// Gets the lyrics of this song
  /// - Parameters:
  ///   - translation: Translation to get lyrics for, leave nil to get original lyrics. Get available translations with getCommonTranslations().
  ///   - session: The URLSession to use, for advanced use.
  /// - Returns: Formatted lyrics string.
  public func getLyrics(session: URLSession = URLSession.shared) async throws -> String {
    let body = try await getPageBody(nil, session: session)
    
    guard
      let lyricElements = try? body.select(".lyrics_member_box>.lyrics_details.entity_more_info>span")
    else { throw MegalobizAPI.MLParseError.couldNotExtractLyrics }
    
    let lyrics = try lyricElements.text(trimAndNormaliseWhitespace: false)
    
    return lyrics
  }
  
  internal func getPageBody(_ pathExt: String? = nil, session: URLSession) async throws -> Element {
    let reqUrl = url.appendingPathComponent(pathExt ?? "")
    var req = URLRequest(url: reqUrl)
    req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.4 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
    
    let (data, _) = try await session.data(for: req)
    guard let htmlStr = String(data: data, encoding: .utf8) else { throw MegalobizAPI.MLParseError.htmlToStringFailed }
    let html = try SwiftSoup.parse(htmlStr, url.absoluteString)
    
    guard let body = html.body() else { throw MegalobizAPI.MLParseError.couldNotGetBody }
    return body
  }
}

extension MLSongItem: Identifiable {
  public var id: String { self.url.absoluteString }
}

extension MLSongItem: Equatable {
  public static func == (lhs: MLSongItem, rhs: MLSongItem) -> Bool {
    lhs.id == rhs.id
  }
}
