# Terris — code rules and architecture

Project facts (environments, git rules, owner preferences, commands) are in
`.claude/project.md`. This file holds the code rules and the map. The rules
are the bar for every change; code written before them is brought up to them
as screens are revamped.

## Rules

1. **Layers, one folder per feature** (the Budgeer pattern):
   - `XFigures.swift`: pure, `Equatable`/`Sendable` value types plus a
     `static func compute(_ input:) -> XFigures`. No SwiftUI, no Core Data,
     no wording. Every figure on screen comes from here, with unit tests.
   - `XModel.swift`: `@MainActor @Observable final class` with
     `enum State { loading, loaded(XFigures), failed(String) }`. It reads
     through the data layer (injected), calls `XFigures.compute`, and holds
     actions. A failed refresh keeps the last figures on screen.
   - `XView.swift`: layout only. `@State` only for UI-local things (a sheet,
     a picked tab). No fetch requests, no `ctx.save()` in views.
2. **Data access** lives in `Data/` (a store over Core Data). Views and
   figures never touch `NSManagedObjectContext`. Saves report errors to the
   model; no silent `try?` on writes.
3. **One source of truth for "been to":** visited + lived. The globe shading,
   the headline count and the continent breakdown all read it from the same
   figures, so they can never disagree. The denominator is the size of the
   country list (`CountryData.all`).
4. **Design system only:** colours, fonts, radii and motion come from
   `Theme/` tokens. No raw `Color.pink`/hex in views. Light and dark for
   every token.
5. **Liquid Glass only on floating controls** (tab bar, floating buttons,
   map overlays) via the `Theme` helpers, never on content cards. Otherwise
   follow iOS conventions: large titles, inset-grouped lists, sheet detents,
   the system font, SF Symbols.
6. **User-facing text is localizable:** `Text("…")` literals and
   `LocalizedStringKey` parameters (extracted to the String Catalog), never
   strings assembled in models or figures. English only for now.
7. **Photos stay references:** store `PHAsset.localIdentifier`, never image
   data. Locations resolve offline (`OfflineCountryResolver`); no network
   geocoding for the footprint.
8. **Privacy:** nothing leaves the device except the user's own iCloud
   (CloudKit private database). No analytics, no third-party SDKs without the
   owner's go.
9. **Tests:** every `Figures` type has unit tests; every screen has a
   snapshot test (light, dark) once the revamp lands. Fixtures are fake.
10. **No dead code:** remove unused views, models and files in the same
    change that orphans them.
11. **Default arguments run outside the main actor:** never construct a
    model (or anything `@MainActor`) in a default argument; default to nil
    and build it in the initializer.

## Map

```
Terris/
  project.yml                XcodeGen spec (the .xcodeproj is generated)
  Terris/
    TerrisApp.swift          entry: store, router, launch screen
    Persistence.swift        NSPersistentCloudKitContainer (in-memory under tests)
    Terris.xcdatamodeld      v2: Country ⇢ City, TravelPhoto, Airport, Flight
    App/                     RootView (Map · Flights · Search tabs, iPad sidebar,
                             first-launch scan), AppRouter, MapLayout, LaunchScreenView
    Data/FootprintStore      the only Core Data reads/writes for the footprint
    Theme/                   tokens (Theme), Liquid Glass helpers (Glass)
    Geo/                     Projection (orthographic, Equal Earth), WorldShapes
                             (countries.geojson), GlobeMap / FlatMap canvases
    Map/                     MapFigures (pure), MapModel, MapScreen (Globe, Journal,
                             Atlas layouts), MapComponents
    Country/                 CountryFigures + CountryModel, CountryScreen (sheet)
    Search/                  SearchScreen, CountrySearch (pure)
    Flights/                 FlightFigures (pure, great-circle routes, distance),
                             FlightDraft + AirportSearch (pure), FlightsScreen (tab),
                             FlightFormScreen (log / edit, inline airport pick),
                             FlightScreen (one flight)
    Onboarding/              PhotoScanner (PHAsset locations, offline), ScanTally
                             (pure), ScanScreen (first launch and the scan button)
    Models/                  static data: CountryData (the country list and the
                             denominator), CountryCentroids, AirportDatabase,
                             TravelStatus, CountryFacts
    Services/                OfflineCountryResolver (nonisolated, used off-main by the
                             scan), AssetImage (PHAsset thumbnails)
    Assets.xcassets          AppIcon (light, dark, tinted), BrandLockup, AccentColor
  TerrisTests/               Swift Testing: projections, figures, country, search,
                             shapes, flights, scan tally
docs/brand/                  logo masters (SVG), brand sheet, README
.github/workflows/ios-app.yml   macOS CI: build, unit tests, snapshots by hand
```
