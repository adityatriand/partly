import Foundation

public enum Jobicy {
    public static let sourceName = "Jobicy"
    public static let site = URL(string: "https://jobicy.com")!
    /// shortcut: one page (count=50). Page further only if `hasMore` becomes true for this tag.
    public static let endpoint = URL(string: "https://jobicy.com/api/v2/remote-jobs?count=50&tag=part-time")!

    public static func ingest(_ data: Data) throws -> IngestResult {
        let rows = try feedRows(data, listKey: "jobs", label: sourceName)
        return finishIngest(rows.map(accept))
    }

    private static func accept(_ row: [String: Any]) -> IncomingJob? {
        let types = texts(row, "jobType")
        guard types.contains(where: isPartTimeListing) || isPartTimeListing(text(row, "jobTitle")) else { return nil }
        let evidence = types.first(where: isPartTimeListing) ?? text(row, "jobTitle")
        let place = text(row, "jobGeo")
        let summarySource = text(row, "jobDescription").isEmpty ? text(row, "jobExcerpt") : text(row, "jobDescription")
        return makeListing(
            sourceName: sourceName,
            sourceID: text(row, "id"),
            url: text(row, "url"),
            title: text(row, "jobTitle"),
            company: text(row, "companyName"),
            category: texts(row, "jobIndustry").joined(separator: ", "),
            location: place,
            salary: salaryLine(row),
            summary: plainText(summarySource),
            remoteEvidence: "Listed on the Jobicy remote-jobs API. Location: \(place.isEmpty ? "Worldwide" : place).",
            partTimeEvidence: "jobType=\(evidence)",
            publishedAt: parseDate(text(row, "pubDate"))
        )
    }

    private static func salaryLine(_ row: [String: Any]) -> String {
        guard let min = number(row, "salaryMin"), min > 0 else { return "" }
        let currency = text(row, "salaryCurrency")
        let period = text(row, "salaryPeriod")
        let range: String
        if let max = number(row, "salaryMax"), max > min {
            range = "\(Int(min))–\(Int(max))"
        } else {
            range = "\(Int(min))"
        }
        return [range, currency, period.isEmpty ? nil : "/ \(period)"].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
    }
}

public enum RemoteOK {
    public static let sourceName = "Remote OK"
    public static let site = URL(string: "https://remoteok.com")!
    public static let endpoint = URL(string: "https://remoteok.com/api")!

    public static func ingest(_ data: Data) throws -> IngestResult {
        let rows = try feedRows(data, listKey: nil, label: sourceName)
        let listings = rows.filter { $0["position"] != nil || $0["id"] != nil }
        return finishIngest(listings.map(accept))
    }

    private static func accept(_ row: [String: Any]) -> IncomingJob? {
        let tags = texts(row, "tags")
        let title = text(row, "position")
        guard tags.contains(where: isPartTimeListing) || isPartTimeListing(title) else { return nil }
        let evidence = tags.first(where: isPartTimeListing) ?? title
        let place = text(row, "location")
        let published = number(row, "epoch").map { Date(timeIntervalSince1970: $0) } ?? parseDate(text(row, "date"))
        return makeListing(
            sourceName: sourceName,
            sourceID: text(row, "id"),
            url: text(row, "url"),
            title: title,
            company: text(row, "company"),
            category: tags.first ?? "Other",
            location: place,
            salary: "",
            summary: plainText(text(row, "description")),
            remoteEvidence: "Listed on the Remote OK API. Location: \(place.isEmpty ? "Worldwide" : place).",
            partTimeEvidence: "tag=\(evidence)",
            publishedAt: published
        )
    }
}

public enum Arbeitnow {
    public static let sourceName = "Arbeitnow"
    public static let site = URL(string: "https://www.arbeitnow.com")!
    /// shortcut: first page only (100–300 rows). Don't walk `?page=` until part-time remote yield is worth the extra calls.
    public static let endpoint = URL(string: "https://www.arbeitnow.com/api/job-board-api")!

