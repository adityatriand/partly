import PartlyCore
import SwiftUI

struct FindView: View {
    @EnvironmentObject private var model: AppModel
    let savedOnly: Bool
    @StateObject private var page = Hold(1)
    private let pageSize = 10

    private var rows: [Listing] { model.results(savedOnly: savedOnly) }
    private var pageCount: Int { max(1, Int(ceil(Double(rows.count) / Double(pageSize)))) }
    private var safePage: Int { min(max(page.value, 1), pageCount) }
    private var slice: [Listing] {
        let start = (safePage - 1) * pageSize
        return Array(rows.dropFirst(start).prefix(pageSize))
    }

    var body: some View {
        Group {
            if model.bootError != nil {
                StatusPage(
                    symbol: "exclamationmark.icloud",
                    tint: Theme.danger,
                    title: "Unable to load jobs",
                    message: model.bootError ?? "",
                    primary: "Retry",
                    primaryAction: {},
                    secondary: nil,
                    secondaryAction: nil
                )
            } else if model.jobs.isEmpty && model.refreshing {
                ProgressView("Fetching part-time remote jobs…")
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.jobs.isEmpty && model.lastError != nil {
                StatusPage(
                    symbol: "exclamationmark.icloud",
                    tint: Theme.danger,
                    title: "Unable to load jobs",
                    message: "We couldn't fetch jobs from the sources right now. \(model.lastError ?? "")",
                    primary: "Retry",
                    primaryAction: { Task { await model.refresh() } },
                    secondary: "Back to home",
                    secondaryAction: { model.showFind() }
                )
            } else if savedOnly && model.jobs.allSatisfy({ !$0.saved }) {
                StatusPage(
                    symbol: "heart",
                    tint: Theme.primary,
                    title: "No saved jobs",
                    message: "Save a listing from the results and it will stay on this Mac.",
                    primary: "Browse all jobs",
                    primaryAction: { model.showFind() },
                    secondary: nil,
                    secondaryAction: nil
                )
            } else if !model.jobs.isEmpty && rows.isEmpty {
                StatusPage(
                    symbol: "magnifyingglass",
                    tint: Theme.primary,
                    title: "No jobs match your search",
                    message: "Try adjusting your filters or search terms. We'll show you new opportunities soon.",
                    primary: "Clear filters",
                    primaryAction: { model.clearFilters() },
                    secondary: "Browse all jobs",
                    secondaryAction: { model.clearFilters(); model.showFind() }
                )
            } else if model.jobs.isEmpty {
                StatusPage(
                    symbol: "magnifyingglass",
                    tint: Theme.primary,
                    title: "No listings stored yet",
                    message: "Refresh pulls remote part-time jobs from Remotive, Jobicy, Remote OK, Arbeitnow, Himalayas, and RemoteJobs.org. They stay on this Mac afterwards, including offline.",
                    primary: "Refresh",
                    primaryAction: { Task { await model.refresh() } },
                    secondary: nil,
                    secondaryAction: nil
                )
            } else {
                list
            }
        }
        .onChange(of: model.filterToken) { _, _ in page.value = 1 }
        .onChange(of: savedOnly) { _, _ in page.value = 1 }
    }

    private var list: some View {
        GeometryReader { geo in
            ScrollView {
                listBody
                    .padding(24)
                    .frame(width: geo.size.width, alignment: .topLeading)
            }
        }
    }

    private var listBody: some View {
        VStack(alignment: .leading, spacing: 16) {
                if !savedOnly { hero }
                searchRow
                chips
                if let banner = model.banner {
                    note(banner, bg: Theme.primaryLight, fg: Theme.primary)
                } else if let stale = model.staleNote {
                    note(stale, bg: Theme.warningBg, fg: Color(red: 0.57, green: 0.25, blue: 0.05))
                }
                HStack(alignment: .top, spacing: 16) {
                    filters
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(slice) { job in
                            JobCard(job: job)
                        }
                        footer
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
        }
    }

    private var hero: some View {
        Card {
            HStack(alignment: .center, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Remote & Part-Time Jobs\nin One Place")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Theme.text)
                    Text("Find genuine remote, part-time jobs with clear details and direct links to apply.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                ZStack {
                    Circle().fill(Theme.primaryLight).frame(width: 150, height: 150)
                    Image(systemName: "laptopcomputer")
                        .font(.system(size: 54))
                        .foregroundStyle(Theme.primary)
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.success)
                        .offset(x: 58, y: -48)
                    Text("Part-time")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.white)
                        .clipShape(Capsule())
                        .offset(x: 70, y: 36)
                }
                .frame(width: 220, height: 160)
            }
            .padding(24)
        }
    }

    private var searchRow: some View {
        HStack(spacing: 10) {
            field(icon: "magnifyingglass") {
                TextField("Job title, keyword, or company", text: $model.query)
                    .textFieldStyle(.plain)
            }
            field(icon: "mappin.and.ellipse") {
                Picker("Location", selection: $model.locationChoice) {
                    ForEach(AppModel.LocationChoice.allCases) { choice in
                        Text(choice.rawValue).tag(choice)
                    }
                }
                .labelsHidden()
                .frame(width: 180)
            }
            field(icon: "square.grid.2x2") {
                Picker("Category", selection: Binding(
                    get: { model.categoryPick },
                    set: { model.chooseCategory($0) }
                )) {
                    Text("All categories").tag("All categories")
                    ForEach(model.categories, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .frame(width: 160)
            }
            Button("Search") { Task { await model.searchTapped() } }
                .buttonStyle(PrimaryButton())
        }
    }

    private func field<Content: View>(icon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(Theme.secondary)
            content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.controlRadius).stroke(Theme.border))
    }

