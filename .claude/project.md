# Project profile: Terris

The facts the generic skills (choose-skill, ship-feature, release-to-prod,
design-renders, brand-designs, delegate-and-review, improve-skills) need for
THIS project. The skills say how to work; this file says what's true here.
CLAUDE.md holds the code rules and the architecture map. The improve-skills
skill keeps this file current, so add project facts here, not in the skills.

## Product and people

- **What it is:** a native iOS travel-footprint app. It shades the countries
  you've been to on a globe and gives one headline number: countries out of
  197. Intake is import-first (it scans the photo library's locations), with
  manual country and city marking, a manual flight log, and bundled fun facts
  on each country page.
- **Stack:** SwiftUI, iOS 26, Core Data through `NSPersistentCloudKitContainer`
  (private iCloud database). There's no server and no website.
- **Owner:** Chrysovalantis Psilos. They decide product questions and approve
  releases (TestFlight / App Store) explicitly, every time.
- **Which skills to use:** the ones in this repo's `.claude/skills/`, copied
  from the expense-tracker (Budgeer) project. They are the maintained copies
  here; improve-skills edits them.
- **Owner preferences** (same as on Budgeer):
  - Decides from pictures: show renders or screenshots before design
    decisions.
  - Native iOS conventions are welcome: Liquid Glass on floating controls, a
    floating tab bar, sheets with detents. Glass never goes on content cards.
  - No unnecessary popups: edit and pick inline. Sheets only for real
    confirmations, destructive actions and focused flows.
  - Short, plain replies. Questions go as multiple choice with a
    recommendation.
  - Never commit real data (photos, locations, names); fixtures are fake.
  - Never print or commit secrets. Signing keys live only in GitHub secrets.

## Environments

- **No back end.** User data lives on the device and in the user's private
  iCloud database (CloudKit Development for debug builds, Production for
  TestFlight and the App Store).
- **Branches:** `develop` is where work lands; `main` is what's released.
  A release is the owner's go → fast-forward `main` → TestFlight. The
  TestFlight build runs on every push to `main` and only then (owner's
  rule, Oct 2026): never from `develop`, never by hand. The commit at the
  tip of a release must not say `[skip ci]`: GitHub then skips every
  workflow for the push, TestFlight included.
- **Apple:** team `Z9KGWP5G82` (the same paid account as Budgeer), bundle id
  `com.chrysovalantis.Terris`, iCloud container
  `iCloud.com.chrysovalantis.Terris` (register it in the developer portal if
  it isn't there yet; cloud signing can't create it).

## Commands

```bash
brew install xcodegen          # once
cd Terris && xcodegen generate # makes Terris.xcodeproj (never committed)
xcodebuild -project Terris/Terris.xcodeproj -scheme Terris \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

The Linux cloud sandbox has no Swift toolchain. Every compile and test runs
on CI (`.github/workflows/ios-app.yml`, macos-26 / Xcode 26.5). Push checked
batches; never push WIP just to see if it compiles.

## Git

- **Develop on `develop`,** or on a feature branch merged into it. Never
  rebase shared branches; merge.
- **Commit identity:** use the env vars
  `GIT_AUTHOR_NAME/GIT_COMMITTER_NAME="Chrysovalantis Psilos"` and
  `GIT_AUTHOR_EMAIL/GIT_COMMITTER_EMAIL=chrysovalantis.psilos@outlook.com`.
  Merges too.
- **No AI mentions:** no mention of AI, Claude, agent or assistant in commits,
  branch names, code or docs, and no Co-Authored-By or session trailers.
  Branches get plain names (`map-revamp`), never a tool's default like
  `claude/…`, even when a session suggests one. The check before every push:
  `git log origin/develop..HEAD --format='%an|%cn %B' | grep -iE "claude|co-authored|assistant"`
  (the only allowed hit is the file name `CLAUDE.md`).
- **Commit messages:** a short plain subject, then a body with what and why.
- **History:** the `claude/trip-tracking-review-fnxiys` branch predates these
  rules; its work was folded into `develop` as one commit. Don't build on it.

## Languages

- English only so far. User-facing text goes through a String Catalog
  (`Localizable.xcstrings`), not literals sprinkled in views, so a second
  language is a translation job, not a refactor.

## iOS app

- **Project:** XcodeGen (`Terris/project.yml`). The `.xcodeproj` is generated
  and gitignored. Sources are the `Terris/Terris` folder; tests are
  `Terris/TerrisTests` and `Terris/TerrisUITests`.
- **Xcode versions:** the owner builds with Xcode 27 on their Mac; CI uses
  Xcode 26.5 on macos-26 (iPhone 17, iOS 26.5). Every change must build on
  both.
- **Devices:** iPhone and iPad (`RootView` turns into a sidebar on iPad).
- **Privacy strings:** the photo-library scan needs
  `NSPhotoLibraryUsageDescription`; it's in `project.yml`.
- **TestFlight (the Budgeer setup):** `.github/workflows/ios-testflight.yml`,
  on every push to `main` (so a release = fast-forward `main`; a failed run
  is retried with GitHub's "Re-run jobs"). No `paths` filter: on a push it
  only sees the files of that push, so a docs-only tip skipped the build. macos-26 / Xcode 26.5,
  `xcodebuild archive` + `-exportArchive` (app-store-connect, upload) with
  `-allowProvisioningUpdates` and the App Store Connect API key: cloud
  signing, no certificate or profile stored. Build number = the run number.
  GitHub secrets (names only): `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`
  (the whole .p8, BEGIN/END lines included), `APPLE_TEAM_ID`. Terris has
  its **own** team API key ("Terris CI", Admin role, which cloud signing
  needs), never Budgeer's (owner's rule, Oct 2026). The issuer id and team id
  are the account's, so they match Budgeer's by nature. **Certificates (owner's rule, 2 Oct 2026): the Terris pipeline
  must never revoke Budgeer's certificates.** At the end of each run it
  revokes only the development certificate that run created, matched by
  fingerprint against the runner's keychain (`scripts/asc/certificates.mjs`,
  tested by `certificates.test.mjs`). There is no "revoke all Created via
  API" step. If the team's development-certificate slots are ever full of
  Budgeer's leftovers, the archive fails: free a slot in the developer portal
  or let Budgeer's own pipeline clean up, never from Terris.
  One-time steps by hand: the app record in App Store Connect
  (`com.chrysovalantis.Terris`), and the iCloud container
  `iCloud.com.chrysovalantis.Terris` registered in the developer portal and
  assigned to the App ID (cloud signing can't create containers, as with
  Budgeer's App Groups). **CloudKit schema:** CloudKit only creates record
  types lazily as data syncs, so the schema is made on purpose: in Xcode,
  Edit Scheme → Run → Arguments, tick `-initCloudKitSchema`, run once
  (Debug) on a device signed in to iCloud, untick; the console log says
  "CloudKit schema: created". Then CloudKit Console → the container →
  Development shows the `CD_…` record types → Deploy Schema Changes to
  Production. Repeat after every model change, before the TestFlight build
  that needs it. (2 Oct 2026: both environments were still empty.)
  `ITSAppUsesNonExemptEncryption` is NO.
- **CI minutes are scarce** (macOS costs 10x). `ios-app.yml` runs on pushes
  to develop that touch the app, on pull requests, and by hand. Snapshots are
  taken only on runs by hand with "snapshots" ticked.

## Screenshots and design renders

- **Concept rounds (look undecided):** HTML prototypes in the session
  scratchpad that imitate iOS 26 (Liquid Glass tab bar, large titles, sheets)
  with the Terris tokens and real geography from `countries.geojson`
  (projected with d3-geo). Shoot with Playwright at 402×874, dsf 2.
- **Browser:** Chromium at `/opt/pw-browsers/chromium-1194/chrome-linux/chrome`,
  Playwright from `/opt/node22/lib/node_modules/`. Never run
  `playwright install`.
- **Built screens:** snapshot tests on CI (the `snapshots` artifact), as on
  Budgeer.

## Brand

- **Mark (Oct 2026, picked by the owner from 8 concepts):** "Summit Flag",
  a coral flag planted on a teal hemisphere with a globe grid: calm pride
  in the places you've stood. Masters in `docs/brand/svg/`, sheet
  `docs/brand/brand-sheet.png`, notes `docs/brand/README.txt`.
- **Wordmark:** "Terris" in Outfit Bold, tracking −1%, outlined in the SVGs.
- **Colours:** the Theme tokens: coral `#E8613C` (visited, accent), teal
  `#1F7A8C` (lived), amber `#F2B134` (want to go, hatched), ink `#17212B`,
  canvas `#F7F5F0`; dark variants in `Theme/Theme.swift`.
- **App icon:** `AppIcon.appiconset` has light (opaque), dark and tinted
  (transparent) 1024 px PNGs, the mark inside the central 80%.
- **Headline count:** "of 197": the country list includes Taiwan and
  Kosovo (owner's call, Oct 2026).

## Follow-ups a feature here usually needs

- **Core Data model change:** add a new model version (lightweight
  migration; new attributes optional). Then, BEFORE main is pushed (main
  pushes go straight to TestFlight, which syncs with CloudKit Production):
  the owner runs the develop build from Xcode with -initCloudKitSchema and
  deploys the schema to Production. A field missing from the Production
  schema breaks iCloud sync for that record type. v3 (Oct 2026) added
  Country.coverPhoto.
- **CloudKit:** new attributes must be optional or have defaults, and
  relationships must have inverses (CloudKit rule).
- **Privacy:** new data types or permissions get a usage string and a line in
  the App Store privacy answers.
- **Docs:** CLAUDE.md's architecture map.
