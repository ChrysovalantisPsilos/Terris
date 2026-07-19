# Terris — Implementation Plan

_Product refactor plan derived from the design review. This is a redesign
that is mostly **subtraction**: Terris becomes one focused thing instead of
three unrelated apps sharing a binary._

---

## The product, in one line

**A "where I've been" footprint app that fills itself from your photo library.**
One hero screen (a shaded-country globe + a big country count), near-zero
manual entry, offline-first.

## Locked decisions

| Area | Decision |
|---|---|
| Core job | Quantify travel — **countries visited + map coverage** is the hero |
| Headline | Big country count (`X / 195`) over a globe shaded by footprint |
| Coverage metric | Simple `countries / 195`. Not landmass. |
| Data source | **Auto from photos** (EXIF geotag + date). Manual is fallback. |
| Photo storage | **Reference only** — `assetIdentifier` + lat/lon/date. No image blobs in Core Data / CloudKit. |
| Geo resolution | **Offline point-in-polygon** vs bundled `countries.geojson`. `CLGeocoder` only for optional, cached city names. |
| Travel vs life | **Home-radius exclusion** — photos near home don't count. |
| Hierarchy | **Country + City only.** Drop Region + Attraction entities. |
| Flights | **Cut live OpenSky tracking.** Keep flights as historical stat data only. |
| Trips / Timeline | **Cut entirely** for now (no auto source, not part of hero). |
| Globe render | **Flat muted base as default;** satellite becomes an optional toggle. |
| Navigation | **2 tabs** — Map (footprint + stats) and Flights. Rest in sheets. |
| First run | **Import-first onboarding** — grant access, scan, watch countries fill in. |
| Discovery / recs | **Cut.** No activities/recommendations guide. |
| Fun facts | **Keep, bundled static** — `countryFacts.json`, 2–3 facts/country, offline, shown on every country page. |

---

## Sequencing principle

Fix the load-bearing bugs first (they're cheap and they de-risk everything
downstream), then collapse the schema, then rebuild the surface, then add the
delight. Each phase should leave the app **compiling and runnable**.

---

## Phase 0 — Safety net & baseline

- Confirm the project builds on the current `main` before touching anything.
- Note: there is a Core Data + CloudKit store. **Schema changes below are
  destructive to existing local data.** Because this is pre-release, plan to
  **reset the store / bump the model** rather than write migrations. Document
  that decision in the commit.
- Capture a screenshot of the current app state for before/after.

**Exit:** clean build, known baseline.

---

## Phase 1 — Fix the load-bearing bugs (no schema change yet)

These are correct-regardless fixes and make the photo pipeline actually work.

1. **Stop cloning the photo library into Core Data / CloudKit.**
   - `Views/Photos/PhotoImportView.swift`: remove `photo.imageData = imageData`
     (the `jpegData(...)` re-encode + blob store). Persist only
     `assetIdentifier`, `latitude`, `longitude`, `takenDate`.
   - Thumbnails load on demand from `PHImageManager` using `assetIdentifier`.
   - (Schema field `imageData` is formally removed in Phase 2.)

2. **Replace network geocoding with offline point-in-polygon.**
   - `Services/GeoMatchingService.swift`: resolve **country** locally against
     the bundled `Resources/countries.geojson` (ray-casting / MKPolygon
     `contains`). Build an in-memory index of `[isoCode: [polygons]]` once.
   - Keep `CLGeocoder` **only** for optional city-name enrichment, and cache
     it: dedupe lookups by a ~1 km coordinate grid so a whole trip costs a
     few calls, not hundreds.

3. **Fix EXIF timezone bug.**
   - `Services/EXIFReader.swift`: `DateTimeOriginal` is camera-local with no
     zone; the current `DateFormatter` parses it in device-local time,
     shifting `takenDate` by the device's UTC offset. Pin the formatter to a
     fixed interpretation (treat as wall-clock / store the naive local
     components) so dates don't drift. Document the chosen convention.

**Exit:** import 100+ photos → countries resolve offline, no blobs written, no
rate-limit failures, dates correct.

---

## Phase 2 — Collapse the schema

Model: `Terris.xcdatamodeld/Terris.xcdatamodel/contents`

- **Delete entities:** `Region`, `Attraction`, `Trip`. Remove their
  relationships from `Country`, `City`, and `TravelPhoto`.
- **`City`** keeps `name`, `latitude`, `longitude`, `status`, `firstVisitDate`,
  and its `country` relationship (re-parent City directly under Country if it
  currently routes through Region).