    public static func ingest(_ data: Data) throws -> IngestResult {
        let rows = try feedRows(data, listKey: "data", label: sourceName)
        return finishIngest(rows.map(accept))
    }

    private static func accept(_ row: [String: Any]) -> IncomingJob? {
        guard row["remote"] as? Bool == true else { return nil }
        let types = texts(row, "job_types")
        let title = text(row, "title")
        guard types.contains(where: isPartTimeListing) || isPartTimeListing(title) else { return nil }
        let evidence = types.first(where: isPartTimeListing) ?? title
        let published = number(row, "created_at").map { Date(timeIntervalSince1970: $0) }
        return makeListing(
            sourceName: sourceName,
            sourceID: text(row, "slug"),
            url: text(row, "url"),
            title: title,
            company: text(row, "company_name"),
            category: types.first ?? "Other",
            location: text(row, "location"),
            salary: "",
            summary: plainText(text(row, "description")),
            remoteEvidence: "Arbeitnow marks this listing remote. Location: \(text(row, "location")).",
            partTimeEvidence: "job_types=\(evidence)",
            publishedAt: published
        )
    }
}

public enum Himalayas {
    public static let sourceName = "Himalayas"
    public static let site = URL(string: "https://himalayas.app")!
    /// shortcut: one search page (20 jobs). Walk `page` only if part-time yield is worth the extra calls.
    public static let endpoint = URL(string: "https://himalayas.app/jobs/api/search?employment_type=Part%20Time")!

    public static func ingest(_ data: Data) throws -> IngestResult {
        let rows = try feedRows(data, listKey: "jobs", label: sourceName)
        return finishIngest(rows.map(accept))
    }

    private static func accept(_ row: [String: Any]) -> IncomingJob? {
        let employment = text(row, "employmentType")
        guard isPartTimeListing(employment) else { return nil }
        let places = texts(row, "locationRestrictions")
        let place = places.joined(separator: ", ")
        let category = (texts(row, "categories").first ?? "Other").replacingOccurrences(of: "-", with: " ")
        let summarySource = text(row, "description").isEmpty ? text(row, "excerpt") : text(row, "description")
        return makeListing(
            sourceName: sourceName,
            sourceID: text(row, "guid"),
            url: text(row, "guid"),
            applicationURL: text(row, "applicationLink"),
            title: text(row, "title"),
            company: text(row, "companyName"),
            category: category,
            location: place,
            salary: salaryLine(row),
            summary: plainText(summarySource),
            remoteEvidence: "Listed on the Himalayas remote-jobs API. Location: \(place.isEmpty ? "Worldwide" : place).",
            partTimeEvidence: "employmentType=\(employment)",
            publishedAt: number(row, "pubDate").map { Date(timeIntervalSince1970: $0) }
        )
    }

    private static func salaryLine(_ row: [String: Any]) -> String {
        guard let min = number(row, "minSalary"), min > 0 else { return "" }
        let range: String
        if let max = number(row, "maxSalary"), max > min {
            range = "\(Int(min))–\(Int(max))"
        } else {
            range = "\(Int(min))"
        }
        return [range, text(row, "currency"), text(row, "salaryPeriod")].filter { !$0.isEmpty }.joined(separator: " ")
    }
}

public enum RemoteJobs {
    public static let sourceName = "RemoteJobs.org"
    public static let site = URL(string: "https://remotejobs.org")!
    /// shortcut: one page (limit=50). Walk `offset` only if the part-time total is worth more calls.
    public static let endpoint = URL(string: "https://remotejobs.org/api/v1/jobs?type=part-time&limit=50")!

    public static func ingest(_ data: Data) throws -> IngestResult {
        let rows = try feedRows(data, listKey: "data", label: sourceName)
        return finishIngest(rows.map(accept))
    }

