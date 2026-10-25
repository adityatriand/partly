import PartlyCore
import SwiftUI

struct DetailView: View {
    @EnvironmentObject private var model: AppModel
    @StateObject private var tab = Hold(0)

    var body: some View {
        if let job = model.selected {
            if job.isAvailable {
                available(job)
            } else {
                StatusPage(
                    symbol: "doc.badge.ellipsis",
                    tint: Theme.danger,
                    title: "This listing is no longer available",
                    message: job.sourceStatus == .closed
                        ? "You reported this job as filled or stale. It stays in the local list until a later refresh sees it again."
                        : "It was not in the latest \(job.sourceName) catalog. The job may have been filled or removed by the source.",
                    primary: "Back to results",
                    primaryAction: { model.back() },
                    secondary: "Report a problem",
                    secondaryAction: { model.showReport = true }
                )
            }
        } else {
            StatusPage(
                symbol: "doc",
                tint: Theme.secondary,
                title: "No listing selected",
                message: "Go back and choose a job.",
                primary: "Back to results",
                primaryAction: { model.back() },
                secondary: nil,
                secondaryAction: nil
            )
        }
    }

    private func available(_ job: Listing) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Button(action: { model.back() }) {
                    Label("Back to results", systemImage: "chevron.left")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.secondary)
                }
                .buttonStyle(.plain)

                Card {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 12) {
                            InitialsMark(name: job.company, size: 48)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(job.title)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(Theme.text)
                                Text(job.company)
                                    .foregroundStyle(Theme.secondary)
                                HStack(spacing: 6) {
                                    Badge(title: "Remote", fg: Theme.remoteFg, bg: Theme.remoteBg)
                                    Badge(title: "Part-time", fg: Theme.primary, bg: Theme.primaryLight)
                                }
                            }
                            Spacer()
                        }
                        HStack(spacing: 16) {
                            Label(job.location, systemImage: "mappin.and.ellipse")
                            Label("Last verified \(relative(job.lastVerified))", systemImage: "clock")
                            Label(job.sourceName, systemImage: "link")
                        }
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.secondary)
                        HStack(spacing: 10) {
                            Button("Go to application") { openExternal(job.applicationURL) }
                                .buttonStyle(PrimaryButton())
                            Button(action: { model.toggleSave(job) }) {
                                Label(job.saved ? "Saved" : "Save", systemImage: job.saved ? "heart.fill" : "heart")
                            }
                            .buttonStyle(QuietButton())
                        }
                    }
                    .padding(20)
                }

                Picker("Section", selection: $tab.value) {
                    Text("Overview").tag(0)
                    Text("Details").tag(1)
                    Text("Company").tag(2)
                }
                .pickerStyle(.segmented)
                .frame(width: 320)

                Card {
                    VStack(alignment: .leading, spacing: 18) {
                        switch tab.value {
                        case 1: details(job)
                        case 2: company(job)
                        default: overview(job)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(24)
            .frame(maxWidth: 860, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private func overview(_ job: Listing) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            section("About the role", job.summary.isEmpty ? "\(job.sourceName) did not include a description for this listing." : job.summary)
            VStack(alignment: .leading, spacing: 8) {
                Label("Eligibility confirmed by source", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.success)
                evidence("Remote work", job.remoteEvidence)
                evidence("Part-time", job.partTimeEvidence)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.successBg)
            .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius))

            Text("Key details")
                .font(.system(size: 16, weight: .semibold))
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 12) {
                detailItem("Location eligibility", job.location)
                detailItem("Source", job.sourceName)
                detailItem("Category", job.category)
                detailItem("Last verified", relative(job.lastVerified))
                if !job.salary.isEmpty { detailItem("Salary", job.salary) }
            }
            linkBlock(job)
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
            Text(job.company).font(.system(size: 18, weight: .semibold))
            detailItem("Where you can work from", job.location)
            Text("The company name and location come from \(job.sourceName). This app does not keep a separate company profile.")
                .foregroundStyle(Theme.secondary)
            linkBlock(job)
        }
    }

    private func linkBlock(_ job: Listing) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Application link")
                .font(.system(size: 13, weight: .semibold))
            Button(job.applicationURL) { openExternal(job.applicationURL) }
                .buttonStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Theme.primary)
                .lineLimit(1)
            Label("Before you apply", systemImage: "info.circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.secondary)
                .padding(.top, 6)
            Text("You'll be redirected to the original listing on \(job.sourceName). Partly does not submit an application for you.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.secondary)
            Button("Report a problem") { model.showReport = true }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.secondary)
                .padding(.top, 4)
        }
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.text)
            Text(body).font(.system(size: 14)).foregroundStyle(Theme.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func evidence(_ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.success)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text)
                Text(body).font(.system(size: 12)).foregroundStyle(Theme.secondary)
            }
        }
    }

    private func detailItem(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 12)).foregroundStyle(Theme.secondary)
            Text(value).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.text)
        }
    }
}

struct ReportSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var reason = Hold(AppModel.ReportReason.stale)
    @StateObject private var details = Hold("")

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Report this listing")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .foregroundStyle(Theme.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            Text("Help keep the local list accurate. Why are you reporting this listing? The report stays on this Mac.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.secondary)
            ForEach(AppModel.ReportReason.allCases) { item in
                Button(action: { reason.value = item }) {
                    HStack(spacing: 8) {
                        Image(systemName: reason.value == item ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(reason.value == item ? Theme.primary : Theme.secondary)
                        Text(item.rawValue)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.text)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
            Text("Additional details (optional)")
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondary)
            TextField("", text: $details.value, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(3...5)
                .padding(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))
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
    }
}
