import XCTest
@testable import Sawt

final class SawtTests: XCTestCase {
    func testOfficialYouTubeLinksAreAccepted() {
        XCTAssertTrue(YouTubeLink.isOfficial("https://www.youtube.com/watch?v=abc"))
        XCTAssertTrue(YouTubeLink.isOfficial("https://youtu.be/abc"))
    }
    func testNonYouTubeLinksAreRejected() {
        XCTAssertFalse(YouTubeLink.isOfficial("https://youtube.example.com/watch?v=abc"))
        XCTAssertFalse(YouTubeLink.isOfficial("https://example.com"))
    }
    func testPlaylistStartsEmpty() {
        XCTAssertTrue(Playlist(name: "اختبار").trackIDs.isEmpty)
    }
}
