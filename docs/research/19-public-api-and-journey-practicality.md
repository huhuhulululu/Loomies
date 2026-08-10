# 19 — Public API + customer journey practicality (US TestFlight)

**Date:** 2026-08-07  
**Scope:** Read-only codebase audit of customer journeys + free/no-key public APIs.  
**Sources:** ClosetCore / ClosetModel / ClosetIntake / ClosetUI / app-shell (file:function evidence).  
**Not verified here:** live network calls, TestFlight binary contents, `git status` dirty set.

---

## Executive summary

| Area | Practical status for US TF tester |
|------|-----------------------------------|
| Onboarding → 4 tabs | **Shipped** — name + city required; body optional; auto-seeds samples |
| Today weather | **Shipped** live Open-Meteo → offline climate; **°F only on Today** (source honesty buried in Me/About) |
| Today Save / Plan / Wore it | **Shipped** with honest flash paths |
| Today cold start | **Shipped** banner + sample seed CTA |
| Closet search / filter / edit / delete | **Shipped** (search facets partial in UI) |
| Intake photo | **Shipped** PHPicker + camera strings; Vision matting on device |
| Intake barcode | **UI + client shipped** — **manual UPC only**, no camera barcode scan |
| Intake OCR | **Protocol + mock only** — no real wash-label OCR |
| Me body / city | **Shipped** dual-track body + city edit |
| Favorites / Calendar | **Shipped** (Favorites nested under Me, not top tab) |
| Export / delete all | **Shipped** share sheet + confirm delete |
| Public size hints | **Shipped** reference captions (not brand-true) |

**Public API stack (D77):** Open-Meteo, Open Product/Beauty/Food Facts, `PublicSizeReference`, composite offline weather fallback — present in tree with unit tests. Treat FEATURE-GAP “offline only weather” as **stale** vs code/ARCHITECTURE/decisions D77.

---

## 1. Onboarding

### Implemented
| Step | Evidence |
|------|----------|
| Gate: empty wardrobe → onboarding | `app-shell/ClosetApp/ClosetApp.swift` `RootView` — `activeWardrobe` nil → `OnboardingScreen` |
| Name + city required | `OnboardingViewModel.canFinish` / `finish(in:)` — `Packages/ClosetUI/.../OnboardingViewModel.swift` |
| Optional body type picker (skip OK) | `OnboardingScreen` Form “Body (optional)” + `popularShapePick` |
| Persist Person + Main wardrobe + optional `PersonBodyProfile` | `OnboardingViewModel.finish(in:)` |
| Auto sample seed after finish | `RootView` onFinish → `DemoSeedService.seedIfEmpty` |
| Delete-all returns to onboarding | `MeView` delete receipt comment + empty `@Query` wardrobes |

### Missing / weak
| Gap | Notes |
|-----|--------|
| No measurement steppers on first launch | Body measures only in Me later (`BodyProfileView`) — intentional light onboarding |
| No explicit “skip samples” | Always seeds if empty after finish |
| City free-text only | No geocode picker; Open-Meteo geocodes later by string |

### US TestFlight practicality risk
- **Low** for first open: 2 fields + Get started works offline.  
- **Med:** Ambiguous city names (“Springfield”, “Portland”) → wrong geocode when online → wrong °F / outerwear until user edits Me → City.

---

## 2. Today (weather, Save / Plan / Wore it, cold start)

### Implemented
| Step | Evidence |
|------|----------|
| Tab “Today” | `AppRootView` → `CopilotView` |
| Bootstrap weather | `CopilotView.bootstrap()` → `vm.applyWeather(CompositeWeatherProvider.production)` |
| Live weather | `OpenMeteoWeatherProvider.daytimeTemperatureF` geocode + daily max °F |
| Offline fallback | `CompositeWeatherProvider` catch → `CityClimateWeatherProvider` (US-heavy city table) |
| City change recompute | `CopilotView` `.onChange(of: vm.wardrobe.locationCity)` → `reapplyWeatherAfterCityChange()` |
| °F pill on hero | `CopilotView` metaPill `%.0f°F` |
| Occasion + refresh / full-auto | `CopilotViewModel.refresh`, `fullAuto`, cold-start forces anchors |
| Save favorite | `OutfitActionsViewModel.saveFavorite` + UI “Save” |
| Plan today | `OutfitActionsViewModel.planToday` → favorite + `CalendarPlanService.plan` |
| Wore it | `CopilotWoreIt.perform` + flash; re-refresh for anti-repeat |
| Cold start banner | `isColdStart` (<8 available or debug force) + “Load sample pieces” |
| Empty look honesty | `CopilotEmptyDressOverlay`, status messages for empty closet / anchors |

