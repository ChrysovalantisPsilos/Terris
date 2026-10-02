# Terris — Xcode Handoff Checklist

The refactor below was written **without a
compiler** (no Swift toolchain / macOS in the automation environment).
Everything that could be done safely off-Xcode is committed and self-consistent.
This document lists what remains — the parts that touch the **Core Data model**
or need a build loop — in the exact order to do them.

> The project uses Xcode 16 **synchronized file groups**, so files added/deleted
> on disk need no `.pbxproj` edits. **Exception:** confirm the new
> `Resources/countryFacts.json` is in the target's *Copy Bundle Resources* phase
> (usually automatic; verify it loads).

---

## ✅ Already committed (verify these build)

- **Phase 1** — `OfflineCountryResolver` (offline point-in-polygon), `AssetImage`
  (on-demand thumbnails), reference-only photo storage, EXIF timezone fix.
- **Phase 2a** — live flight tracking removed; `LiveBadge` relocated to
  `FlightTrackerView`.
- **Phase 2b** — `TripTimelineView` + `TripType` deleted; Timeline nav removed;
  `attractionCount` + `Country.completionPercent` writes removed;
  `SectionHeader` relocated to `PhotoImportView`.
- **Phase 3** — globe defaults to muted style.
- **Phase 7** — bundled `countryFacts.json` + `CountryFacts` loader + a
  "Did You Know?" card on `CountryDetailPage`.

**First step in Xcode: build `main`-equivalent, then build this branch.** The
branch should compile *as-is* because the deleted entities (Region/Attraction/
Trip) still exist in the `.xcdatamodeld`, so the views that reference them
still resolve. The steps below then remove those entities.

---

## Phase 2c — Core Data schema collapse (the risky part)

Do this with the compiler running after each sub-step.

### 2c.1 — Model surgery (`Terris.xcdatamodeld`)
1. Delete entities **`Region`**, **`Attraction`**, **`Trip`**.
2. On **`TravelPhoto`**: delete attribute `imageData`; delete relationships
   `region`, `attraction`, `trip`.
3. On **`Country`**: delete relationships `regions`, `trips`; delete attribute
   `completionPercent`. Add a to-many relationship **`cities`** →
   destination `City`, inverse `country`, delete rule Nullify.
4. On **`City`**: delete relationship `region`. Add a to-one relationship
   **`country`** → destination `Country`, inverse `cities`, delete rule
   Nullify. (City is now parented directly under Country.)
5. Because this is destructive and pre-release, **reset the store** rather than
   migrate: bump the model or delete the app from the simulator so the seed
   re-runs. (If there are real users, write a lightweight migration instead.)

### 2c.2 — Delete now-dead files
- `Views/PlaceDetail/PlaceDetailView.swift` — dead (nothing navigates to it),
  but it **defines `DateRow` and `AddPlaceSheet`, which `CountryDetailPage`
  uses.** Before deleting, **move `DateRow` and `AddPlaceSheet` (+ its
  `PlaceCompleter`) into a surviving file** (e.g. `CountryDetailPage.swift`),
  and rewrite `AddPlaceSheet` so it no longer creates Region/Attraction —
  City-only.
- `Views/PlaceDetail/StatusPickerView.swift` — only used by `PlaceDetailView`;
  delete once that's gone (or keep if you reuse it).

### 2c.3 — Rewrite references to deleted entities
- **`CountryDetailPage.swift`**
  - Remove the `placesTab`'s `attractionsSection` and any Region UI.
  - `citiesSection` / add-city: create `City` with `c.country = country`
    (was `c.region = region`).
  - The `.sheet(isPresented: $showAddRegion)` block in `body` creates a
    `Region` — remove it (and the `showAddRegion` state + its button).
  - Line ~680 `PhotoGridCell`: the `AssetImage(... legacyData: photo.imageData ...)`
    argument references the now-deleted attribute. **Drop the `legacyData:`
    argument** (the store is reset, so there's no legacy blob to fall back to).
  - The city count at ~line 211 uses `($0.cities ...)` via regions — recompute
    from `country.cities`.
- **`SearchView.swift`** — remove attraction search; replace every
  `city.region?.country` with `city.country`, and `attr.city?.region?.country`
  paths entirely.
- **`GlobeView.swift`** — one `Region` reference near the cities layer; it's
  likely `city.region?...`; change to `city.country?...` or drop.
- **`RootAdaptiveView.swift`** — the `visitedCities` `@FetchRequest` and the
  globe cities layer should still work (City keeps `status`); just confirm no
  `.region` traversal remains.

### 2c.4 — Grep gates (should all be empty when done)
```
grep -rn "Region\b\|Attraction\b\|\.trip\b\|imageData\|completionPercent\|\.region\b" --include=*.swift Terris/Terris
```

---

## Phase 4 — Navigation: collapse to 2 tabs
Currently three tabs remain (Globe, Flights, Stats). Target: **Map** + **Flights**.
- Fold Stats into the Map surface: keep the headline country count on/over the
  globe; move the full `StatsDashboardView` breakdown into a pull-up sheet or a
  toolbar-presented sheet from the Map.
- Remove the standalone Stats tab (iPhone) and Stats nav link (iPad).
- Move Search/Import into Map toolbar affordances.

## Phase 5 — Stats hero polish
- Make `visitedCount + livedInCount` over `/ 195` the single big number, and
  ensure it matches the globe shading exactly (same source of truth).
- (attractionCount already removed.)

## Phase 6 — Import-first onboarding + PHAsset scanner
Key architectural note discovered during Phase 1: **the system `PhotosPicker`
strips GPS/location EXIF** from delivered image data for privacy, so the true
"auto from photos" intake must be a **PHAsset library scan**, not the picker:
1. Request `PHPhotoLibrary` authorization on first launch.
2. `PHAsset.fetchAssets` → read `asset.location` (CLLocation) and
   `asset.creationDate` directly (no EXIF parsing, no stripping).
3. Resolve each `asset.location` via `OfflineCountryResolver` (already built).
4. Store `asset.localIdentifier` on `TravelPhoto` (schema already supports it).
5. Animate countries filling in on the globe as the scan runs.
6. Handle denied access: fall back to the empty globe + manual country tap.
`AssetImage` (already built) then renders everything from identifiers.

## Phase 8 — Cleanup & verify
- Run the grep gate from 2c.4.
- Update `TerrisTests`/`TerrisUITests` for the new surface.
- Manual pass: onboarding scan → globe shades → count → tap country → facts →
  flights list.
- Confirm CloudKit payload is now tiny (references, not blobs).

---

## Open risks (unchanged from the plan)
- `countries.geojson` border fidelity affects near-coast / disputed-border
  photo resolution.
- Home-exclusion (Phase not yet built) still needs a "home radius" model + UI;
  it was a design decision, not yet implemented in code.
- Flights are manual-entry only now that live tracking is gone — confirm the
  `AddFlightView` flow is sufficient.
