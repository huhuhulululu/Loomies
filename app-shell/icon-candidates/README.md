# Loomies App Icon candidates

## SHIPPED — Icon Composer layered icon
`../ClosetApp/AppIcon.icon` — the primary app icon as an iOS 26 layered `.icon`
package. Motif: a feminine silk **woven loop** — a clay ribbon threaded through a
vertical loop on bone linen. Brand: bone `#F4F0E8`, clay `#9E5540`. Reproduces the
`FINAL-woven-loop.png` vector direction. No pre-cropped squircle (the system masks
it), no baked highlight.

### Structure (`icon.json`)
- **Background** = document `fill-specializations`: bone (light) / warm espresso
  `#231C18` (dark). The tinted/clear backgrounds are system-derived (see below).
- **Group "Woven Loop"** — matte on purpose: `glass:false`, `specular:false`. The
  only depth cue is the system `shadow` (`neutral`, opacity 0.28). Silk/linen reads
  soft-matte, not glossy, so we opt the layers out of the Liquid Glass gloss pass;
  toggle `glass` back on per-layer in the GUI if a glassy look is ever wanted.
  `lighting:"individual"` so the two layers light independently if glass is enabled.
  - **Layer "Loop"** — `Assets/loop.svg`: the vertical ellipse ring.
  - **Layer "Thread"** — `Assets/thread.svg`: the woven band (a main span + a
    re-emerging tab). The ring's right limb crosses **over** the thread and the
    thread merges with the left limb — that over/under is the weave.
- Layers are **flat** vector (single fill, no shading). Color is driven per
  appearance by layer `fill-specializations`, which recolor the artwork *through its
  alpha*, so one asset serves every variant. The `#9E5540` in the SVGs is only a
  standalone-preview default; `icon.json` overrides it.

### Six appearance variants — encoded vs system-derived (honest)
All six renditions render clean under `ictool` on this machine — **Icon Composer
1.2** (bundle 76, ships with Xcode 26.2). Every key below was verified one-by-one
against `ictool` (a successful render *is* the validation: if it renders, Icon
Composer can open it). The `.icon` / `icon.json` format is **not an Apple-published
schema**; this is the minimal, verified subset — nothing invented.

| Rendition | Source |
|---|---|
| **Default** (light) | hand-encoded — bone background + clay glyph |
| **Dark** | hand-encoded — espresso background + warm-clay glyph |
| **TintedLight / TintedDark** | glyph `fill:"automatic"` (inherits the system tint). The tinted **background can't be overridden in JSON** — the OS derives it. |
| **ClearLight / ClearDark** | **entirely system-derived** — the OS composes the clear/translucent look; not expressible in `icon.json`. Renders, but not authorable. |

So Default + Dark are fully authored; the tinted glyph opts into the system tint;
Clear and the tinted *background* are the OS's to compute. Anything a spec might ask
for in those two (bespoke Clear art, a custom tinted backdrop) needs the runtime, not
this file. Nothing here requires the Icon Composer GUI to open or ship — the GUI is
only for further art tweaks.

### Preview / re-render
```bash
ICTOOL="$(dirname "$(xcode-select -p)")/Applications/Icon Composer.app/Contents/Executables/ictool"
open -a "Icon Composer" ../ClosetApp/AppIcon.icon           # GUI
# one rendition at 2048px:
"$ICTOOL" ../ClosetApp/AppIcon.icon --export-image --output-file /tmp/icon.png \
    --platform iOS --rendition Default --width 1024 --height 1024 --scale 2
# sweep all six (Tinted* also accept --tint-color N --tint-strength N):
for R in Default Dark TintedLight TintedDark ClearLight ClearDark; do
  "$ICTOOL" ../ClosetApp/AppIcon.icon --export-image --output-file /tmp/icon-$R.png \
      --platform iOS --rendition "$R" --width 512 --height 512 --scale 1 || echo "FAIL $R"
done
```