### Missing / weak
| Gap | Evidence / impact |
|-----|-------------------|
| ~~**No live vs offline source on Today chrome**~~ | **Shipped:** `weatherSourceLabel` under °F + VO (`Open-Meteo` / `Offline estimate` / `Unavailable`) |
| ~~Weather protocol returns bare `Double`~~ | **Shipped:** `WeatherDaySnapshot` + `WeatherSnapshotProviding` (source + precip) |
| Feature journey weather test uses offline only | `FeatureJourneyTests.journeyWeatherAndCityClimate` → still Fixed/climate; live Open-Meteo covered in Core `PublicAPITests` |
| ~~FEATURE-GAP offline-only weather~~ | **Synced:** FEATURE-GAP lists Open-Meteo + Composite + barcode + size ref (D77) |

### US TestFlight practicality risk
- **Low–Med:** Online → Open-Meteo should work without keys; offline → climate table still produces wearable °F.  
- **Low honesty:** Source label on Today; rain/cool outerwear cue when precip ≥50% or &lt;60°F.  
- **Med:** Default post-onboarding sample wardrobe can leave cold-start quickly; real empty closet needs sample CTA or Add piece.

---

## 3. Closet (search / filter / edit / delete)

### Implemented
| Step | Evidence |
|------|----------|
| Grid + empty states | `ClosetGridView` in `AppRootView.swift` |
| Status chips | available / inWash / dryCleaning / idle / lent |
| Search toggle | magnifyingglass → text + **slot chips from `GarmentSlot.allCases` + `displayTitle`** |
| Search engine | `SearchViewModel` → `SearchService.searchItems` (name/brand, slot, occasion, status, wardrobe scope) |
| Add piece | `+` → `AddPieceSheet` |
| Detail edit | `ItemDetailView` + `ItemDetailViewModel` (name, slot, brand, size, occasions, status, flat measures, fit mark) |
| Delete piece | confirmation → `vm.delete` → `DeleteService.deleteItem` (outfits permanentlyMissing, calendar attention) |
| Transfer | toolbar → `TransferViewModel` / `TransferSheet` |
| Size reference caption | `PublicSizeReference.displayHint` on detail Size field |

### Missing / weak
| Gap | Notes |
|-----|--------|
| Search UI omits occasion + status facets | VM supports them; Closet only exposes text + slot |
| No multi-select bulk delete | Per-item only |
| Cross-wardrobe search | Service supports `wardrobeID == nil`; Closet always scopes to current wardrobe |

### US TestFlight practicality risk
- **Low** for daily closet ops.  
- **Low–Med:** Tagging defaults to mock on intake → slot/color may need manual fix on detail.

---

## 4. Intake (photo / barcode / OCR)

### Implemented
| Step | Evidence |
|------|----------|
| Sheet entry | `ClosetGridView` / empty → `AddPieceSheet` (`PhotoCaptureViews.swift`) |
| Photo library | `PhotoLibraryPicker` + `NSPhotoLibraryUsageDescription` |
| Camera | `CameraCapturePicker` + `NSCameraUsageDescription` (“Scan garments…”) |
| Process pipeline | `IntakeViewModel.process` + matting/tagging/ocr DI |
| Device matting | `IntakeServiceFactory.makeMatting` → `VisionMattingService` on iOS device |
| Confirm → Item + image store | `IntakeViewModel.confirm` |
| Manual path | “Enter manually” mode |
| **Barcode field + Lookup** | Form: `TextField("Barcode (UPC/EAN)")` + `Button("Lookup product (Open Facts)")` → `enrichFromPublicBarcode` |
| Product client | `OpenProductFactsClient` chains OPF / Beauty / Food hosts |
| Non-overwrite enrich | fills empty brand/name/quantity only |
| Footer honesty | “Open Product/Beauty/Food Facts (public, no key)” |
| Size hint on intake | `PublicSizeReference.displayHint` |

### Missing / weak
| Gap | Evidence |
|-----|----------|
| **No barcode camera / DataScanner** | Grep: no `DataScanner` / `VNBarcode` / AVCapture barcode path |
| **OCR always mock** | `IntakeServiceFactory.makeOCR` → `MockOCRService` only (comment: RecognizeDocumentsRequest not wired) |
| **Tagging always mock** | `makeTagging` → `MockTaggingService` (“云端 VLM 未接”) |
| Open*Facts apparel coverage thin | Many US clothing UPCs missing → “No public product record…” |
| Quantity → size field | May put pack size string into “size” (not garment size) |

### US TestFlight practicality risk
- **High for “scan barcode like retail apps”:** must type UPC by hand.  
- **High for wash-label auto-fill:** OCR does not run real Vision document OCR.  
- **Med for photo cutout:** works on device; simulator mock only.  
- **Med product lookup:** cosmetics/packaged goods hit rate >> fashion apparel.

