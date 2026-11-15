import PartlyCore
import SwiftUI

struct DetailView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.theme) private var theme
    @StateObject private var tab = Hold(0)

    var body: some View {
        Group {
            if let job = model.selected {
                if job.isAvailable {
                    available(job)
                } else {
                    unavailable(job)
                }
            }
        }
        .frame(width: 720, height: 640)
        .background(theme.bg)
        .sheet(isPresented: $model.showReport) {
            ReportSheet()
                .environmentObject(model)
                .sheetTheme(theme)
        }
    }

    private func unavailable(_ job: Listing) -> some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Listing")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.secondary)
                    Spacer()
                    closeButton
                }
                Text(job.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(theme.text)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface)

            ScrollView {
                Text(job.sourceStatus == .closed
                    ? "You reported this job as filled or stale."
                    : "It was not in the latest \(job.sourceName) catalog.")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
            .scrollContentBackground(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                Spacer()
                Button("Report a problem") { model.showReport = true }
                    .buttonStyle(PrimaryButton())
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(theme.surface)
            .overlay(alignment: .top) { Divider().overlay(theme.border) }
        }
    }

    private var closeButton: some View {
        Button { model.selected = nil } label: {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.text)
                .frame(width: 28, height: 28)
                .background(theme.bg)
                .clipShape(Circle())
        }
        .buttonStyle(PlainActionButton())
        .accessibilityLabel("Close")
    }

    private func available(_ job: Listing) -> some View {
        VStack(spacing: 0) {
            header(job)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch tab.value {
                    case 1: details(job)
                    case 2: company(job)
                    default: overview(job)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollContentBackground(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            footer(job)
        }
    }

    private func header(_ job: Listing) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                InitialsMark(name: job.company, size: 48)
                VStack(alignment: .leading, spacing: 4) {
                    Text(job.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(job.company)
                        .foregroundStyle(theme.secondary)
                    HStack(spacing: 6) {
                        Badge(title: "Remote", fg: theme.remoteFg, bg: theme.remoteBg)
                        Badge(title: "Part-time", fg: theme.primary, bg: theme.primaryLight)
                    }
                }
                Spacer(minLength: 8)
                closeButton
            }
            HStack(spacing: 16) {
                Label(job.location, systemImage: "mappin.and.ellipse")
                Label("Last verified \(relative(job.lastVerified))", systemImage: "clock")
                Label(job.sourceName, systemImage: "link")
            }
            .font(.system(size: 13))
            .foregroundStyle(theme.secondary)
            SectionTabs(selection: $tab.value)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface)
        .overlay(alignment: .bottom) { Divider().overlay(theme.border) }
    }

    private func footer(_ job: Listing) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Application")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.text)
                Text("Opens the original listing on \(job.sourceName). Partly does not apply for you.")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Button("Report a problem") { model.showReport = true }
                .buttonStyle(QuietButton())
            Button("Go to application") { openExternal(job.applicationURL) }
                .buttonStyle(PrimaryButton())
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(theme.surface)
        .overlay(alignment: .top) { Divider().overlay(theme.border) }
    }

    private func overview(_ job: Listing) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            section("About the role", job.summary.isEmpty ? "\(job.sourceName) did not include a description for this listing." : job.summary)
            VStack(alignment: .leading, spacing: 8) {
                Label("Eligibility confirmed by source", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.success)
                evidence("Remote work", job.remoteEvidence)
                evidence("Part-time", job.partTimeEvidence)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.successBg)
            .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius))

            Text("Key details")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(theme.text)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 12) {
                detailItem("Location eligibility", job.location)
                detailItem("Source", job.sourceName)
                detailItem("Category", job.category)
                detailItem("Last verified", relative(job.lastVerified))
                if !job.salary.isEmpty { detailItem("Salary", job.salary) }
            }
        }
    }

    private func details(_ job: Listing) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            section("Description", job.summary.isEmpty ? "No description stored." : job.summary)
            detailItem("Published", job.publishedAt.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "Unknown")
            detailItem("First saved on this Mac", job.firstSeen.formatted(date: .abbreviated, time: .shortened))
            detailItem("Part-time evidence", job.partTimeEvidence)
            detailItem("Remote evidence", job.remoteEvidence)
        }
    }

    private func company(_ job: Listing) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(job.company)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(theme.text)
            detailItem("Where you can work from", job.location)
            Text("The company name and location come from \(job.sourceName). This app does not keep a separate company profile.")
                .foregroundStyle(theme.secondary)
        }
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(theme.text)
            Text(body).font(.system(size: 14)).foregroundStyle(theme.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func evidence(_ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(theme.success)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(theme.text)
                Text(body).font(.system(size: 12)).foregroundStyle(theme.secondary)
            }
        }
    }

    private func detailItem(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 12)).foregroundStyle(theme.secondary)
            Text(value).font(.system(size: 14, weight: .medium)).foregroundStyle(theme.text)
        }
    }
}

private struct SectionTabs: View {
    @Environment(\.theme) private var theme
    @Binding var selection: Int
    private let titles = ["Overview", "Details", "Company"]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                let selected = selection == index
                Button {
                    selection = index
                } label: {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selected ? theme.onPrimary : theme.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(selected ? theme.primary : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(PlainActionButton())
            }
        }
        .padding(4)
        .background(theme.bg)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct ReportSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @StateObject private var reason = Hold(AppModel.ReportReason.stale)
    @StateObject private var details = Hold("")

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Report this listing")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(theme.text)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .foregroundStyle(theme.secondary)
                }
                .buttonStyle(PlainActionButton())
                .accessibilityLabel("Close")
            }
            Text("Help keep the local list accurate. Why are you reporting this listing? The report stays on this Mac.")
                .font(.system(size: 13))
                .foregroundStyle(theme.secondary)
            ForEach(AppModel.ReportReason.allCases) { item in
                Button(action: { reason.value = item }) {
                    HStack(spacing: 8) {
                        Image(systemName: reason.value == item ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(reason.value == item ? theme.primary : theme.secondary)
                        Text(item.rawValue)
                            .font(.system(size: 13))
                            .foregroundStyle(theme.text)
                        Spacer()
                    }
                }
                .buttonStyle(PlainActionButton())
            }
            Text("Additional details (optional)")
                .font(.system(size: 12))
                .foregroundStyle(theme.secondary)
            TextField("", text: $details.value, axis: .vertical)
                .textFieldStyle(.plain)
                .foregroundStyle(theme.text)
                .lineLimit(3...5)
                .padding(8)
                .background(theme.surface)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.border))
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(QuietButton())
                Button("Submit report") {
                    model.submitReport(reason: reason.value, details: details.value)
                }
                .buttonStyle(PrimaryButton())
            }
        }
        .padding(20)
        .frame(width: 440)
        .background(theme.bg)
    }
}
