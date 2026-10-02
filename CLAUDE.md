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
   figures, so they can never disagree. The denominator is 195.
4. **Design system only:** colours, fonts, radii and motion come from
   `Theme/` tokens. No raw `Color.pink`/hex in views. Light and dark for
   every token.
5. **Liquid Glass only on floating controls** (tab bar, floating buttons,
   map overlays) via the `Theme` helpers, never on content cards. Otherwise
   follow iOS conventions: large titles, inset-grouped lists, sheet detents,
   the system font, SF Symbols.
6. **No literal user-facing text in Swift:** strings go through
   `Localizable.xcstrings` keys.
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

## Map

```
Terris/
  project.yml                XcodeGen spec (the .xcodeproj is generated)
  Terris/
    TerrisApp.swift          entry, injects the Core Data context
    Persistence.swift        NSPersistentCloudKitContainer, first-run seed of 195 countries
    Terris.xcdatamodeld      Country, City, TravelPhoto, Flight (Region/Attraction/Trip pending removal)
    Models/                  static data: CountryData, Continent, CountryCentroids,
                             AirportDatabase, TravelStatus, CountryFacts
    Services/                OfflineCountryResolver (point-in-polygon), EXIFReader,
                             GeoMatchingService, AssetImage (PHAsset thumbnails)
    Resources/               countries.geojson, countryFacts.json
    Views/                   RootAdaptiveView (iPhone tabs / iPad split), Globe,
                             Flights, PlaceDetail, Photos, Search, Stats, Sidebar
  TerrisTests/, TerrisUITests/
.github/workflows/ios-app.yml   macOS CI: build, unit tests, snapshots by hand
docs/                        refactor plan and remaining model work
```

The revamp moves screens into `Map/`, `Flights/`, `Country/`, `Onboarding/`
feature folders with the layering above, plus `Theme/` and `Data/`.
