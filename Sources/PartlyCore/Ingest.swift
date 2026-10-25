import Foundation

public enum IngestError: Error, CustomStringConvertible {
    case message(String)
    public var description: String { switch self { case .message(let m): return m } }
}

public func isPartTimeListing(_ raw: String?) -> Bool {
    guard let raw else { return false }
    var letters = ""
    for scalar in raw.lowercased() {
        letters.append(scalar.isLetter ? scalar : " ")
    }
    let tokens = letters.split(separator: " ").map(String.init)
    if tokens.contains("parttime") || tokens.contains("teilzeit") { return true }
    var previous = ""
    for token in tokens {
        if previous == "part" && token == "time" { return true }
        previous = token
    }
    return false
}

func finishIngest(_ items: [IncomingJob?]) -> IngestResult {
    var rejected = 0
    var byID: [String: IncomingJob] = [:]
    for item in items {
        guard let item else {
            rejected += 1
            continue
        }
        if byID[item.sourceID] != nil { rejected += 1 }
        byID[item.sourceID] = item
    }
    var byURL: [String: IncomingJob] = [:]
    for job in byID.values {
        if byURL[job.canonicalURL] != nil { rejected += 1 }
        byURL[job.canonicalURL] = job
    }
    let jobs = byURL.values.sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
    return IngestResult(jobs: jobs, rejected: rejected)
}

public enum Remotive {
    public static let sourceName = "Remotive"
    public static let site = URL(string: "https://remotive.com")!
    public static let endpoint = URL(string: "https://remotive.com/api/remote-jobs")!

    public static func ingest(_ data: Data) throws -> IngestResult {
        let page: Page
        do {
            page = try JSONDecoder().decode(Page.self, from: data)
        } catch {
            throw IngestError.message("Remotive response could not be read (\(error.localizedDescription)).")
        }

        return finishIngest(page.jobs.map { accept($0) })
    }

    static func isPartTime(_ raw: String?) -> Bool { isPartTimeListing(raw) }

    private static func accept(_ item: Item) -> IncomingJob? {
        guard isPartTime(item.jobType) else { return nil }
        let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let company = item.companyName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !company.isEmpty else { return nil }
        guard let url = URL(string: item.url), let scheme = url.scheme?.lowercased(), scheme == "https" else {
            return nil
        }
        let location = item.candidateRequiredLocation?.trimmingCharacters(in: .whitespacesAndNewlines)
        let place = (location?.isEmpty == false) ? location! : "Worldwide"
        let summary = plainText(item.description ?? "")
        return IncomingJob(
            sourceName: sourceName,
            sourceID: String(item.id),
            canonicalURL: item.url,
            applicationURL: item.url,
            title: title,
            company: company,
            category: item.category?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Other",
            location: place,
            salary: item.salary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            summary: summary,
            remoteEvidence: "Listed on the Remotive remote-jobs API. Location restriction: \(place).",
            partTimeEvidence: "job_type=\(item.jobType ?? "")",
            publishedAt: item.publicationDate.flatMap(parseDate),
            duplicateKey: duplicateKey(company: company, title: title, location: place)
        )
    }
}

func plainText(_ html: String) -> String {
    var text = html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
    let entities = [
        "&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'",
    ]
    for (entity, value) in entities {
        text = text.replacingOccurrences(of: entity, with: value)
    }
    let collapsed = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    // shortcut: descriptions are cut at 4000 characters; raise the cap if detail pages need the full posting.
    if collapsed.count > 4000 {
        return String(collapsed.prefix(4000)) + "…"
    }
    return collapsed
}

func parseDate(_ raw: String) -> Date? {
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime]
    if let date = iso.date(from: raw) { return date }
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = iso.date(from: raw) { return date }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    if let date = formatter.date(from: raw) { return date }
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: raw)
}

private struct Page: Decodable {
    let jobs: [Item]
}

private struct Item: Decodable {
    let id: Int
    let url: String
    let title: String
    let companyName: String
    let category: String?
    let jobType: String?
    let publicationDate: String?
    let candidateRequiredLocation: String?
    let salary: String?
    let description: String?

    enum CodingKeys: String, CodingKey {
        case id, url, title, category, salary, description
        case companyName = "company_name"
        case jobType = "job_type"
        case publicationDate = "publication_date"
        case candidateRequiredLocation = "candidate_required_location"
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