---

## 5. Me (body / city)

### Implemented
| Step | Evidence |
|------|----------|
| Closet name / item counts | `MeView` |
| City edit | `ClosetCityEditView` + Open-Meteo honesty caption |
| Body measurements dual-track | `BodyProfileView` + `BodyProfileViewModel` (shape pick, sex, phenotype, steppers, fine-tune) |
| Personal color | `PersonalColorView` |
| Storage locations | `StorageLocationsView` |
| Wardrobe manage | `WardrobeManageView` |
| Favorites link | NavigationLink → `FavoritesView` |
| Demo seed | “Load sample pieces” |
| About + privacy blurb | `AboutView` |
| Diagnostics export | `DiagnosticsExport` + share sheet |
| Debug panel | `DebugSettings` (cold start force, anti-repeat off, etc.) |

### Missing / weak
| Gap | Notes |
|-----|--------|
| Body avatar catalog gaps surface in UI | Certification / basewear labels when assets incomplete |
| No push of body shape recompute toast on Today | Today reads body on bootstrap only |

### US TestFlight practicality risk
- **Low** for setting city/body.  
- **Med:** imperial default + metric toggle exists in body UI — OK for US; users who skip body get weaker fit marks.

---

## 6. Favorites / Calendar

### Implemented
| Step | Evidence |
|------|----------|
| Save from Today → favorite outfit | `OutfitFavoriteService.saveFavorite` |
| Favorites list | `FavoritesView` — swipe plan today, swipe delete unfavorite |
| Calendar tab | `CalendarView` list / attention toggle / plan from favorites sheet / swipe delete |
| Plan needsAttention | missing/transfer pieces → attention flag |
| Model services | `CalendarPlanService`, `OutfitFavoriteService` |

### Missing / weak
| Gap | Notes |
|-----|--------|
| Favorites not a root tab | Nested under Me → “Looks” (discoverability) |
| No month grid calendar | List + date picker only |
| Plan default day = today from Today CTA | Calendar sheet allows other days |

### US TestFlight practicality risk
- **Low–Med:** Full loop works after Save; empty Calendar empty-state points users correctly.  
- **Med UX:** Users may not find Favorites under Me.

---

## 7. Data export / delete

### Implemented
| Step | Evidence |
|------|----------|
| Export JSON | `DataLifecycleService.exportJSONString` — optional body dimensions toggle |
| iOS share sheet | `MeView` → `ActivityView` / `ShareBox` |
| Delete all + confirm | `deleteAllUserData` — plans, wear, outfits, items, locations, wardrobes, persons, body; wipe item images |
| Uninstall ≠ iCloud wipe copy | Caption on Me Data section |
| Diagnostics (support) | separate from user data export |

### Missing / weak
| Gap | Notes |
|-----|--------|
| No account / server delete | Local-first; CloudKit private lib not enabled in MVP path |
| Export is JSON dump not pretty “human report” | Fine for portability / CCPA-style exercise |

### US TestFlight practicality risk
- **Low** for beta privacy story if CloudKit off.  
- **Med** if CloudKit later enabled without matching remote wipe.

---

## 8. Public APIs (detail)

### Stack present in repo

| API | Role | Implementation | Tests |
|-----|------|----------------|-------|
| Open-Meteo Geocoding + Forecast | City → lat/lon → daily max °F | `Packages/ClosetCore/.../OpenMeteoWeatherProvider.swift` | `PublicAPITests` |
| Offline climate | Fallback / no network | `CityClimateWeatherProvider` in `WeatherProviding.swift` | Core + UI tests |
| Composite | Production DI | `CompositeWeatherProvider.production` | composite fallback test |
| Open Product/Beauty/Food Facts | Barcode → name/brand | `OpenProductFactsClient` | parse + fixture transport |
| Public size bridge | US/EU/UK display hints | `PublicSizeReference` | unit tests |
| Transport | URLSession + Fixture | `PublicAPITransport.swift` | fixtures |

### UI exposure audit

| Capability | Exposed in UI? | Where |
|------------|----------------|-------|
| Live weather used | **Yes** | Today bootstrap + city onChange |
| Weather source honesty | **Yes** | Today caption under °F (`weatherSourceLabel`) + Me City / About |
| Barcode lookup button | **Yes** | Intake confirm form after photo draft |
| Barcode camera scan | **No** | Manual type/paste only (`barcodeEntryCaption`) |
| Size reference hints | **Yes** | Item detail + Intake size field |
| Product source host shown | **Yes** (hit) | `statusMessage` “Filled empty fields from {host}.”; miss/error via `lastError` |
| Storage location on piece | **Yes** | Detail picker + Closet/Search meta when assigned |

