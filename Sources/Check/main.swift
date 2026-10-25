import Foundation
import PartlyCore

func expect(_ condition: Bool) {
    if !condition {
        fputs("check failed\n", stderr)
        exit(1)
    }
}

func onlyPartTimeIsStoredFromPayload() throws {
        let result = try Remotive.ingest(Data(sampleJSON.utf8))
        expect(result.jobs.map(\.sourceID) == ["1"])
        expect(result.rejected == 3)
        expect(result.jobs[0].summary == "Hello & welcome")
        expect(result.jobs[0].company == "BrightPath Media")
        expect(result.jobs[0].partTimeEvidence.contains("part_time"))
    }

    func duplicateRefreshDoesNotDuplicateOrMoveFirstSeen() throws {
        let store = try JobStore(path: tempPath())
        let first = Date(timeIntervalSince1970: 1_700_000_000)
        let second = Date(timeIntervalSince1970: 1_700_000_500)
        let jobs = try Remotive.ingest(Data(sampleJSON.utf8)).jobs
        try store.applyFullCatalog(jobs, at: first, rejected: 3)
        try store.applyFullCatalog(jobs, at: second, rejected: 3)
        let rows = try store.snapshot().jobs
        expect(rows.count == 1)
        expect(abs(rows[0].firstSeen.timeIntervalSince1970 - first.timeIntervalSince1970) < 0.001)
        expect(abs((rows[0].lastVerified?.timeIntervalSince1970 ?? 0) - second.timeIntervalSince1970) < 0.001)
        expect(rows[0].sourceStatus == .open)
    }

    func failedRefreshKeepsRowsAndVerification() throws {
        let store = try JobStore(path: tempPath())
        let seen = Date(timeIntervalSince1970: 1_700_000_000)
        let jobs = try Remotive.ingest(Data(sampleJSON.utf8)).jobs
        try store.applyFullCatalog(jobs, at: seen, rejected: 0)
        try store.noteFailure("offline", at: Date(timeIntervalSince1970: 1_700_000_900))
        let snapshot = try store.snapshot()
        expect(snapshot.jobs.count == 1)
        expect(abs((snapshot.jobs[0].lastVerified?.timeIntervalSince1970 ?? 0) - seen.timeIntervalSince1970) < 0.001)
        expect(snapshot.jobs[0].sourceStatus == .open)
        expect(snapshot.lastError == "offline")
        expect(abs((snapshot.lastSuccess?.timeIntervalSince1970 ?? 0) - seen.timeIntervalSince1970) < 0.001)
    }

    func missingListingIsKeptAndMarked() throws {
        let path = tempPath()
        let store = try JobStore(path: path)
        let both = [incoming("1", title: "Writer"), incoming("2", title: "Support")]
        try store.applyFullCatalog(both, at: Date(timeIntervalSince1970: 10), rejected: 0)
        try store.applyFullCatalog([incoming("1", title: "Writer")], at: Date(timeIntervalSince1970: 20), rejected: 0)
        let rows = try store.snapshot().jobs
        expect(rows.count == 2)
        expect(rows.first { $0.sourceID == "1" }?.sourceStatus == .open)
        expect(rows.first { $0.sourceID == "2" }?.sourceStatus == .missing)
        let reopened = try JobStore(path: path)
        let reopenedRows = try reopened.snapshot().jobs
        expect(reopenedRows.count == 2)
    }

    func emptyCatalogDoesNotWipe() throws {
        let store = try JobStore(path: tempPath())
        try store.applyFullCatalog([incoming("1", title: "Writer")], at: Date(timeIntervalSince1970: 10), rejected: 0)
        var threw = false
        do {
            try store.applyFullCatalog([], at: Date(timeIntervalSince1970: 20), rejected: 0)
        } catch {
            threw = true
        }
        expect(threw)
        let snapshot = try store.snapshot()
        expect(snapshot.jobs.count == 1)
        expect(snapshot.jobs[0].sourceStatus == .open)
        expect(snapshot.lastError == nil)
    }

    func savedFlagAndLocalReportSurviveRefresh() throws {
        let store = try JobStore(path: tempPath())
        try store.applyFullCatalog([incoming("1", title: "Writer")], at: Date(timeIntervalSince1970: 10), rejected: 0)
        let id = try store.snapshot().jobs[0].id
        try store.setSaved(id: id, saved: true)
        try store.addReport(jobID: id, reason: "Closed (position filled)", details: "", markClosed: true, at: Date(timeIntervalSince1970: 15))
        let reportCount = try store.reports(jobID: id)
        let closed = try store.snapshot().jobs[0]
        expect(reportCount == 1)
        expect(closed.sourceStatus == .closed)
        expect(closed.saved)
        try store.applyFullCatalog([incoming("1", title: "Writer")], at: Date(timeIntervalSince1970: 30), rejected: 0)
        let job = try store.snapshot().jobs[0]
        expect(job.saved)
        expect(job.sourceStatus == .open)
        let reportsAfter = try store.reports(jobID: id)
        expect(reportsAfter == 1)
    }

    func sameURLWithNewSourceIDUpdatesInPlace() throws {
        let store = try JobStore(path: tempPath())
        try store.applyFullCatalog([incoming("1", title: "Writer")], at: Date(timeIntervalSince1970: 10), rejected: 0)
        var moved = incoming("9", title: "Writer")
        moved.canonicalURL = "https://remotive.com/remote-jobs/writing/writer-1"
        moved.applicationURL = moved.canonicalURL
        try store.applyFullCatalog([moved], at: Date(timeIntervalSince1970: 20), rejected: 0)
        let rows = try store.snapshot().jobs
        expect(rows.count == 1)
        expect(rows[0].sourceID == "9")
        expect(rows[0].sourceStatus == .open)
    }

    func partTimePhrases() {
        expect(!isPartTimeListing("full_time"))
        expect(!isPartTimeListing("partner timeline"))
        expect(isPartTimeListing("part_time"))
        expect(isPartTimeListing("Part-Time"))
        expect(isPartTimeListing("tag=part time"))
        expect(isPartTimeListing("Teilzeit"))
    }

    func jobicyKeepsPartTimeOnly() throws {
        let json = """
        {"jobs":[
          {"id":10,"url":"https://jobicy.com/jobs/10","jobTitle":"Writer","companyName":"Acme","jobIndustry":["Writing"],"jobType":["Part-Time"],"jobGeo":"UK","jobExcerpt":"Words","pubDate":"2026-10-01T00:00:00Z"},
          {"id":11,"url":"https://jobicy.com/jobs/11","jobTitle":"Engineer","companyName":"Acme","jobIndustry":["Software"],"jobType":["Full-Time"],"jobGeo":"UK","jobExcerpt":"No"}
        ]}
        """
        let result = try Jobicy.ingest(Data(json.utf8))
        expect(result.jobs.map(\.sourceID) == ["10"])
        expect(result.jobs[0].location == "UK")
        expect(result.rejected == 1)
    }

    func remoteOKSkipsLegalBannerAndFullTime() throws {
        let json = """
        [{"legal":"link back"},
         {"id":"9","position":"Editor","company":"Acme","tags":["writing","part time"],"location":"","url":"https://remoteok.com/remote-jobs/editor-9","epoch":1700000000,"description":"<p>Edit</p>"},
         {"id":"8","position":"Engineer","company":"Acme","tags":["dev"],"url":"https://remoteok.com/remote-jobs/eng-8"}]
        """
        let result = try RemoteOK.ingest(Data(json.utf8))
        expect(result.jobs.map(\.sourceID) == ["9"])
        expect(result.jobs[0].location == "Worldwide")
        expect(result.jobs[0].summary == "Edit")
    }

    func arbeitnowRequiresRemoteAndPartTime() throws {
        let json = """
        {"data":[
          {"slug":"on-site","url":"https://www.arbeitnow.com/jobs/on-site","title":"Writer","company_name":"Acme","remote":false,"location":"Berlin","job_types":["Teilzeit"],"created_at":1700000000,"description":"No"},
          {"slug":"remote-full","url":"https://www.arbeitnow.com/jobs/remote-full","title":"Engineer","company_name":"Acme","remote":true,"location":"Berlin","job_types":["Full Time"],"created_at":1700000000,"description":"No"},
          {"slug":"remote-part","url":"https://www.arbeitnow.com/jobs/remote-part","title":"Support","company_name":"Acme","remote":true,"location":"Berlin","job_types":["Teilzeit"],"created_at":1700000000,"description":"<p>Help</p>"}
        ]}
        """
        let result = try Arbeitnow.ingest(Data(json.utf8))
        expect(result.jobs.map(\.sourceID) == ["remote-part"])
        expect(result.rejected == 2)
    }

    func himalayasKeepsPartTimeOnly() throws {
        let json = """
        {"jobs":[
          {"title":"Writer","companyName":"Acme","employmentType":"Full Time","applicationLink":"https://himalayas.app/companies/acme/jobs/writer","guid":"https://himalayas.app/companies/acme/jobs/writer","locationRestrictions":[],"categories":["Writing"],"description":"No","pubDate":1700000000},
          {"title":"Support","companyName":"Acme","employmentType":"Part Time","applicationLink":"https://himalayas.app/companies/acme/jobs/support?utm_source=api","guid":"https://himalayas.app/companies/acme/jobs/support","locationRestrictions":["Indonesia"],"categories":["Support"],"description":"<p>Help</p>","pubDate":1700000000}
        ]}
        """
        let result = try Himalayas.ingest(Data(json.utf8))
        expect(result.jobs.map(\.sourceID) == ["https://himalayas.app/companies/acme/jobs/support"])
        expect(result.jobs[0].applicationURL.contains("utm_source=api"))
        expect(result.jobs[0].location == "Indonesia")
        expect(result.rejected == 1)
    }

    func remoteJobsKeepsPartTimeOnly() throws {
        let json = """
        {"data":[
          {"id":"1","title":"Engineer","url":"https://remotejobs.org/remote-jobs/eng","apply_url":"https://remotejobs.org/remote-jobs/eng","company":{"name":"Acme"},"category":{"name":"Programming"},"location":"UK","type":"Full-time","employment_types":["FULL_TIME"],"description":"No","posted_at":"2024-01-02T03:04:05Z"},
          {"id":"2","title":"Writer","url":"https://remotejobs.org/remote-jobs/writer","apply_url":"https://remotejobs.org/remote-jobs/writer","company":{"name":"Acme"},"category":{"name":"Writing"},"location":null,"type":"Part-time","employment_types":["PART_TIME"],"description":"<p>Edit</p>","posted_at":"2024-01-02T03:04:05Z"}
        ]}
        """
        let result = try RemoteJobs.ingest(Data(json.utf8))
        expect(result.jobs.map(\.sourceID) == ["2"])
        expect(result.jobs[0].location == "Worldwide")
        expect(result.jobs[0].company == "Acme")
        expect(result.rejected == 1)
    }

    func refreshInterval() {
        let now = Date(timeIntervalSince1970: 1_000)
        expect(RefreshPolicy.allow(lastAttempt: nil, now: now))
        expect(!RefreshPolicy.allow(lastAttempt: now.addingTimeInterval(-30), now: now))
        expect(RefreshPolicy.allow(lastAttempt: now.addingTimeInterval(-60), now: now))
        expect(!RefreshPolicy.shouldReplaceCatalog(eligibleCount: 0))
    }

    private func tempPath() -> String {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("partly-\(UUID().uuidString).sqlite")
            .path
    }

    private func incoming(_ id: String, title: String) -> IncomingJob {
        IncomingJob(
            sourceName: Remotive.sourceName,
            sourceID: id,
            canonicalURL: "https://remotive.com/remote-jobs/writing/\(title.lowercased())-\(id)",
            applicationURL: "https://remotive.com/remote-jobs/writing/\(title.lowercased())-\(id)",
            title: title,
            company: "Acme",
            category: "Writing",
            location: "Worldwide",
            salary: "",
            summary: "Words",
            remoteEvidence: "api",
            partTimeEvidence: "job_type=part_time",
            publishedAt: Date(timeIntervalSince1970: 50),
            duplicateKey: duplicateKey(company: "Acme", title: title, location: "Worldwide")
        )
    }

    private let sampleJSON = """
    {"jobs":[
      {"id":1,"url":"https://remotive.com/remote-jobs/writing/writer-1","title":"Remote Content Writer (Part-time)","company_name":"BrightPath Media","category":"Writing","job_type":"part_time","publication_date":"2024-01-02T03:04:05","candidate_required_location":"Worldwide","salary":"","description":"<p>Hello &amp; welcome</p>"},
      {"id":2,"url":"https://remotive.com/remote-jobs/software/eng-2","title":"Engineer","company_name":"Acme","category":"Software Development","job_type":"full_time","publication_date":"2024-01-02T03:04:05","candidate_required_location":"Worldwide","description":"No"},
      {"id":3,"url":"https://remotive.com/remote-jobs/writing/mystery-3","title":"Mystery","company_name":"Acme","category":"Writing","candidate_required_location":"Worldwide","description":"No type"},
      {"id":4,"url":"http://insecure.example/job","title":"Insecure","company_name":"Acme","category":"Writing","job_type":"part_time","description":"Bad scheme"}
    ]}
    """


let checks: [() throws -> Void] = [
    onlyPartTimeIsStoredFromPayload,
    duplicateRefreshDoesNotDuplicateOrMoveFirstSeen,
    failedRefreshKeepsRowsAndVerification,
    missingListingIsKeptAndMarked,
    emptyCatalogDoesNotWipe,
    savedFlagAndLocalReportSurviveRefresh,
    sameURLWithNewSourceIDUpdatesInPlace,
    partTimePhrases,
    jobicyKeepsPartTimeOnly,
    remoteOKSkipsLegalBannerAndFullTime,
    arbeitnowRequiresRemoteAndPartTime,
    himalayasKeepsPartTimeOnly,
    remoteJobsKeepsPartTimeOnly,
    refreshInterval,
]
for check in checks {
    do { try check() } catch {
        fputs("FAIL \(error)\n", stderr)
        exit(1)
    }
}
print("ok")
