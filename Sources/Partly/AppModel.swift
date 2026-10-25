import AppKit
import Foundation
import PartlyCore

enum FetchError: LocalizedError {
    case status(Int)

    var errorDescription: String? {
        switch self {
        case .status(let code):
            return "HTTP \(code). Listings already on this Mac were kept."
        }
    }
}

enum SourceClient {
    static func fetch(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 40
        request.setValue("Partly/1.0 (local macOS reader)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else { throw FetchError.status(code) }
        return data
    }
}

@MainActor
final class AppModel: ObservableObject {
    enum Screen: Equatable { case find, saved, about, detail }

    enum LocationChoice: String, CaseIterable, Identifiable {
        case any = "Any location"
        case worldwide = "Worldwide"
        case indonesia = "Indonesia only"
        case specific = "Specific countries/regions"
        var id: String { rawValue }
    }

    enum Posted: String, CaseIterable, Identifiable {
        case any = "Any time"
        case d3 = "Last 3 days"
        case d7 = "Last 7 days"
        case d30 = "Last 30 days"
        var id: String { rawValue }
        var days: Int? {
            switch self {
            case .any: nil
            case .d3: 3
            case .d7: 7
            case .d30: 30
            }
        }
    }

    enum Chip: String, CaseIterable, Identifiable {
        case all = "All"
        case remoteDefault = "Remote (Default)"
        case remoteSpecific = "Remote (Specific Region)"
        case partTime = "Part-time"
        var id: String { rawValue }
    }

    enum Sort: String, CaseIterable, Identifiable {
        case newest = "Most recent"
        case oldest = "Oldest"
        var id: String { rawValue }
    }

    enum ReportReason: String, CaseIterable, Identifiable {
        case stale = "Stale (no longer accurate)"
        case closed = "Closed (position filled)"
        case misleading = "Misleading information"
        case misclassified = "Incorrectly classified (not remote or not part-time)"
        case duplicate = "Duplicate listing"
        case other = "Other"
        var id: String { rawValue }
        var closesListing: Bool { self == .stale || self == .closed }
    }

    @Published var screen: Screen = .find
    @Published var jobs: [Listing] = []
    @Published var query = ""
    @Published var locationChoice: LocationChoice = .any
    @Published var categoryPick = "All categories"
    @Published var selectedCategories: Set<String> = []
    @Published var posted: Posted = .any
    @Published var chip: Chip = .all
    @Published var sort: Sort = .newest
    @Published var selected: Listing?
    @Published var showReport = false
    @Published var refreshing = false
    @Published var banner: String?
    @Published var lastSuccess: Date?
    @Published var lastError: String?
    @Published var bootError: String?
    private var lastAttempt: Date?
    private var returnScreen: Screen = .find
    private var store: JobStore?
    private var started = false

    var categories: [String] {
        Array(Set(jobs.map(\.category))).sorted()
    }

    var filterToken: String {
        "\(query)|\(locationChoice)|\(chip)|\(posted)|\(sort)|\(selectedCategories.sorted().joined(separator: ","))"
    }

    var freshness: String {
        guard let lastSuccess else { return "Not fetched yet" }
        let when = lastSuccess.formatted(.relative(presentation: .named))
        return "Last verified \(when)"
    }

    var staleNote: String? {
        guard let lastError, !jobs.isEmpty else { return nil }
        return "Couldn't refresh (\(lastError)). Showing saved listings from \(freshness.lowercased()). They were not re-verified."
    }

    func results(savedOnly: Bool) -> [Listing] {
        let now = Date()
        let rows = jobs.filter { job in
            if savedOnly && !job.saved { return false }
            if !query.isEmpty {
                let blob = "\(job.title) \(job.company) \(job.summary) \(job.category)".lowercased()
                if !blob.contains(query.lowercased()) { return false }
            }
            if !selectedCategories.isEmpty && !selectedCategories.contains(job.category) { return false }
            switch locationChoice {
            case .any: break
            case .worldwide: if !job.isWorldwide { return false }
            case .indonesia: if !job.location.lowercased().contains("indonesia") { return false }
            case .specific: if job.isWorldwide { return false }
            }
            switch chip {
            case .all, .partTime: break
            case .remoteDefault: if !job.isWorldwide { return false }
            case .remoteSpecific: if job.isWorldwide { return false }
            }
            if let days = posted.days {
                guard let published = job.publishedAt else { return false }
                if published < now.addingTimeInterval(-Double(days) * 86_400) { return false }
            }
            return true
        }
        return rows.sorted { a, b in
            let ad = a.publishedAt ?? .distantPast
            let bd = b.publishedAt ?? .distantPast
            if ad != bd { return sort == .newest ? ad > bd : ad < bd }
            return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
        }
    }