    private var chips: some View {
        HStack(spacing: 8) {
            ForEach(AppModel.Chip.allCases) { chip in
                let on = model.chip == chip
                Button(chip.rawValue) { model.chip = chip }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(on ? Theme.primary : Theme.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(on ? Theme.primaryLight : .white)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(on ? Theme.primary.opacity(0.3) : Theme.border))
            }
            Spacer()
            HStack(spacing: 6) {
                Text("Sort by")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.secondary)
                Picker("Sort", selection: $model.sort) {
                    ForEach(AppModel.Sort.allCases) { Text($0.rawValue).tag($0) }
                }
                .labelsHidden()
                .frame(width: 130)
            }
            Button(model.refreshing ? "Refreshing…" : "Refresh") { Task { await model.refresh() } }
                .buttonStyle(QuietButton())
                .disabled(model.refreshing)
            Text(model.freshness)
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondary)
        }
    }

    private var filters: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                Label("Filters", systemImage: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.text)
                filterGroup("Job category") {
                    if model.categories.isEmpty {
                        Text("Refresh to load categories")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.secondary)
                    }
                    ForEach(model.categories, id: \.self) { name in
                        CheckRow(title: name, on: model.selectedCategories.contains(name)) {
                            model.toggleCategory(name)
                        }
                    }
                }
                filterGroup("Location eligibility") {
                    CheckRow(title: "Worldwide", on: model.locationChoice == .worldwide) {
                        model.chooseLocation(.worldwide)
                    }
                    CheckRow(title: "Indonesia only", on: model.locationChoice == .indonesia) {
                        model.chooseLocation(.indonesia)
                    }
                    CheckRow(title: "Specific countries/regions", on: model.locationChoice == .specific) {
                        model.chooseLocation(.specific)
                    }
                }
                filterGroup("Posted") {
                    CheckRow(title: "Last 3 days", on: model.posted == .d3) { model.choosePosted(.d3) }
                    CheckRow(title: "Last 7 days", on: model.posted == .d7) { model.choosePosted(.d7) }
                    CheckRow(title: "Last 30 days", on: model.posted == .d30) { model.choosePosted(.d30) }
                }
            }
            .padding(16)
            .frame(width: 220, alignment: .topLeading)
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private func filterGroup(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.text)
            content()
        }
    }

    private var footer: some View {
        HStack {
            let start = rows.isEmpty ? 0 : (safePage - 1) * pageSize + 1
            let end = min(safePage * pageSize, rows.count)
            Text("Showing \(start)-\(end) of \(rows.count) jobs")
                .font(.system(size: 13))
                .foregroundStyle(Theme.secondary)
            Spacer()
            HStack(spacing: 6) {
                pageButton("chevron.left", enabled: safePage > 1) { page.value = safePage - 1 }
                ForEach(1...pageCount, id: \.self) { number in
                    Button("\(number)") { page.value = number }
                        .buttonStyle(.plain)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(number == safePage ? .white : Theme.text)
                        .frame(width: 28, height: 28)
                        .background(number == safePage ? Theme.primary : .white)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border))
                }
                pageButton("chevron.right", enabled: safePage < pageCount) { page.value = safePage + 1 }
            }
        }
        .padding(.top, 4)
    }

    private func pageButton(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .frame(width: 28, height: 28)
                .foregroundStyle(enabled ? Theme.text : Theme.secondary)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func note(_ text: String, bg: Color, fg: Color) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(fg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius))
    }
}

struct CheckRow: View {
    let title: String
    let on: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: on ? "checkmark.square.fill" : "square")
                    .foregroundStyle(on ? Theme.primary : Theme.secondary)
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
    }
}

struct JobCard: View {
    @EnvironmentObject private var model: AppModel
    let job: Listing

    var body: some View {
        Card {
            HStack(alignment: .top, spacing: 14) {
                InitialsMark(name: job.company)
                VStack(alignment: .leading, spacing: 6) {
                    Text(job.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(2)
                    Text(job.company)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.secondary)
                    HStack(spacing: 6) {
                        Badge(title: "Remote", fg: Theme.remoteFg, bg: Theme.remoteBg)
                        Badge(title: "Part-time", fg: Theme.primary, bg: Theme.primaryLight)
                        if !job.isAvailable {
                            Badge(title: "Expired", fg: Theme.danger, bg: Theme.dangerBg)
                        }
                    }
                    HStack(spacing: 14) {
                        meta("mappin.and.ellipse", job.location)
                        meta("clock", "Last verified \(relative(job.lastVerified))")
                        meta("link", job.sourceName)
                    }
                    if !job.summary.isEmpty {
                        Text(job.summary)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.secondary)
                            .lineLimit(2)
                            .truncationMode(.tail)
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                VStack(spacing: 8) {
                    Button("View details") { model.open(job) }
                        .buttonStyle(PrimaryButton())
                    Button(action: { model.toggleSave(job) }) {
                        Label(job.saved ? "Saved" : "Save", systemImage: job.saved ? "heart.fill" : "heart")
                    }
                    .buttonStyle(QuietButton())
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .padding(16)
        }
    }

    private func meta(_ icon: String, _ text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 12))
            .foregroundStyle(Theme.secondary)
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
    }
}

struct StatusPage: View {
    let symbol: String
    let tint: Color
    let title: String
    let message: String
    let primary: String
    let primaryAction: () -> Void
    let secondary: String?
    let secondaryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(tint.opacity(0.12)).frame(width: 88, height: 88)
                Image(systemName: symbol)
                    .font(.system(size: 32))
                    .foregroundStyle(tint)
            }
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.text)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            HStack(spacing: 10) {
                Button(primary, action: primaryAction).buttonStyle(PrimaryButton())
                if let secondary, let secondaryAction {
                    Button(secondary, action: secondaryAction).buttonStyle(QuietButton())
                }
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
