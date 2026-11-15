import AppKit
import Foundation

struct PublishedUpdate {
    let version: String
    let fileID: String
}

enum UpdateError: LocalizedError {
    case status(Int)
    case unreadable
    case asset
    case install

    var errorDescription: String? {
        switch self {
        case .status(let code):
            return "Couldn't check for updates (\(code))."
        case .unreadable:
            return "Couldn't read the update from Drive."
        case .asset:
            return "An update is published, but there is no installer for this Mac yet."
        case .install:
            return "The update downloaded, but it could not be installed."
        }
    }
}

enum AppUpdate {
    /// Public version.txt in the shared "Partly updates" folder. Publish overwrites this file, so the id stays put.
    private static let versionFileID = "1we_7HRlTkBf93zImrPo9_0w4Pve1uRS1"

    private static var assetKey: String {
        #if arch(arm64)
        "macos-aarch64"
        #elseif arch(x86_64)
        "macos-x64"
        #else
        "macos-aarch64"
        #endif
    }

    static var currentVersion: String { "\(Release.version).\(Release.build)" }

    static func remote() async throws -> PublishedUpdate {
        let data = try await bytes(from: driveDownloadURL(versionFileID))
        guard let text = String(data: data, encoding: .utf8) else { throw UpdateError.unreadable }
        let (version, files) = parsePublished(text)
        guard let fileID = files[assetKey] else { throw UpdateError.asset }
        return PublishedUpdate(version: version, fileID: fileID)
    }

    static func download(fileID: String) async throws -> URL {
        let data = try await bytes(from: driveDownloadURL(fileID))
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent("Partly-update.dmg")
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try data.write(to: dest)
        return dest
    }

    static func isNewer(_ latest: String, than current: String) -> Bool {
        guard let theirs = parseVersion(latest), let mine = parseVersion(current) else { return false }
        return theirs > mine
    }

    private static func driveDownloadURL(_ id: String) -> URL {
        URL(string: "https://drive.usercontent.google.com/download?id=\(id)&export=download&confirm=t")!
    }

    /// First line is the version. Later lines are `macos-aarch64=<file id>`.
    private static func parsePublished(_ text: String) -> (String, [String: String]) {
        let lines = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let version = lines.first ?? ""
        var files: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let split = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false).first,
                  let value = line.split(separator: "=", maxSplits: 1).dropFirst().first else { continue }
            let name = split.trimmingCharacters(in: .whitespaces)
            let id = value.trimmingCharacters(in: .whitespaces)
            if !name.isEmpty, !id.isEmpty { files[name] = id }
        }
        return (version, files)
    }

    private static func parseVersion(_ raw: String) -> (Int, Int, Int)? {
        let parts = raw.trimmingCharacters(in: .whitespacesAndNewlines).drop { $0 == "v" }.split(separator: ".")
        guard parts.count >= 3,
              let major = Int(parts[0]),
              let minor = Int(parts[1]),
              let patch = Int(parts[2]) else { return nil }
        return (major, minor, patch)
    }

    private static func bytes(from url: URL) async throws -> Data {
        var current = url
        for _ in 0..<3 {
            var request = URLRequest(url: current, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 120)
            request.setValue("Partly", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(code) else { throw UpdateError.status(code) }
            if let confirm = confirmURL(in: data) {
                current = confirm
                continue
            }
            return data
        }
        throw UpdateError.unreadable
    }

    private static func confirmURL(in data: Data) -> URL? {
        let head = data.prefix(64)
        guard let preview = String(data: head, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() else { return nil }
        guard preview.hasPrefix("<!doctype html") || preview.hasPrefix("<html") else { return nil }
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        let marker = "https://drive.usercontent.google.com/download"
        guard let start = text.range(of: marker) else { return nil }
        let rest = text[start.lowerBound...]
        let end = rest.firstIndex(of: "\"") ?? rest.endIndex
        var url = rest[..<end].replacingOccurrences(of: "&amp;", with: "&")
        if !url.contains("confirm=") {
            url += url.contains("?") ? "&confirm=t" : "?confirm=t"
        }
        return URL(string: String(url))
    }

    /// Replaces `/Applications/Partly.app` after this process quits, then clears quarantine.
    static func beginInstall(dmg: URL) throws {
        let work = FileManager.default.temporaryDirectory
            .appendingPathComponent("partly-update-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        let place = work.appendingPathComponent("place.sh")
        let install = work.appendingPathComponent("install.sh")
        try placeScript.write(to: place, atomically: true, encoding: .utf8)
        try installScript.write(to: install, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: place.path)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: install.path)

        let kick = Process()
        kick.executableURL = URL(fileURLWithPath: "/bin/bash")
        kick.arguments = [
            "-c",
            "nohup /bin/bash \"$0\" \"$1\" \"$2\" \"$3\" >/tmp/partly-update.log 2>&1 &",
            install.path,
            String(ProcessInfo.processInfo.processIdentifier),
            dmg.path,
            work.path,
        ]
        try kick.run()
        kick.waitUntilExit()
        guard kick.terminationStatus == 0 else { throw UpdateError.install }
    }

    private static let placeScript = """
    #!/bin/bash
    set -euo pipefail
    APP="$1"
    xattr -cr "$APP"
    rm -rf /Applications/Partly.app
    cp -R "$APP" /Applications/Partly.app
    xattr -cr /Applications/Partly.app
    chmod +x /Applications/Partly.app/Contents/MacOS/Partly
    """

    private static let installScript = """
    #!/bin/bash
    set -u
    PARENT="$1"
    DMG="$2"
    WORK="$3"
    while kill -0 "$PARENT" 2>/dev/null; do
      sleep 0.3
    done
    sleep 0.4
    if [ -d /Volumes/Partly ]; then
      hdiutil detach /Volumes/Partly -force >/dev/null 2>&1 || diskutil eject force /Volumes/Partly >/dev/null 2>&1 || true
    fi
    ATTACH=$(hdiutil attach -nobrowse -readonly "$DMG") || exit 1
    MOUNT=$(printf '%s\\n' "$ATTACH" | sed -n 's/.*\\(\\/Volumes\\/.*\\)/\\1/p' | tail -1)
    if [ -z "$MOUNT" ]; then
      exit 1
    fi
    PKG=$(find "$MOUNT" -name '*.pkg' -maxdepth 2 | head -1)
    if [ -z "$PKG" ]; then
      hdiutil detach "$MOUNT" >/dev/null 2>&1 || true
      exit 1
    fi
    pkgutil --expand-full "$PKG" "$WORK/pkg" || exit 1
    APP=$(find "$WORK/pkg" -name 'Partly.app' -type d | head -1)
    if [ -z "$APP" ]; then
      hdiutil detach "$MOUNT" >/dev/null 2>&1 || true
      exit 1
    fi
    if ! /bin/bash "$WORK/place.sh" "$APP"; then
      osascript -e "do shell script \\"/bin/bash '$WORK/place.sh' '$APP'\\" with administrator privileges" || {
        hdiutil detach "$MOUNT" >/dev/null 2>&1 || true
        exit 1
      }
    fi
    hdiutil detach "$MOUNT" >/dev/null 2>&1 || true
    open /Applications/Partly.app
    """
}
