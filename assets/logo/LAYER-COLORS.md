# CredOS logo source layers

The approved transparent logo is reconstructed from 54 grayscale PNGs: three RGB channel masks for each of its 18 visible elements. Every mask retains the original 1448 x 1086 canvas and position. Layers 01-12 form the symbol; 13-18 form the wordmark. These preserve the original visible pixels and gradients; hidden geometry is not reconstructed.

`reference.png` is the approved transparent full-size result. It retains the existing extraction's edge pixels and background mask. It is independent of the generated README preview in `../credos-logo.png`. CI compares the reconstruction against this reference in every RGBA channel with zero tolerance.

## Color mapping

`layer-colors.json` is the machine-readable build input. Each grayscale channel uses exactly one primary color: R = #FF0000, G = #00FF00, B = #0000FF. Multiply the grayscale intensity by that color while preserving alpha, then combine all contributions with **Plus/Add** at 100% opacity in stored sRGB values. Do not use flat color replacement, Screen, or linear-light blending. The current source masks have binary alpha; resized deliverables retain antialiased transparency.

For each original pixel `(r,g,b,a)`, the masks contain `(r,r,r,a)`, `(g,g,g,a)`, `(b,b,b,a)`. Coloring creates `(r,0,0,a)`, `(0,g,0,a)`, `(0,0,b,a)`. Addition recovers the original pixel. `Build-Logo.ps1` uses ImageMagick to perform this operation and checks the result before producing icons or archives.

## Build and update

Use PowerShell 7 and **ImageMagick 7.1.2-29 Q16-HDRI**. The CI bootstrap downloads the official portable Windows x64 archive, verifies its pinned SHA-256, and extracts it into `.artifacts/tools/` without changing machine configuration. CI uses this binary rather than the runner's installed ImageMagick.

From the repository root:

```powershell
# Windows x64: provision the exact CI toolchain in a child PowerShell session.
pwsh -NoProfile -Command './.github/scripts/Install-ImageMagick.ps1; ./Build-Logo.ps1 -Version 0.1.1 -CheckTrackedAssets'

# With the pinned magick already on PATH (including other operating systems):
pwsh -File ./Build-Logo.ps1 -Version 0.1.1 -CheckTrackedAssets
pwsh -File ./.github/scripts/Test-BrandingPipeline.ps1 -Version 0.1.1 -BrandingDirectory .artifacts/branding
```

The script accepts `-OutputDirectory` and optional `-Version`. A version produces `credos-branding-<version>.zip`; unversioned local builds still generate the package inputs. `branding-manifest.json` records all output hashes. PNG metadata and ZIP timestamps are normalized. `-CheckTrackedAssets` verifies that the tracked README logo and icon match generated files byte for byte.

For an intentional artwork change, update the grayscale masks, mapping, and approved reference together. Run the build without `-CheckTrackedAssets`, inspect the result, then refresh both tracked previews:

```powershell
pwsh -File ./Build-Logo.ps1
Copy-Item .artifacts/branding/credos-logo.png assets/credos-logo.png
Copy-Item .artifacts/branding/credos-icon.png assets/credos-icon.png
pwsh -File ./Build-Logo.ps1 -CheckTrackedAssets
```

The full-size logo keeps the exact source canvas. Smaller full logos fit within 512, 256, and 128 px. Symbol-only icons are centered on a square with 7.5% padding per side and rendered at 256, 128, 64, 32, and 16 px. `credos-icon.png` aliases the 128 px NuGet icon. `credos.ico` and `favicon.ico` contain all five symbol frames. The reference comparison occurs before resizing; smaller outputs necessarily resample the source.

NuGet packing reads the generated `credos-logo.png` and `credos-icon.png` from `.artifacts/branding` (override with `-p:BrandingDirectory=<absolute path>`). The tracked previews serve README display and freshness checks, rather than package fallback inputs. Only the full logo and package icon are included in NuGet; grayscale sources and the reference are not packed.

## Color for every grayscale layer

