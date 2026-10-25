import Foundation

public enum SourceStatus: String, Sendable, Codable {
    case open
    case missing
    case closed
    case unknown
}

public struct Listing: Identifiable, Equatable, Sendable {
    public var id: String
    public var sourceName: String
    public var sourceID: String
    public var canonicalURL: String
    public var applicationURL: String
    public var title: String
    public var company: String
    public var category: String
    public var location: String
    public var salary: String
    public var summary: String
    public var remoteEvidence: String
    public var partTimeEvidence: String
    public var firstSeen: Date
    public var lastSeen: Date
    public var lastVerified: Date?
    public var sourceStatus: SourceStatus
    public var saved: Bool
    public var publishedAt: Date?
    public var duplicateKey: String

    public init(
        id: String,
        sourceName: String,
        sourceID: String,
        canonicalURL: String,
        applicationURL: String,
        title: String,
        company: String,
        category: String,
        location: String,
        salary: String,
        summary: String,
        remoteEvidence: String,
        partTimeEvidence: String,
        firstSeen: Date,
        lastSeen: Date,
        lastVerified: Date?,
        sourceStatus: SourceStatus,
        saved: Bool,
        publishedAt: Date?,
        duplicateKey: String
    ) {
        self.id = id
        self.sourceName = sourceName
        self.sourceID = sourceID
        self.canonicalURL = canonicalURL
        self.applicationURL = applicationURL
        self.title = title
        self.company = company
        self.category = category
        self.location = location
        self.salary = salary
        self.summary = summary
        self.remoteEvidence = remoteEvidence
        self.partTimeEvidence = partTimeEvidence
        self.firstSeen = firstSeen
        self.lastSeen = lastSeen
        self.lastVerified = lastVerified
        self.sourceStatus = sourceStatus
        self.saved = saved
        self.publishedAt = publishedAt
        self.duplicateKey = duplicateKey
    }

    public var isWorldwide: Bool {
        let value = location.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return value == "worldwide" || value == "anywhere" || value.contains("worldwide")
    }

    public var isAvailable: Bool { sourceStatus == .open }
}

public struct IncomingJob: Equatable, Sendable {
    public var sourceName: String
    public var sourceID: String
    public var canonicalURL: String
    public var applicationURL: String
    public var title: String
    public var company: String
    public var category: String
    public var location: String
    public var salary: String
    public var summary: String
    public var remoteEvidence: String
    public var partTimeEvidence: String
    public var publishedAt: Date?
    public var duplicateKey: String

    public init(
        sourceName: String,
        sourceID: String,
        canonicalURL: String,
        applicationURL: String,
        title: String,
        company: String,
        category: String,
        location: String,
        salary: String,
        summary: String,
        remoteEvidence: String,
        partTimeEvidence: String,
        publishedAt: Date?,
        duplicateKey: String
    ) {
        self.sourceName = sourceName
        self.sourceID = sourceID
        self.canonicalURL = canonicalURL
        self.applicationURL = applicationURL
        self.title = title
        self.company = company
        self.category = category
        self.location = location
        self.salary = salary
        self.summary = summary
        self.remoteEvidence = remoteEvidence
        self.partTimeEvidence = partTimeEvidence
        self.publishedAt = publishedAt
        self.duplicateKey = duplicateKey
    }
}

public struct IngestResult: Equatable, Sendable {
    public var jobs: [IncomingJob]
    public var rejected: Int

    public init(jobs: [IncomingJob], rejected: Int) {
        self.jobs = jobs
        self.rejected = rejected
    }
}

public struct CatalogSnapshot: Sendable {
    public var jobs: [Listing]
    public var lastSuccess: Date?
    public var lastError: String?
    public var lastAttempt: Date?

    public init(jobs: [Listing], lastSuccess: Date?, lastError: String?, lastAttempt: Date?) {
        self.jobs = jobs
        self.lastSuccess = lastSuccess
        self.lastError = lastError
        self.lastAttempt = lastAttempt
    }
}

public enum RefreshPolicy {
    /// Remotive blocks more than 2 requests a minute. One minute is the hard floor.
    /// shortcut: 4/day is documented guidance, not enforced; tighten if Remotive asks.
    public static let minimumInterval: TimeInterval = 60

    public static func allow(lastAttempt: Date?, now: Date) -> Bool {
        guard let lastAttempt else { return true }
        return now.timeIntervalSince(lastAttempt) >= minimumInterval
    }

    /// An empty eligible set is treated as a bad payload, not an empty market.
    public static func shouldReplaceCatalog(eligibleCount: Int) -> Bool {
        eligibleCount > 0
    }
}

public func duplicateKey(company: String, title: String, location: String) -> String {
    [company, title, location].map(normalizeMatch).joined(separator: "|")
}

private func normalizeMatch(_ raw: String) -> String {
    let cleaned = raw.lowercased().map { ch -> Character in
        ch.isLetter || ch.isNumber ? ch : " "
    }
    return String(cleaned).split(separator: " ").joined(separator: " ")
}
