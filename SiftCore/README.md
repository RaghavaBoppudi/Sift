# SiftCore

Logic-only Swift package: no UI, no persistence, no network. Parses an Apple Passwords
CSV export and flags two things:

1. **Conflict groups** — same username + same registrable domain, but not all rows share
   one password (the Meta example: `meta.com`, `accounts.meta.com`, `business.meta.com`,
   same email, two different passwords in the mix).
2. **Reuse groups** — the same password used across otherwise-unrelated logins.

## Not done yet / known gaps

- `DomainResolver` hardcodes a handful of common two-label public suffixes (`co.uk`,
  `com.au`, etc.) instead of using a real Public Suffix List. It'll get the common cases
  right and misgroup obscure ones. Swap in a real PSL before this matters for real.
- No handling yet for cross-brand domains (`facebook.com` vs `fb.com`) — out of scope
  for v1, per the architecture doc.
- Untested on Linux/against a real Swift toolchain — this was written and reviewed by
  hand without a compiler in the loop. Run `swift test` on your Mac first and expect to
  fix small things (typos, a missed edge case) before trusting it.

## Try it

```bash
swift test
```

Then, once it's green, feed it your actual export:

```swift
let text = try String(contentsOf: yourCSVFileURL, encoding: .utf8)
let entries = try CSVImporter.parse(csvText: text)
let result = ConflictAnalyzer.analyze(entries)
print("\(result.conflictGroups.count) conflict groups, \(result.reuseGroups.count) reuse groups, \(result.uncategorized.count) uncategorized")
```