- **`TravelPhoto`**: remove `imageData`; keep `assetIdentifier`, `latitude`,
  `longitude`, `takenDate`, `caption`, `suggestedPlaceName`, and `country` /
  `city` relationships only.
- **`Country`**: keep footprint-relevant fields (`isoCode`, `name`,
  `continent`, `status`, `firstVisitDate`, `lastVisitDate`, `notes`,
  `rating`, `tags`). Drop `completionPercent` (was driven by the deleted
  hierarchy).
- **Keep** `Airport` + `Flight` (historical flight stats).
- Delete now-dead source files: `Views/Timeline/TripTimelineView.swift`,
  `Views/Flights/LiveFlightTrackingView.swift`,
  `Services/FlightLiveTrackingService.swift`, plus any Region/Attraction views.
- Remove OpenSky / ICAO callsign code paths.

**Exit:** builds with the trimmed model; no references to deleted entities.

---

## Phase 3 — Globe: make the data legible

`Views/Globe/GlobeView.swift`, `RootAdaptiveView.swift`

- Default `MapAppearance` → the **flat muted** style (was `hybridFlyover`).
- Keep satellite/hybrid as an **optional** pick in the existing style menu.
- Verify visited-country shading reads clearly against the muted base
  (status colors from `TravelStatus.color` should be the loudest thing).

**Exit:** first-open globe clearly communicates which countries are filled in.

---

## Phase 4 — Navigation: 2 tabs

`Views/RootAdaptiveView.swift`

- Collapse to **2 tabs: Map** (globe + stats) and **Flights**.
- Remove the **Timeline** tab entirely.
- Fold **Stats** into the Map surface: headline country count on/over the
  globe, full breakdown via a pull-up / sheet (reuse `StatsDashboardView`,
  minus the deleted `attractionCount` etc.).
- Keep the iPad `NavigationSplitView` adaptation, updated for the new
  structure.
- Move Search / Import / Settings into toolbar affordances, not tabs.

**Exit:** no empty/half-populated tabs; Map is the home.

---

## Phase 5 — Stats: one honest hero number

`Views/Stats/StatsDashboardView.swift`

- Hero = **`visitedCountries / 195`** as the big number + continents + cities.
- Remove `attractionCount` and any hierarchy-derived stats.
- Keep the by-continent breakdown (still meaningful).
- Ensure the count matches the globe shading exactly (single source of truth).

**Exit:** the number you screenshot is defined, correct, and matches the map.

---

## Phase 6 — Import-first onboarding

New: a first-run flow (e.g. `Views/Onboarding/OnboardingView.swift`)

- On first launch: request Photos access → background-scan the library →
  animate countries filling in on the globe as they resolve.
- Handle **access-denied** gracefully: fall back to the empty globe with a
  clear "Import photos" CTA and manual country tapping.
- Show scan progress; make the "wow" the onboarding itself.
- Replace/repurpose the current 2.2 s `LaunchScreenView` splash so it doesn't
  just delay an empty globe.

**Exit:** new user goes empty → populated globe in the first ~30 seconds.

---

## Phase 7 — Fun facts

New: `Resources/countryFacts.json` + a small loader

- `countryFacts.json`: keyed by ISO code, 2–3 short facts per country.
  Author incrementally; a partial file is fine (fall back to none).
- `Models/CountryFacts.swift`: load + look up by ISO.
- `Views/PlaceDetail/CountryDetailPage.swift`: show facts for **every**
  country (visited or not). The unvisited empty state becomes: flag + name +
  fun facts + set-status action — no dead end, no travel guide.

**Exit:** tapping any country shows something; unvisited pages aren't blank.

---

## Phase 8 — Cleanup & verify

- Delete dead assets, unused SF Symbols, orphaned view models.
- Update `TerrisTests` / `TerrisUITests` for the new surface.
- Manual pass: import → shade → count → tap country → facts → flights list.
- Confirm CloudKit sync payload is now tiny (references, not blobs).

---

## Risks / open items to watch

- **`countries.geojson` fidelity** — polygon resolution and disputed borders
  affect which ISO a coordinate resolves to; sea/near-border photos may miss.
  Acceptable for a footprint app; note the limitation.
- **Home-exclusion edge cases** — user relocates, or travels within their home
  country. Home is a radius, not a country; revisit if it feels wrong.
- **Flights data entry** — with live tracking gone, how flights get logged
  (manual add form remains). Confirm that's sufficient, or defer flights.
- **Destructive schema change** — acceptable pre-release; would need real
  migration if there are already users.