| Grayscale layer | Apply color | Channel |
| --- | --- | --- |
| [01-upper-blue-black-panel-R.png](layers/01-upper-blue-black-panel-R.png) | `#FF0000` | R |
| [01-upper-blue-black-panel-G.png](layers/01-upper-blue-black-panel-G.png) | `#00FF00` | G |
| [01-upper-blue-black-panel-B.png](layers/01-upper-blue-black-panel-B.png) | `#0000FF` | B |
| [02-upper-blue-overlap-facet-R.png](layers/02-upper-blue-overlap-facet-R.png) | `#FF0000` | R |
| [02-upper-blue-overlap-facet-G.png](layers/02-upper-blue-overlap-facet-G.png) | `#00FF00` | G |
| [02-upper-blue-overlap-facet-B.png](layers/02-upper-blue-overlap-facet-B.png) | `#0000FF` | B |
| [03-left-silver-panel-R.png](layers/03-left-silver-panel-R.png) | `#FF0000` | R |
| [03-left-silver-panel-G.png](layers/03-left-silver-panel-G.png) | `#00FF00` | G |
| [03-left-silver-panel-B.png](layers/03-left-silver-panel-B.png) | `#0000FF` | B |
| [04-left-blue-ribbon-R.png](layers/04-left-blue-ribbon-R.png) | `#FF0000` | R |
| [04-left-blue-ribbon-G.png](layers/04-left-blue-ribbon-G.png) | `#00FF00` | G |
| [04-left-blue-ribbon-B.png](layers/04-left-blue-ribbon-B.png) | `#0000FF` | B |
| [05-right-magenta-panel-R.png](layers/05-right-magenta-panel-R.png) | `#FF0000` | R |
| [05-right-magenta-panel-G.png](layers/05-right-magenta-panel-G.png) | `#00FF00` | G |
| [05-right-magenta-panel-B.png](layers/05-right-magenta-panel-B.png) | `#0000FF` | B |
| [06-lower-black-panel-R.png](layers/06-lower-black-panel-R.png) | `#FF0000` | R |
| [06-lower-black-panel-G.png](layers/06-lower-black-panel-G.png) | `#00FF00` | G |
| [06-lower-black-panel-B.png](layers/06-lower-black-panel-B.png) | `#0000FF` | B |
| [07-orange-ribbon-upper-facet-R.png](layers/07-orange-ribbon-upper-facet-R.png) | `#FF0000` | R |
| [07-orange-ribbon-upper-facet-G.png](layers/07-orange-ribbon-upper-facet-G.png) | `#00FF00` | G |
| [07-orange-ribbon-upper-facet-B.png](layers/07-orange-ribbon-upper-facet-B.png) | `#0000FF` | B |
| [08-orange-ribbon-front-R.png](layers/08-orange-ribbon-front-R.png) | `#FF0000` | R |
| [08-orange-ribbon-front-G.png](layers/08-orange-ribbon-front-G.png) | `#00FF00` | G |
| [08-orange-ribbon-front-B.png](layers/08-orange-ribbon-front-B.png) | `#0000FF` | B |
| [09-shield-left-facet-R.png](layers/09-shield-left-facet-R.png) | `#FF0000` | R |
| [09-shield-left-facet-G.png](layers/09-shield-left-facet-G.png) | `#00FF00` | G |
| [09-shield-left-facet-B.png](layers/09-shield-left-facet-B.png) | `#0000FF` | B |
| [10-shield-right-facet-R.png](layers/10-shield-right-facet-R.png) | `#FF0000` | R |
| [10-shield-right-facet-G.png](layers/10-shield-right-facet-G.png) | `#00FF00` | G |
| [10-shield-right-facet-B.png](layers/10-shield-right-facet-B.png) | `#0000FF` | B |
| [11-white-shield-outline-R.png](layers/11-white-shield-outline-R.png) | `#FF0000` | R |
| [11-white-shield-outline-G.png](layers/11-white-shield-outline-G.png) | `#00FF00` | G |
| [11-white-shield-outline-B.png](layers/11-white-shield-outline-B.png) | `#0000FF` | B |
| [12-white-keyhole-R.png](layers/12-white-keyhole-R.png) | `#FF0000` | R |
| [12-white-keyhole-G.png](layers/12-white-keyhole-G.png) | `#00FF00` | G |
| [12-white-keyhole-B.png](layers/12-white-keyhole-B.png) | `#0000FF` | B |
| [13-letter-C-R.png](layers/13-letter-C-R.png) | `#FF0000` | R |
| [13-letter-C-G.png](layers/13-letter-C-G.png) | `#00FF00` | G |
| [13-letter-C-B.png](layers/13-letter-C-B.png) | `#0000FF` | B |
| [14-letter-r-R.png](layers/14-letter-r-R.png) | `#FF0000` | R |
| [14-letter-r-G.png](layers/14-letter-r-G.png) | `#00FF00` | G |
| [14-letter-r-B.png](layers/14-letter-r-B.png) | `#0000FF` | B |
| [15-letter-e-R.png](layers/15-letter-e-R.png) | `#FF0000` | R |
| [15-letter-e-G.png](layers/15-letter-e-G.png) | `#00FF00` | G |
| [15-letter-e-B.png](layers/15-letter-e-B.png) | `#0000FF` | B |
| [16-letter-d-R.png](layers/16-letter-d-R.png) | `#FF0000` | R |
| [16-letter-d-G.png](layers/16-letter-d-G.png) | `#00FF00` | G |
| [16-letter-d-B.png](layers/16-letter-d-B.png) | `#0000FF` | B |
| [17-letter-O-R.png](layers/17-letter-O-R.png) | `#FF0000` | R |
| [17-letter-O-G.png](layers/17-letter-O-G.png) | `#00FF00` | G |
| [17-letter-O-B.png](layers/17-letter-O-B.png) | `#0000FF` | B |
| [18-letter-S-R.png](layers/18-letter-S-R.png) | `#FF0000` | R |
| [18-letter-S-G.png](layers/18-letter-S-G.png) | `#00FF00` | G |
| [18-letter-S-B.png](layers/18-letter-S-B.png) | `#0000FF` | B |
