import XCTest
@testable import SwiftMegalobiz
import SwiftSoup

final class SwiftMegalobizTests: XCTestCase {
  func testResults() async throws {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct
    // results.
    
    let results = try await MegalobizAPI.default.getSongs(for: "crystal dolphin")
    for result in results {
      print("[Search Results] \(result.title)")
    }
  }
  
  func testLyrics() async throws {
    let results = try await MegalobizAPI.default.getSongs(for: "crystal dolphin")
    
    let song = results.first!
    
    let lyrics = try await song.getLyrics()
    print(lyrics)
  }
}
