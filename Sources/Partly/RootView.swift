import AppKit
import PartlyCore
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider().overlay(Theme.border)
            Group {
                switch model.screen {
                case .find:
                    FindView(savedOnly: false)
                case .saved:
                    FindView(savedOnly: true)
                case .about:
                    AboutView()
                case .detail:
                    DetailView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 1000, minHeight: 680)
        .background(Theme.bg)
        .task { await model.start() }
        .onAppear(perform: Brand.applyIcon)
        .sheet(isPresented: $model.showReport) {
            ReportSheet()
        }
    }

    private var topBar: some View {
        HStack(spacing: 24) {
            HStack(spacing: 8) {
                BrandLockup(height: 28)
            }
            Spacer()
            HStack(spacing: 6) {
                nav("Find jobs", screen: .find) { model.showFind() }
                nav("Saved jobs", screen: .saved) { model.showSaved() }
                nav("About", screen: .about) { model.screen = .about }
            }
            Spacer()
            profile
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.white)
    }

    private func nav(_ title: String, screen: AppModel.Screen, action: @escaping () -> Void) -> some View {
        let on = model.screen == screen || (screen == .find && model.screen == .detail)
        return Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: on ? .semibold : .regular))
                .foregroundStyle(on ? Theme.primary : Theme.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(on ? Theme.primaryLight : .clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var profile: some View {
        Menu {
            Text("Jobs stay on this Mac. No account.")
        } label: {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(Theme.primary)
                .frame(width: 32, height: 32)
        }
        .menuStyle(.borderlessButton)
        .frame(width: 36)
        .accessibilityLabel("Local profile")
    }
}

struct AboutView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                BrandLockup(height: 32)
                Text("About")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.text)
                Text("Partly keeps your job list on this Mac. Nothing in the local database is uploaded.")
                    .foregroundStyle(Theme.secondary)
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Source")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Listings come from public feeds that allow reuse: Remotive, Jobicy, Remote OK, Arbeitnow, Himalayas, and RemoteJobs.org. Each job opens that source's own page. Only remote part-time listings are stored.")
                            .foregroundStyle(Theme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Link("Remotive", destination: Remotive.site)
                        Link("Jobicy", destination: Jobicy.site)
                        Link("Remote OK", destination: RemoteOK.site)
                        Link("Arbeitnow", destination: Arbeitnow.site)
                        Link("Himalayas", destination: Himalayas.site)
                        Link("RemoteJobs.org", destination: RemoteJobs.site)
                        Text("Refresh re-fetches those feeds and updates the list on this Mac. A new fetch is refused for 60 seconds. A source that fails does not delete the other jobs or mark old rows as just verified.")
                            .foregroundStyle(Theme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 8) {
                            Button(model.refreshing ? "Refreshing…" : "Refresh") { Task { await model.refresh() } }
                                .buttonStyle(PrimaryButton())
                                .disabled(model.refreshing)
                        }
                        Text("Reports stay pending on this Mac. There is no submission service.")
                            .foregroundStyle(Theme.secondary)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(32)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }
}

func openExternal(_ raw: String) {
    guard let url = URL(string: raw) else { return }
    NSWorkspace.shared.open(url)
}

enum Brand {
    static func applyIcon() {
        guard let url = BrandFile.url("AppIcon"), let image = NSImage(contentsOf: url) else { return }
        NSApplication.shared.applicationIconImage = image
    }
}

struct BrandLockup: View {
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
                .foregroundStyle(Theme.primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Partly")
    }
}
