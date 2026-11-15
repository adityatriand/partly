import AppKit
import PartlyCore
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    private var theme: Theme { model.dark ? .night : .light }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider().overlay(theme.border)
            FindView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 1000, minHeight: 680)
        .background(theme.bg)
        .environment(\.theme, theme)
        .preferredColorScheme(theme.scheme)
        .task { await model.start() }
        .onAppear {
            Brand.applyIcon()
            NSApp.appearance = NSAppearance(named: model.dark ? .darkAqua : .aqua)
        }
        .onChange(of: model.dark) { _, dark in
            NSApp.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        }
        .sheet(item: $model.selected) { _ in
            DetailView()
                .environmentObject(model)
                .sheetTheme(theme)
        }
        .sheet(isPresented: $model.showAbout) {
            AboutView()
                .environmentObject(model)
                .sheetTheme(theme)
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button { model.showFind() } label: {
                BrandLockup(height: 28)
            }
            .buttonStyle(PlainActionButton())
            .accessibilityLabel("Partly, back to jobs")
            Spacer(minLength: 0)
            Button { Task { await model.checkForUpdate() } } label: {
                Label(model.updating ? "Checking…" : "Check for updates", systemImage: "arrow.down.circle")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.secondary)
            }
            .buttonStyle(PlainActionButton())
            .disabled(model.updating)
            Button { model.toggleAppearance() } label: {
                Image(systemName: model.dark ? "sun.max" : "moon")
                    .font(.system(size: 16))
                    .foregroundStyle(theme.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(PlainActionButton())
            .accessibilityLabel(model.dark ? "Use light theme" : "Use dark theme")
            Button { model.showAbout = true } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 18))
                    .foregroundStyle(theme.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(PlainActionButton())
            .accessibilityLabel("About")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(theme.surface)
    }
}

struct AboutView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("About")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(theme.text)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.secondary)
                        .frame(width: 28, height: 28)
                        .background(theme.bg)
                        .clipShape(Circle())
                }
                .buttonStyle(PlainActionButton())
                .accessibilityLabel("Close")
            }
            Text("Version \(Release.version) (\(Release.build))")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.text)
            Button { Task { await model.checkForUpdate() } } label: {
                Text(model.updating ? "Checking…" : "Check for updates")
            }
            .buttonStyle(PrimaryButton())
            .disabled(model.updating)
            if let updateMessage = model.updateMessage {
                Text(updateMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Partly keeps your job list on this Mac. Nothing in the local database is uploaded.")
                .foregroundStyle(theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Listings come from public feeds that allow reuse. Each job opens that source's own page. Only remote part-time listings are stored.")
                .foregroundStyle(theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 6) {
                Link("Remotive", destination: Remotive.site).actionCursor()
                Link("Jobicy", destination: Jobicy.site).actionCursor()
                Link("Remote OK", destination: RemoteOK.site).actionCursor()
                Link("Arbeitnow", destination: Arbeitnow.site).actionCursor()
                Link("Himalayas", destination: Himalayas.site).actionCursor()
                Link("RemoteJobs.org", destination: RemoteJobs.site).actionCursor()
            }
            Text("Refresh re-fetches those feeds. A new fetch is refused for 60 seconds. A source that fails does not delete the other jobs.")
                .font(.system(size: 13))
                .foregroundStyle(theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Reports stay pending on this Mac. There is no submission service.")
                .font(.system(size: 13))
                .foregroundStyle(theme.secondary)
        }
        .padding(24)
        .frame(width: 460)
        .background(theme.bg)
    }
}

func openExternal(_ raw: String) {
    guard let url = URL(string: raw) else { return }
    NSWorkspace.shared.open(url)
}

enum Brand {
    @MainActor
    static func applyIcon() {
        // The packaged app already has AppIcon.icns. The PNG is 512px at 72 dpi,
        // so assigning it here makes the Dock draw a 512-point icon and the tile zooms up.
        if Bundle.main.url(forResource: "AppIcon", withExtension: "icns") != nil { return }
        guard let url = BrandFile.url("AppIcon"),
              let image = NSImage(contentsOf: url)?.copy() as? NSImage else { return }
        image.size = NSSize(width: 128, height: 128)
        NSApplication.shared.applicationIconImage = image
    }
}

struct BrandLockup: View {
    @Environment(\.theme) private var theme
    var height: CGFloat = 40

    var body: some View {
        HStack(spacing: 8) {
            if let url = BrandFile.url("AppIcon"), let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: height, height: height)
            }
            Text("Partly")
                .font(.system(size: height * 0.55, weight: .bold))
                .foregroundStyle(theme.primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Partly")
    }
}
