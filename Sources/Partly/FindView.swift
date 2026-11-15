import PartlyCore
import SwiftUI

struct FindView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.theme) private var theme
    @StateObject private var page = Hold(1)
    @StateObject private var categoryQuery = Hold("")
    @StateObject private var search = DebouncedSearch()
    private let pageSize = 10
    private let categoryListHeight: CGFloat = 240

    private var rows: [Listing] { model.results() }
    private var pageCount: Int { max(1, Int(ceil(Double(rows.count) / Double(pageSize)))) }
    private var safePage: Int { min(max(page.value, 1), pageCount) }
    private var slice: [Listing] {
        let start = (safePage - 1) * pageSize
        return Array(rows.dropFirst(start).prefix(pageSize))
    }

    private var shownCategories: [String] {
        let query = categoryQuery.value.trimmingCharacters(in: .whitespacesAndNewlines)
        let matched = model.categories.filter { name in
            query.isEmpty || name.localizedCaseInsensitiveContains(query)
        }
        return matched.sorted { a, b in
            let aSelected = model.selectedCategories.contains(a)
            let bSelected = model.selectedCategories.contains(b)
            if aSelected != bSelected { return aSelected }
            return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
        }
    }

    var body: some View {
        Group {
            if model.bootError != nil {
                StatusPage(
                    symbol: "exclamationmark.icloud",
                    tint: theme.danger,
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
                    tint: theme.danger,
                    title: "Unable to load jobs",
                    message: "We couldn't fetch jobs from the sources right now. \(model.lastError ?? "")",
                    primary: "Retry",
                    primaryAction: { Task { await model.refresh() } },
                    secondary: "Back to home",
                    secondaryAction: { model.showFind() }
                )
            } else if !model.jobs.isEmpty && rows.isEmpty {
                StatusPage(
                    symbol: "magnifyingglass",
                    tint: theme.primary,
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
                    tint: theme.primary,
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
        .onAppear { search.adopt(model.query) }
        .onChange(of: model.query) { _, newValue in search.adopt(newValue) }
        .onChange(of: model.filterToken) { _, _ in page.value = 1 }
    }

    private var list: some View {
        GeometryReader { geo in
            let contentWidth = max(0, geo.size.width - 48)
            ScrollView {
                listBody(contentWidth: contentWidth)
                    .padding(24)
                    .frame(width: geo.size.width, alignment: .topLeading)
            }
        }
    }

    private func listBody(contentWidth: CGFloat) -> some View {
        let resultsWidth = max(0, contentWidth - 220 - 16)
        return VStack(alignment: .leading, spacing: 16) {
            hero
            toolbar
            if let banner = model.banner {
                note(banner, bg: theme.primaryLight, fg: theme.primary)
            } else if let stale = model.staleNote {
                note(stale, bg: theme.warningBg, fg: theme.warningFg)
            }
            HStack(alignment: .top, spacing: 16) {
                filters
                VStack(alignment: .leading, spacing: 12) {
                    footer
                    jobGrid(width: resultsWidth)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func columnCount(for width: CGFloat) -> Int {
        let minimumCard: CGFloat = 220
        let spacing: CGFloat = 12
        let fitted = Int((width + spacing) / (minimumCard + spacing))
        return min(5, max(1, fitted))
    }

    private func jobGrid(width: CGFloat) -> some View {
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: 12, alignment: .top),
            count: columnCount(for: width)
        )
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(slice) { job in
                JobCard(job: job)
            }
        }
    }

    private var hero: some View {
        HStack(alignment: .center, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Remote & Part-Time Jobs\nin One Place")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(theme.text)
                Text("Find genuine remote, part-time jobs with clear details and direct links to apply.")
                    .font(.system(size: 15))
                    .foregroundStyle(theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            ZStack {
                Circle()
                    .fill(theme.primaryLight)
                    .frame(width: 168, height: 168)
                Circle()
                    .fill(theme.primary.opacity(0.08))
                    .frame(width: 120, height: 120)
                    .offset(x: 48, y: 18)
                Image(systemName: "laptopcomputer")
                    .font(.system(size: 62, weight: .light))
                    .foregroundStyle(theme.primary)
                Image(systemName: "briefcase.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(theme.primary)
                    .padding(8)
                    .background(Circle().fill(theme.surface))
                    .offset(x: 72, y: -42)
            }
            .frame(width: 240, height: 150)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 26)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(theme.border.opacity(0.7))
        )
    }

    private var toolbar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                field(icon: "magnifyingglass", radius: 14) {
                    TextField("Search jobs, skills, or company...", text: Binding(
                        get: { search.text },
                        set: { search.edit($0) { model.query = $0 } }
                    ))
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundStyle(theme.text)
                }
                .frame(maxWidth: .infinity)
                Button {
                    search.commitNow { model.query = $0 }
                    Task { await model.searchTapped() }
                } label: {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .buttonStyle(PrimaryButton(corner: 12))
            }
            HStack(spacing: 8) {
                pillMenu(icon: "mappin.and.ellipse", value: model.locationChoice.rawValue, options: Array(AppModel.LocationChoice.allCases), label: \.rawValue) {
                    model.locationChoice = $0
                }
                pillMenu(icon: "square.grid.2x2", value: model.categoryPick, options: ["All categories"] + model.categories, label: { $0 }) {
                    model.chooseCategory($0)
                }
                pillMenu(icon: "arrow.up.arrow.down", value: model.sort.rawValue, options: Array(AppModel.Sort.allCases), label: \.rawValue) {
                    model.sort = $0
                }
                Spacer(minLength: 12)
                Button { Task { await model.refresh() } } label: {
                    Label(model.refreshing ? "Refreshing…" : "Refresh", systemImage: "arrow.clockwise")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(theme.secondary)
                }
                .buttonStyle(PlainActionButton())
                .disabled(model.refreshing)
            }
        }
    }

    private func pillMenu<Item: Hashable>(
        icon: String,
        value: String,
        options: [Item],
        label: @escaping (Item) -> String,
        select: @escaping (Item) -> Void
    ) -> some View {
        field(icon: icon, radius: 12) {
            FilterMenu(value: value, options: options, label: label, select: select, compact: true)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func field<Content: View>(icon: String, radius: CGFloat = Theme.controlRadius, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(theme.secondary)
            content()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: radius))
        .overlay(RoundedRectangle(cornerRadius: radius).stroke(theme.border))
    }

    private var filters: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("Filters", systemImage: "line.3.horizontal.decrease")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.text)
                    Spacer(minLength: 8)
                    Button("Clear all") { model.clearFilters() }
                        .buttonStyle(PlainActionButton())
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(theme.primary)
                }
                filterGroup("Job category") {
                    categoryFilters
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

    @ViewBuilder
    private var categoryFilters: some View {
        if model.categories.isEmpty {
            Text("Refresh to load categories")
                .font(.system(size: 12))
                .foregroundStyle(theme.secondary)
        } else {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.secondary)
                TextField("Search category...", text: $categoryQuery.value)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.text)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(theme.bg)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            if !model.selectedCategories.isEmpty {
                Text("\(model.selectedCategories.count) selected")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.primary)
            }
            if shownCategories.count > 8 {
                ScrollView {
                    categoryRows
                }
                .frame(height: categoryListHeight)
            } else {
                categoryRows
            }
        }
    }

    private var categoryRows: some View {
        VStack(alignment: .leading, spacing: 8) {
            if shownCategories.isEmpty {
                Text("No matching category")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.secondary)
            }
            ForEach(shownCategories, id: \.self) { name in
                CheckRow(title: name, on: model.selectedCategories.contains(name)) {
                    model.toggleCategory(name)
                }
            }
        }
    }

    private func filterGroup(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.text)
            content()
        }
    }

    private var footer: some View {
        HStack {
            let start = rows.isEmpty ? 0 : (safePage - 1) * pageSize + 1
            let end = min(safePage * pageSize, rows.count)
            Text("Showing \(start)-\(end) of \(rows.count) jobs")
                .font(.system(size: 13))
                .foregroundStyle(theme.secondary)
            Spacer()
            HStack(spacing: 6) {
                pageButton("chevron.left", enabled: safePage > 1) { page.value = safePage - 1 }
                ForEach(Self.pageMarks(current: safePage, count: pageCount)) { mark in
                    switch mark.kind {
                    case .number(let number):
                        Button("\(number)") { page.value = number }
                            .buttonStyle(PlainActionButton())
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(number == safePage ? theme.onPrimary : theme.text)
                            .frame(width: 28, height: 28)
                            .background(number == safePage ? theme.primary : theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.border))
                    case .gap:
                        Text("…")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(theme.secondary)
                            .frame(width: 16, height: 28)
                    }
                }
                pageButton("chevron.right", enabled: safePage < pageCount) { page.value = safePage + 1 }
            }
        }
    }

    private func pageButton(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .frame(width: 28, height: 28)
                .foregroundStyle(enabled ? theme.text : theme.secondary)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.border))
        }
        .buttonStyle(PlainActionButton())
        .disabled(!enabled)
    }

    private struct PageMark: Identifiable {
        enum Kind { case number(Int), gap }
        let id: String
        let kind: Kind
    }

    /// A short window: the ends, the current page and its neighbors, with gaps collapsed.
    private static func pageMarks(current: Int, count: Int) -> [PageMark] {
        guard count > 1 else { return [PageMark(id: "1", kind: .number(1))] }
        let current = min(max(current, 1), count)
        if count <= 7 {
            return (1...count).map { PageMark(id: "\($0)", kind: .number($0)) }
        }
        var pages: Set<Int> = [1, count, current, current - 1, current + 1]
        if current <= 4 { pages.formUnion([2, 3, 4, 5]) }
        if current >= count - 3 { pages.formUnion([count - 4, count - 3, count - 2, count - 1]) }
        let sorted = pages.filter { (1...count).contains($0) }.sorted()
        var marks: [PageMark] = []
        var previous = 0
        for number in sorted {
            if previous > 0, number - previous > 1 {
                marks.append(PageMark(id: "gap-\(previous)", kind: .gap))
            }
            marks.append(PageMark(id: "\(number)", kind: .number(number)))
            previous = number
        }
        return marks
    }

    private func note(_ text: String, bg: Color, fg: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(fg)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button { model.hideNotice() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(fg)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(PlainActionButton())
            .accessibilityLabel("Hide")
        }
        .padding(12)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius))
    }
}

