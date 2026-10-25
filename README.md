# Partly

[![macOS](https://img.shields.io/badge/macOS-14%2B-000000?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)](https://www.swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-native-0A84FF)](https://developer.apple.com/xcode/swiftui/)
[![SQLite](https://img.shields.io/badge/SQLite-local-003B57?logo=sqlite&logoColor=white)](https://www.sqlite.org)
[![License](https://img.shields.io/badge/license-all%20rights%20reserved-lightgrey)](#license)

Remote part-time jobs, kept on your Mac.

`macos` · `swift` · `swiftui` · `sqlite` · `remote` · `part-time` · `local-first`

Native macOS app for finding remote part-time jobs and keeping them on your Mac. There is no account, no backend, and no upload of the local database.

Listings are loaded from public feeds that allow reuse — [Remotive](https://remotive.com), [Jobicy](https://jobicy.com), [Remote OK](https://remoteok.com), [Arbeitnow](https://www.arbeitnow.com), [Himalayas](https://himalayas.app), and [RemoteJobs.org](https://remotejobs.org). Only roles that are both remote and part-time are stored. Each job opens the original page on that source.

## Features

- Search, category, location, and posted-date filters over the local catalog
- Saved jobs, stored only on this Mac
- Detail page with the source's eligibility evidence and a link out to apply
- Report a listing. The report stays pending locally and is not submitted anywhere
- Manual refresh of six permitted feeds. A source that fails leaves that source's previous jobs in place
- Freshness is the last successful check, not the last time you opened the app

## Requirements

- macOS 14 or later
- Swift 6 (Xcode or the Command Line Tools)

## Getting started

```sh
swift run Check
```

`swift run Check` runs the catalog checks (part-time filtering, dedupe, failed refresh). It does not call the network.

The Finder name is Partly. The dock icon and the in-app mark come from `Sources/PartlyCore/AppIcon.png`.

`swift run Partly` needs the SwiftUI macro plugin, which ships with Xcode and is not in the Command Line Tools. This copy was compiled with `swiftc` for that reason.

The first window is empty until **Refresh** (or ⌘R) fetches the six feeds. The app will not fetch again for 60 seconds. An empty database refreshes once on launch.

Data lives in:

| File | Purpose |
| :---- | :---- |
| `~/Library/Application Support/Partly/jobs.sqlite` | Jobs, saved state, local reports |

## How a job gets in

1. A refresh downloads each feed.
2. Rows that are not clearly remote and part-time are dropped.
3. Rows are matched by source id, then by canonical URL, and written in one SQLite transaction.
4. After a successful catalog, older open rows from that source that were not in the catalog are marked missing. They are kept.
5. A failed download does not delete anything and does not move the verification time.

Deduplicating the same payload twice does not create a second row.

## Project layout

```
Sources/PartlyCore/     Catalog parsers and SQLite store
Sources/Partly/         SwiftUI app
Sources/Check/          Logic checks (`swift run Check`)
docs/SOURCES.md         Permission, fields, and rate limits per feed
```

## Source rules

Read [docs/SOURCES.md](docs/SOURCES.md) before enabling another feed. The app links back to the source and does not collect logins, emails, or pages that only happen to be public. HTML crawling of boards that do not offer a permitted feed is out of scope.

Jobicy, Remote OK, Arbeitnow, Himalayas, and RemoteJobs.org ask to be named and linked. Remotive also asks that its jobs not be pushed to other job boards.

## Development

```sh
swift run Check
swift build --target PartlyCore
```

`swift run Check` covers part-time filtering, dedupe, failed refresh, and missing listings. It does not call the network.

The interface follows the Partly desktop layout: list, detail, report, empty, unavailable, and error. The system font is used. Phone layouts from the design sheet are not a separate target.

## License

No license file has been added. All rights reserved.
