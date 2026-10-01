import XCTest
@testable import SiftCore

final class BrandClusteringTests: XCTestCase {

    private func clusterSizes(_ domains: [String]) -> [Int] {
        BrandClustering.clusters(of: domains.map { makeEntry($0) }).map(\.count).sorted()
    }

    func testSameLabelAcrossTLDsIsOneBrand() {
        XCTAssertEqual(clusterSizes(["google.com", "google.co.uk"]), [2])
    }

    func testPrefixRelatedDomainsAreOneBrand() {
        XCTAssertEqual(clusterSizes(["meta.com", "metacareers.com"]), [2])
    }

    func testUnrelatedNamesStayApart() {
        // Same owner, unrelated names: a known, accepted miss.
        XCTAssertEqual(clusterSizes(["instagram.com", "facebook.com"]), [1, 1])
    }

    func testShortLabelsNeverPrefixMatch() {
        XCTAssertEqual(clusterSizes(["ab.com", "abcompany.com"]), [1, 1])
    }

    func testSiblingsOfASharedPrefixJoinThroughIt() {
        // metacareers and metafoo are unrelated to each other; both relate to "meta".
        // This is the case that needs transitive closure, and also the false-positive
        // amplifier described in BrandClustering's doc comment.
        XCTAssertEqual(clusterSizes(["meta.com", "metacareers.com", "metafoo.com"]), [3])
    }

    func testDistinctIPAddressesNeverCluster() {
        XCTAssertEqual(clusterSizes(["192.168.1.1", "192.168.1.10"]), [1, 1])
    }

    func testEntriesWithNoDomainAreExcluded() {
        let entries = [makeEntry("meta.com"), makeEntry(nil)]
        XCTAssertEqual(BrandClustering.clusters(of: entries).count, 1)
    }
}