### Regenerating the layer SVGs
`loop.svg` is one editable path; `thread.svg` is a sampled polygon, so edit geometry
here and re-run (flat fills only = portable SVG that Icon Composer recolors via
`fill`). Output into the bundle's `Assets/`:
```python
import math
CANVAS=1024; SHIFT=-52.0            # whole-mark left shift to recenter (tab is right-heavy)
R_OUT=(200.0,310.0); R_IN=(112.0,222.0); CY=512.0
DIP_XL,DIP_XR,DIP,H = 250.0,846.0,40.0,46.0
MAIN=(360.0,566.0); TAB=(770.0,822.0); STEP=4.0; CLAY="#9E5540"
def yc(x):
    t=max(0.0,min(1.0,(x-DIP_XL)/(DIP_XR-DIP_XL))); return CY+DIP*math.sin(math.pi*t)
def fr(a,b,s):
    n=int((b-a)/s); return [a+i*s for i in range(n+1)]+([b] if a+n*s<b else [])
def cap(xa,xb):
    p=[(x,yc(x)-H) for x in fr(xa,xb,STEP)]; yb=yc(xb); a=-90
    while a<=90: r=math.radians(a); p.append((xb+H*math.cos(r),yb+H*math.sin(r))); a+=12
    p+=[(x,yc(x)+H) for x in fr(xb,xa,-STEP)]; ya=yc(xa); a=90
    while a<=270: r=math.radians(a); p.append((xa+H*math.cos(r),ya+H*math.sin(r))); a+=12
    return "M "+" L ".join(f"{x+SHIFT:.2f} {y:.2f}" for x,y in p)+" Z"
def ell(cx,rx,ry):
    cx+=SHIFT; return f"M {cx-rx:.2f} {CY:.2f} a {rx:.2f} {ry:.2f} 0 1 0 {2*rx:.2f} 0 a {rx:.2f} {ry:.2f} 0 1 0 {-2*rx:.2f} 0 Z"
def wrap(b): return f'<svg xmlns="http://www.w3.org/2000/svg" width="{CANVAS}" height="{CANVAS}" viewBox="0 0 {CANVAS} {CANVAS}">\n{b}\n</svg>\n'
open("../ClosetApp/AppIcon.icon/Assets/loop.svg","w").write(wrap(
  f'  <path fill="{CLAY}" fill-rule="evenodd" d="{ell(512,*R_OUT)} {ell(512,*R_IN)}"/>'))
open("../ClosetApp/AppIcon.icon/Assets/thread.svg","w").write(wrap(
  f'  <path fill="{CLAY}" d="{cap(*MAIN)}"/>\n  <path fill="{CLAY}" d="{cap(*TAB)}"/>'))
```

### Integration checkpoint (owned by the project.yml / app-shell task — NOT this task)
- `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` already resolves to this bundle
  (`AppIcon.icon`) — no build-setting change needed for the name.
- A `.icon` is **not** exercised by `swift test`; it must be verified with a real
  `xcodebuild` (per CLAUDE.md's app-shell rule). **XcodeGen 2.45.4** globs
  `ClosetApp/` recursively and may not special-case `.icon` as a single bundle
  reference — confirm `actool` ingests `AppIcon.icon` (inspect the generated
  `.xcodeproj` / `Assets.car`), and add an explicit file reference if it recurses
  into `icon.json` + `Assets/`.
- Min deployment is iOS 26, so the `.icon` is primary; the raster below stays as the
  asset-catalog fallback.

## Raster fallback (kept — do not delete)
`../ClosetApp/Assets.xcassets/AppIcon.appiconset/AppIcon.png` / `SHIPPED.png` — the
prior 1024 RGB, no-alpha, full-bleed render (feminine silk ribbon + woven loop on
bone linen). Safety net for anything still reading the asset catalog.

## Alternates (older experiments)
- `feminine-silk-bow.png` — satin bow on linen (more gift/feminine)
- `feminine-felt-cord.png` — ivory cord on clay felt (more craft/loom)
- `FINAL-woven-loop.png` — the vector direction this `.icon` reproduces; `preview-mono.png` its mono study
- older vector experiments: A/B/C, `imagine-*`