    func start() async {
        guard !started else { return }
        started = true
        do {
            let store = try JobStore(path: Self.databasePath)
            self.store = store
            let snapshot = try store.snapshot()
            apply(snapshot)
            if snapshot.jobs.isEmpty { await refresh() }
        } catch {
            bootError = error.localizedDescription
        }
    }

    func searchTapped() async {
        if jobs.isEmpty { await refresh() }
    }

    func refresh() async {
        guard let store, !refreshing else { return }
        let now = Date()
        if !RefreshPolicy.allow(lastAttempt: lastAttempt, now: now) {
            banner = "Wait a minute before refreshing again."
            return
        }
        refreshing = true
        banner = nil
        defer { refreshing = false }
        try? store.noteAttempt(now)
        lastAttempt = now
        var lines: [String] = []
        var errors: [String] = []
        var applied = 0
        for pull in Self.pulls {
            do {
                let data = try await SourceClient.fetch(pull.url)
                let result = try pull.ingest(data)
                if RefreshPolicy.shouldReplaceCatalog(eligibleCount: result.jobs.count) {
                    try store.applyFullCatalog(result.jobs, at: Date(), rejected: result.rejected)
                    applied += result.jobs.count
                    lines.append("\(pull.name): \(result.jobs.count) part-time")
                } else {
                    lines.append("\(pull.name): no part-time listings")
                }
            } catch {
                errors.append("\(pull.name): \(error.localizedDescription)")
            }
        }
        if applied == 0, !errors.isEmpty {
            try? store.noteFailure(errors.joined(separator: " "), at: Date())
        }
        if let snapshot = try? store.snapshot() { apply(snapshot) }
        banner = (lines + errors).joined(separator: " · ")
    }

    func toggleSave(_ job: Listing) {
        guard let store else { return }
        do {
            try store.setSaved(id: job.id, saved: !job.saved)
            apply(try store.snapshot())
        } catch {
            banner = error.localizedDescription
        }
    }

    func submitReport(reason: ReportReason, details: String) {
        guard let store, let selected else { return }
        do {
            try store.addReport(
                jobID: selected.id,
                reason: reason.rawValue,
                details: details.trimmingCharacters(in: .whitespacesAndNewlines),
                markClosed: reason.closesListing,
                at: Date()
            )
            apply(try store.snapshot())
            showReport = false
            banner = "Report saved on this Mac. Nothing was sent."
        } catch {
            banner = error.localizedDescription
        }
    }

    func open(_ job: Listing) {
        returnScreen = screen == .detail ? returnScreen : screen
        selected = job
        screen = .detail
    }

    func back() {
        screen = returnScreen == .detail ? .find : returnScreen
    }

    func showFind() {
        screen = .find
    }

    func showSaved() {
        screen = .saved
    }

    func chooseCategory(_ name: String) {
        categoryPick = name
        selectedCategories = name == "All categories" ? [] : [name]
    }

    func toggleCategory(_ name: String) {
        if selectedCategories.contains(name) {
            selectedCategories.remove(name)
        } else {
            selectedCategories.insert(name)
        }
        categoryPick = selectedCategories.count == 1 ? (selectedCategories.first ?? "All categories") : "All categories"
    }

    func chooseLocation(_ choice: LocationChoice) {
        locationChoice = locationChoice == choice ? .any : choice
    }

    func choosePosted(_ choice: Posted) {
        posted = posted == choice ? .any : choice
    }

    func clearFilters() {
        query = ""
        locationChoice = .any
        categoryPick = "All categories"
        selectedCategories = []
        posted = .any
        chip = .all
        sort = .newest
    }

    private func apply(_ snapshot: CatalogSnapshot) {
        jobs = snapshot.jobs
        lastSuccess = snapshot.lastSuccess
        lastError = snapshot.lastError
        lastAttempt = snapshot.lastAttempt
        if let selected, let fresh = jobs.first(where: { $0.id == selected.id }) {
            self.selected = fresh
        }
    }

    private static let pulls: [(name: String, url: URL, ingest: (Data) throws -> IngestResult)] = [
        (Remotive.sourceName, Remotive.endpoint, Remotive.ingest),
        (Jobicy.sourceName, Jobicy.endpoint, Jobicy.ingest),
        (RemoteOK.sourceName, RemoteOK.endpoint, RemoteOK.ingest),
        (Arbeitnow.sourceName, Arbeitnow.endpoint, Arbeitnow.ingest),
        (Himalayas.sourceName, Himalayas.endpoint, Himalayas.ingest),
        (RemoteJobs.sourceName, RemoteJobs.endpoint, RemoteJobs.ingest),
    ]

    private static var supportURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Partly", isDirectory: true)
    }

    private static var databasePath: String {
        supportURL.appendingPathComponent("jobs.sqlite").path
    }
}