@MainActor
final class DebouncedSearch: ObservableObject {
    @Published var text = ""
    private var pending: Task<Void, Never>?

    func edit(_ next: String, commit: @escaping (String) -> Void) {
        text = next
        pending?.cancel()
        pending = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            commit(next)
        }
    }

    func commitNow(_ commit: (String) -> Void) {
        pending?.cancel()
        pending = nil
        commit(text)
    }

    func adopt(_ value: String) {
        guard text != value else { return }
        pending?.cancel()
        pending = nil
        text = value
    }
}

struct FilterMenu<Item: Hashable>: View {
    @Environment(\.theme) private var theme
    let value: String
    let options: [Item]
    let label: (Item) -> String
    let select: (Item) -> Void
    var compact: Bool = false

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { item in
                Button(label(item)) { select(item) }
            }
        } label: {
            HStack(spacing: 6) {
                Text(value)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                    .frame(maxWidth: compact ? nil : .infinity, alignment: .leading)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(theme.secondary)
            }
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .foregroundStyle(theme.text)
        .tint(theme.text)
        .colorScheme(theme.scheme)
        .actionCursor()
    }
}

struct CheckRow: View {
    @Environment(\.theme) private var theme
    let title: String
    let on: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: on ? "checkmark.square.fill" : "square")
                    .foregroundStyle(on ? theme.primary : theme.secondary)
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.text)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(PlainActionButton())
    }
}

struct JobCard: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.theme) private var theme
    let job: Listing

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    InitialsMark(name: job.company, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(job.company)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(theme.text)
                            .lineLimit(1)
                        Text(job.sourceName)
                            .font(.system(size: 12))
                            .foregroundStyle(theme.secondary)
                            .lineLimit(1)
                    }
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                }
                Text(job.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.text)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 40, alignment: .topLeading)
                HStack(spacing: 6) {
                    Badge(title: "Remote", fg: theme.remoteFg, bg: theme.remoteBg)
                    Badge(title: "Part-time", fg: theme.primary, bg: theme.primaryLight)
                    if !job.isAvailable {
                        Badge(title: "Expired", fg: theme.danger, bg: theme.dangerBg)
                    }
                    Spacer(minLength: 0)
                }
                meta("mappin.and.ellipse", job.location)
                Spacer(minLength: 4)
                Button { model.open(job) } label: {
                    HStack(spacing: 6) {
                        Text("View details")
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButton(corner: 10))
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func meta(_ icon: String, _ text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 12))
            .foregroundStyle(theme.secondary)
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
    }
}

struct StatusPage: View {
    @Environment(\.theme) private var theme
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
                .foregroundStyle(theme.text)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(theme.secondary)
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