    private static func accept(_ row: [String: Any]) -> IncomingJob? {
        let type = text(row, "type")
        let types = texts(row, "employment_types")
        guard types.contains(where: isPartTimeListing) || isPartTimeListing(type) else { return nil }
        let evidence = types.first(where: isPartTimeListing) ?? type
        let place = text(row, "location")
        let listing = text(row, "url")
        return makeListing(
            sourceName: sourceName,
            sourceID: text(row, "id"),
            url: listing,
            applicationURL: text(row, "apply_url"),
            title: text(row, "title"),
            company: nested(row, "company", "name"),
            category: nested(row, "category", "name"),
            location: place,
            salary: text(row, "salary_text"),
            summary: plainText(text(row, "description")),
            remoteEvidence: "Listed on the RemoteJobs.org API. Location: \(place.isEmpty ? "Worldwide" : place).",
            partTimeEvidence: "type=\(evidence)",
            publishedAt: parseDate(text(row, "posted_at"))
        )
    }
}

func makeListing(
    sourceName: String,
    sourceID: String,
    url: String,
    applicationURL: String? = nil,
    title: String,
    company: String,
    category: String,
    location: String,
    salary: String,
    summary: String,
    remoteEvidence: String,
    partTimeEvidence: String,
    publishedAt: Date?
) -> IncomingJob? {
    let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
    let company = company.trimmingCharacters(in: .whitespacesAndNewlines)
    let sourceID = sourceID.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty, !company.isEmpty, !sourceID.isEmpty else { return nil }
    guard isPartTimeListing(partTimeEvidence) else { return nil }
    guard !remoteEvidence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
    let applyRaw = (applicationURL ?? url).trimmingCharacters(in: .whitespacesAndNewlines)
    guard let parsed = URL(string: url), parsed.scheme?.lowercased() == "https" else { return nil }
    guard URL(string: applyRaw)?.scheme?.lowercased() == "https" else { return nil }
    let place = location.trimmingCharacters(in: .whitespacesAndNewlines)
    let whereFrom = place.isEmpty ? "Worldwide" : place
    let category = category.trimmingCharacters(in: .whitespacesAndNewlines)
    return IncomingJob(
        sourceName: sourceName,
        sourceID: sourceID,
        canonicalURL: url,
        applicationURL: applyRaw,
        title: title,
        company: company,
        category: category.isEmpty ? "Other" : category,
        location: whereFrom,
        salary: salary.trimmingCharacters(in: .whitespacesAndNewlines),
        summary: summary,
        remoteEvidence: remoteEvidence,
        partTimeEvidence: partTimeEvidence,
        publishedAt: publishedAt,
        duplicateKey: duplicateKey(company: company, title: title, location: whereFrom)
    )
}

func feedRows(_ data: Data, listKey: String?, label: String) throws -> [[String: Any]] {
    let json: Any
    do {
        json = try JSONSerialization.jsonObject(with: data)
    } catch {
        throw IngestError.message("\(label) response could not be read.")
    }
    if let listKey {
        guard let root = json as? [String: Any], let rows = root[listKey] as? [[String: Any]] else {
            throw IngestError.message("\(label) response did not include \(listKey).")
        }
        return rows
    }
    guard let rows = json as? [Any] else {
        throw IngestError.message("\(label) response could not be read.")
    }
    return rows.compactMap { $0 as? [String: Any] }
}

func nested(_ row: [String: Any], _ key: String, _ child: String) -> String {
    guard let object = row[key] as? [String: Any] else { return "" }
    return text(object, child)
}

func text(_ row: [String: Any], _ key: String) -> String {
    switch row[key] {
    case let value as String: return value
    case let value as Int: return String(value)
    case let value as Double where value.rounded() == value: return String(Int(value))
    case let value as Double: return String(value)
    default: return ""
    }
}

func texts(_ row: [String: Any], _ key: String) -> [String] {
    switch row[key] {
    case let value as [String]: return value
    case let value as [Any]: return value.map { String(describing: $0) }
    case let value as String where !value.isEmpty: return [value]
    default: return []
    }
}

func number(_ row: [String: Any], _ key: String) -> Double? {
    switch row[key] {
    case let value as Int: return Double(value)
    case let value as Double: return value
    case let value as String: return Double(value)
    default: return nil
    }
}
