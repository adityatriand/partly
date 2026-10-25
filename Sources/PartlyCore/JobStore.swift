import Foundation
import SQLite3

public struct StoreError: Error, CustomStringConvertible {
    public let description: String
    public init(_ description: String) { self.description = description }
}

public final class JobStore: @unchecked Sendable {
    private var db: OpaquePointer?
    private let lock = NSLock()
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    public init(path: String) throws {
        if path != ":memory:" {
            let directory = URL(fileURLWithPath: path).deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(path, &handle, flags, nil) == SQLITE_OK, let handle else {
            throw StoreError("Could not open the local database.")
        }
        db = handle
        do {
            try exec("PRAGMA busy_timeout = 3000")
            try exec("PRAGMA foreign_keys = ON")
            let version = try queryInt("PRAGMA user_version")
            if version == 0 {
                try exec(Self.schema)
                try exec("PRAGMA user_version = 1")
            } else if version != 1 {
                throw StoreError("This database was written by a newer version of Partly.")
            }
        } catch {
            sqlite3_close(handle)
            db = nil
            throw error
        }
    }

    deinit { sqlite3_close(db) }

    public func snapshot() throws -> CatalogSnapshot {
        try locked {
            CatalogSnapshot(
                jobs: try readJobs(),
                lastSuccess: try metaDate("last_success"),
                lastError: try meta("last_error").flatMap { $0.isEmpty ? nil : $0 },
                lastAttempt: try metaDate("last_attempt")
            )
        }
    }

    public func noteAttempt(_ date: Date) throws {
        try locked { try setMeta("last_attempt", value: Self.stamp(date)) }
    }

    /// Records the failure and leaves every job row untouched.
    public func noteFailure(_ message: String, at date: Date) throws {
        try locked {
            try setMeta("last_attempt", value: Self.stamp(date))
            try setMeta("last_error", value: message)
        }
    }

    public func applyFullCatalog(_ jobs: [IncomingJob], at date: Date, rejected: Int) throws {
        try locked {
            guard RefreshPolicy.shouldReplaceCatalog(eligibleCount: jobs.count) else {
                throw StoreError("Refusing to apply an empty catalog.")
            }
            try exec("BEGIN IMMEDIATE")
            do {
                let source = jobs[0].sourceName
                for job in jobs {
                    try upsert(job, at: date)
                }
                try markMissing(source: source, seenBefore: date)
                try setMeta("last_success", value: Self.stamp(date))
                try setMeta("last_attempt", value: Self.stamp(date))
                try setMeta("last_error", value: "")
                try setMeta("last_rejected", value: String(rejected))
                try exec("COMMIT")
            } catch {
                sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
                throw error
            }
        }
    }

    public func setSaved(id: String, saved: Bool) throws {
        try locked {
            let stmt = try prepare("UPDATE jobs SET saved = ? WHERE id = ?")
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_int(stmt, 1, saved ? 1 : 0)
            bind(stmt, 2, id)
            try step(stmt)
        }
    }

    public func addReport(jobID: String, reason: String, details: String, markClosed: Bool, at date: Date) throws {
        try locked {
            try exec("BEGIN IMMEDIATE")
            do {
                let stmt = try prepare(
                    "INSERT INTO reports (job_id, reason, details, created_at, status) VALUES (?, ?, ?, ?, 'pending')"
                )
                defer { sqlite3_finalize(stmt) }
                bind(stmt, 1, jobID)
                bind(stmt, 2, reason)
                bind(stmt, 3, details)
                sqlite3_bind_double(stmt, 4, date.timeIntervalSince1970)
                try step(stmt)
                if markClosed {
                    let update = try prepare("UPDATE jobs SET source_status = 'closed' WHERE id = ?")
                    defer { sqlite3_finalize(update) }
                    bind(update, 1, jobID)
                    try step(update)
                }
                try exec("COMMIT")
            } catch {
                sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
                throw error
            }
        }
    }

    public func reports(jobID: String) throws -> Int {
        try locked {
            let stmt = try prepare("SELECT COUNT(*) FROM reports WHERE job_id = ?")
            defer { sqlite3_finalize(stmt) }
            bind(stmt, 1, jobID)
            guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
            return Int(sqlite3_column_int(stmt, 0))
        }
    }

    private func upsert(_ job: IncomingJob, at date: Date) throws {
        if let id = try findID(source: job.sourceName, sourceID: job.sourceID)
            ?? findID(url: job.canonicalURL)
        {
            try update(job, id: id, at: date)
            return
        }
        let stmt = try prepare(
            """
            INSERT INTO jobs (
                id, source_name, source_id, canonical_url, application_url, title, company, category,
                location, salary, summary, remote_evidence, part_time_evidence, first_seen, last_seen,
                last_verified, source_status, saved, published_at, duplicate_key
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'open', 0, ?, ?)
            """
        )
        defer { sqlite3_finalize(stmt) }
        let id = UUID().uuidString
        bind(stmt, 1, id)
        bindIncoming(stmt, job, start: 2)
        let stamp = date.timeIntervalSince1970
        sqlite3_bind_double(stmt, 14, stamp)
        sqlite3_bind_double(stmt, 15, stamp)
        sqlite3_bind_double(stmt, 16, stamp)
        bindOptionalDate(stmt, 17, job.publishedAt)
        bind(stmt, 18, job.duplicateKey)
        do {
            try step(stmt)
        } catch {
            if let existing = try findID(url: job.canonicalURL) {
                try update(job, id: existing, at: date)
            } else {
                throw error
            }
        }
    }

    private func update(_ job: IncomingJob, id: String, at date: Date) throws {
        let stmt = try prepare(
            """
            UPDATE jobs SET
                source_name = ?, source_id = ?, canonical_url = ?, application_url = ?, title = ?,
                company = ?, category = ?, location = ?, salary = ?, summary = ?, remote_evidence = ?,
                part_time_evidence = ?, last_seen = ?, last_verified = ?, source_status = 'open',
                published_at = ?, duplicate_key = ?
            WHERE id = ?
            """
        )
        defer { sqlite3_finalize(stmt) }
        bindIncoming(stmt, job, start: 1)
        let stamp = date.timeIntervalSince1970
        sqlite3_bind_double(stmt, 13, stamp)
        sqlite3_bind_double(stmt, 14, stamp)
        bindOptionalDate(stmt, 15, job.publishedAt)
        bind(stmt, 16, job.duplicateKey)
        bind(stmt, 17, id)
        try step(stmt)
    }

    private func bindIncoming(_ stmt: OpaquePointer?, _ job: IncomingJob, start: Int32) {
        let fields = [
            job.sourceName, job.sourceID, job.canonicalURL, job.applicationURL, job.title,
            job.company, job.category, job.location, job.salary, job.summary,
            job.remoteEvidence, job.partTimeEvidence,
        ]
        for (offset, field) in fields.enumerated() {
            bind(stmt, start + Int32(offset), field)
        }
    }

    private func markMissing(source: String, seenBefore: Date) throws {
        let stmt = try prepare(
            """
            UPDATE jobs SET source_status = 'missing'
            WHERE source_name = ? AND source_status = 'open' AND last_seen < ?
            """
        )
        defer { sqlite3_finalize(stmt) }
        bind(stmt, 1, source)
        sqlite3_bind_double(stmt, 2, seenBefore.timeIntervalSince1970)
        try step(stmt)
    }

    private func findID(source: String, sourceID: String) throws -> String? {
        let stmt = try prepare("SELECT id FROM jobs WHERE source_name = ? AND source_id = ?")
        defer { sqlite3_finalize(stmt) }
        bind(stmt, 1, source)
        bind(stmt, 2, sourceID)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return columnText(stmt, 0)
    }

    private func findID(url: String) throws -> String? {
        let stmt = try prepare("SELECT id FROM jobs WHERE canonical_url = ?")
        defer { sqlite3_finalize(stmt) }
        bind(stmt, 1, url)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return columnText(stmt, 0)
    }

    private func readJobs() throws -> [Listing] {
        let stmt = try prepare(
            """
            SELECT id, source_name, source_id, canonical_url, application_url, title, company, category,
                   location, salary, summary, remote_evidence, part_time_evidence, first_seen, last_seen,
                   last_verified, source_status, saved, published_at, duplicate_key
            FROM jobs
            ORDER BY published_at DESC, title COLLATE NOCASE
            """
        )
        defer { sqlite3_finalize(stmt) }
        var rows: [Listing] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let status = SourceStatus(rawValue: columnText(stmt, 16)) ?? .unknown
            rows.append(Listing(
                id: columnText(stmt, 0),
                sourceName: columnText(stmt, 1),
                sourceID: columnText(stmt, 2),
                canonicalURL: columnText(stmt, 3),
                applicationURL: columnText(stmt, 4),
                title: columnText(stmt, 5),
                company: columnText(stmt, 6),
                category: columnText(stmt, 7),
                location: columnText(stmt, 8),
                salary: columnText(stmt, 9),
                summary: columnText(stmt, 10),
                remoteEvidence: columnText(stmt, 11),
                partTimeEvidence: columnText(stmt, 12),
                firstSeen: columnDate(stmt, 13),
                lastSeen: columnDate(stmt, 14),
                lastVerified: columnOptionalDate(stmt, 15),
                sourceStatus: status,
                saved: sqlite3_column_int(stmt, 17) == 1,
                publishedAt: columnOptionalDate(stmt, 18),
                duplicateKey: columnText(stmt, 19)
            ))
        }
        return rows
    }