### Uncommitted / docs drift note
- Code + tests + `docs/decisions.md` **D77** + `docs/ARCHITECTURE.md` + FEATURE-GAP public-API rows describe the stack.  
- This research page re-audited **2026-08-08** against post-TF27 polish (weather source, barcode status, storage assign).  
- Uncommitted working tree may still hold polish not yet in a TF build — ship only after archive includes those commits.

### Deferred (explicit)
- WeatherKit (protocol ready, Apple capability)  
- Paid UPC / brand size-chart APIs  
- Fashion catalog APIs (ToS)

---

## 9. Journey matrix (pass / weak / fail for TF demo)

| Customer step | Status | Practicality (US TF) |
|---------------|--------|----------------------|
| Install → welcome name/city | Pass | Low risk |
| Optional body type | Pass | Low risk |
| Land on Today with samples | Pass | Low risk |
| See temperature for city | Pass | Source label on Today |
| Occasion switch → new looks | Pass | Low risk |
| Anchor piece (cold start) | Pass | Med if user clears samples |
| Save look | Pass | Low risk |
| Plan look | Pass | Low risk |
| Wore it + anti-repeat | Pass | Low risk |
| Closet filter by status | Pass | Low risk |
| Search by name/slot | Pass | Low risk |
| Edit / delete item | Pass | Low risk |
| Assign storage location | Pass | Detail + list meta |
| Add photo from library | Pass | Device permissions |
| Camera capture | Pass (device) | Simulator weak |
| Auto cutout | Pass (device Vision) | Simulator mock |
| Type barcode → lookup | Pass (coverage dependent) | Med–High miss rate on apparel; hit/miss flash |
| Scan barcode with camera | **Fail / missing** | High if expected |
| OCR wash label | **Fail / mock only** | High if expected; captions honest |
| Set body measures / fit mark | Pass | Med engagement cost |
| Change city → weather updates | Pass | Med geocode ambiguity |
| Favorites list | Pass | Today toolbar heart |
| Calendar plan / attention | Pass | Low risk |
| Export data share | Pass | Low risk |
| Delete all data | Pass | Low risk |

---

## 10. Highest-impact TF practicality fixes (product, not exhaustive eng)

1. ~~**Today weather honesty**~~ — **done** (`weatherSourceLabel` + precip cue).  
2. **Barcode camera or paste-from-screenshot guidance** if marketing implies “scan.”  
3. **Real OCR or hide OCR promises** — captions honest (starter guesses); true OCR still mock.  
4. ~~**FEATURE-GAP / D77 sync**~~ — **done** (Open-Meteo + Open Facts + size ref listed).  
5. ~~**Favorites discoverability**~~ — **done** (Today toolbar → Favorites).  
6. ~~**Open*Facts expectation on miss**~~ — **done** (`lastError` + hit `statusMessage` with host).

---

## 11. Key file index

| Concern | Paths |
|---------|--------|
| Onboarding UI | `app-shell/ClosetApp/ClosetApp.swift` |
| Onboarding VM | `Packages/ClosetUI/Sources/ClosetUI/OnboardingViewModel.swift` |
| Today | `Packages/ClosetUI/Sources/ClosetUI/CopilotView.swift`, `CopilotViewModel.swift`, `OutfitActionsViewModel.swift` |
| Closet | `Packages/ClosetUI/Sources/ClosetUI/AppRootView.swift` (`ClosetGridView`) |
| Search | `SearchViewModel.swift`, `ClosetModel/SearchService.swift` |
| Item edit/delete | `FeatureViews.swift` (`ItemDetailView`), `ItemDetailViewModel.swift`, `DeleteService.swift` |
| Intake UI | `PhotoCaptureViews.swift` |
| Intake VM / factory | `ClosetIntake/IntakeViewModel.swift`, `IntakeServiceFactory.swift` |
| Me / export | `AppRootView.swift` (`MeView`), `DataLifecycleService.swift` |
| Calendar / favorites | `CompletenessViews.swift` (`CalendarView`), `FeatureViews.swift` (`FavoritesView`) |
| Weather | `WeatherProviding.swift`, `PublicAPI/OpenMeteoWeatherProvider.swift` |
| Product | `PublicAPI/OpenProductFactsClient.swift` |
| Sizes | `PublicAPI/PublicSizeReference.swift` |
| Journey tests | `ClosetUI/Tests/.../FeatureJourneyTests.swift` |
| ADR | `docs/decisions.md` D77 |

---

## Confidence

Code-path mapping is high (files read/grepped). Live Open-Meteo / Open*Facts success rates on US apparel UPCs and ambiguous cities were **not** measured in this pass. `git` cleanliness of D77 not verified.
