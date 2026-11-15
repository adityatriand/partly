import AppKit
import Foundation

struct RemoteRelease: Decodable {
    let version: String
    let build: Int
    let asset: String
}

enum UpdateError: LocalizedError {
    case status(Int)
    case unreadable
    case asset
    case install

    var errorDescription: String? {
        switch self {
        case .status(let code):
            return "The repository replied HTTP \(code)."
        case .unreadable:
            return "Couldn't read the update from the repository."
        case .asset:
            return "The repository update did not include Partly.dmg."
        case .install:
            return "The update downloaded, but it could not be installed."
        }
    }
}

enum AppUpdate {
    private static let manifest = URL(string: "https://raw.githubusercontent.com/adityatriand/partly/update/latest.json")!
    private static let diskImage = URL(string: "https://raw.githubusercontent.com/adityatriand/partly/update/Partly.dmg")!

    static func remote() async throws -> RemoteRelease {
        var request = URLRequest(url: manifest, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue("Partly/\(Release.version)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else { throw UpdateError.status(code) }
        guard let release = try? JSONDecoder().decode(RemoteRelease.self, from: data) else {
            throw UpdateError.unreadable
        }
        return release
    }

    static func download() async throws -> URL {
        var request = URLRequest(url: diskImage, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 120)
        request.setValue("Partly/\(Release.version)", forHTTPHeaderField: "User-Agent")
        let (temp, response) = try await URLSession.shared.download(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else { throw UpdateError.status(code) }
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent("Partly-update.dmg")
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.moveItem(at: temp, to: dest)
        return dest
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