    private func meta(_ key: String) throws -> String? {
        let stmt = try prepare("SELECT value FROM meta WHERE key = ?")
        defer { sqlite3_finalize(stmt) }
        bind(stmt, 1, key)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return columnText(stmt, 0)
    }

    private func metaDate(_ key: String) throws -> Date? {
        guard let raw = try meta(key), let value = Double(raw) else { return nil }
        return Date(timeIntervalSince1970: value)
    }

    private func setMeta(_ key: String, value: String) throws {
        let stmt = try prepare("INSERT INTO meta (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value")
        defer { sqlite3_finalize(stmt) }
        bind(stmt, 1, key)
        bind(stmt, 2, value)
        try step(stmt)
    }

    private func queryInt(_ sql: String) throws -> Int {
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(stmt, 0))
    }

    private func locked<T>(_ body: () throws -> T) throws -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }

    private func exec(_ sql: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, sql, nil, nil, &error) == SQLITE_OK else {
            let message = error.map { String(cString: $0) } ?? "SQLite error"
            sqlite3_free(error)
            throw StoreError(message)
        }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw StoreError(String(cString: sqlite3_errmsg(db)))
        }
        return stmt
    }

    private func step(_ stmt: OpaquePointer?) throws {
        let code = sqlite3_step(stmt)
        guard code == SQLITE_DONE else {
            throw StoreError(String(cString: sqlite3_errmsg(db)))
        }
    }

    private func bind(_ stmt: OpaquePointer?, _ index: Int32, _ value: String) {
        sqlite3_bind_text(stmt, index, value, -1, transient)
    }

    private func bindOptionalDate(_ stmt: OpaquePointer?, _ index: Int32, _ date: Date?) {
        if let date {
            sqlite3_bind_double(stmt, index, date.timeIntervalSince1970)
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }

    private func columnText(_ stmt: OpaquePointer?, _ index: Int32) -> String {
        guard let raw = sqlite3_column_text(stmt, index) else { return "" }
        return String(cString: raw)
    }

    private func columnDate(_ stmt: OpaquePointer?, _ index: Int32) -> Date {
        Date(timeIntervalSince1970: sqlite3_column_double(stmt, index))
    }

    private func columnOptionalDate(_ stmt: OpaquePointer?, _ index: Int32) -> Date? {
        guard sqlite3_column_type(stmt, index) != SQLITE_NULL else { return nil }
        return columnDate(stmt, index)
    }

    private static func stamp(_ date: Date) -> String {
        String(date.timeIntervalSince1970)
    }

    private static let schema = """
    CREATE TABLE meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
    );
    CREATE TABLE jobs (
        id TEXT PRIMARY KEY,
        source_name TEXT NOT NULL,
        source_id TEXT NOT NULL,
        canonical_url TEXT NOT NULL,
        application_url TEXT NOT NULL,
        title TEXT NOT NULL,
        company TEXT NOT NULL,
        category TEXT NOT NULL,
        location TEXT NOT NULL,
        salary TEXT NOT NULL,
        summary TEXT NOT NULL,
        remote_evidence TEXT NOT NULL,
        part_time_evidence TEXT NOT NULL,
        first_seen REAL NOT NULL,
        last_seen REAL NOT NULL,
        last_verified REAL,
        source_status TEXT NOT NULL,
        saved INTEGER NOT NULL,
        published_at REAL,
        duplicate_key TEXT NOT NULL,
        UNIQUE (source_name, source_id),
        UNIQUE (canonical_url)
    );
    CREATE INDEX idx_jobs_status ON jobs (source_status);
    CREATE INDEX idx_jobs_published ON jobs (published_at);
    CREATE INDEX idx_jobs_duplicate ON jobs (duplicate_key);
    CREATE TABLE reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        job_id TEXT NOT NULL,
        reason TEXT NOT NULL,
        details TEXT NOT NULL,
        created_at REAL NOT NULL,
        status TEXT NOT NULL
    );
    """
}
