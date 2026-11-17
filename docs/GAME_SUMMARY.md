# How Steal a Box is made

## Project setup
- All code lives in `src/` and is built into the place file with **Lune**:
  `lune run tools/build.luau StealABox_v5.rbxl StealABox_v5.rbxl`
- The whole map is built from code (`StealABoxMap.server.luau`). Nothing is hand-placed in Studio.
- One **Config** module holds every number and piece of data, and one **Shop** module holds every game pass and product.

| File | Goes to |
| --- | --- |
| `StealABoxConfig.luau`, `StealABoxShop.luau` | ReplicatedStorage |
| `StealABoxServer.server.luau`, `StealABoxMap.server.luau` | ServerScriptService |
| `StealABoxClient.client.luau` + `client/*.luau` modules | StarterPlayerScripts |
| `client/Admin.client.luau` | ServerStorage (handed only to admins) |

## Routine after every change
1. `lune run tools/check_compile.luau src/*.luau src/client/*.luau`. This compiles like Studio and catches the 200-local limit.
2. Build the place.
3. Run both smoke tests: `tools/test/test_server.luau` and `test_client.luau`, which run the real scripts in a fake engine.
4. Commit, push, and send `StealABox_vN.rbxl`.

Map preview: `tools/render/dump_map.luau` exports the map, and `tools/render/view.html` draws it in a browser.

## IDs
| What | ID |
| --- | --- |
| Icon sheet 1 (transparent PNG) | 121181129357514 |
| Icon sheet 2 (transparent PNG) | 119828445968430 |
| Music: Morning Mood (APM) | 1846088038 (backups 1844291580, 1843564290), volume 0.3 |
| Bacon hair | 63690008 |
| Classic face | `rbxasset://textures/face.png` |
| Tutorial cursor | `rbxasset://textures/Cursors/KeyboardMouse/ArrowFarCursor.png` |

**Animations:**

| | idle | walk | point | cheer | laugh | wave | dance |
| --- | --- | --- | --- | --- | --- | --- | --- |
| R6 | 180435571 | 180426354 | 128853357 | 129423030 | 129423131 | 128777973 | 182435998 |
| R15 | 507766666 | 507777826 | 507770453 | 507770677 | 507770818 | 507770239 | 507771019 |

- **Icon sheets** are 10 x 5 grids. The server turns a Decal id into its image with `InsertService:LoadAsset` and reads the Decal's `.Texture`.
- **Uploads:** upload icons as transparent PNGs. Screenshots give every icon a white square.
- **Sounds:** `rbxasset://sounds/swoosh.wav` isn't allowed in published games. Use Creator Store audio instead.
- **Passes and products** are tied to this game. A new game needs its own.

## Lighting
| Setting | Value |
| --- | --- |
| ClockTime | 14 |
| Brightness | 2.6 |
| Ambient | 150, 152, 160 |
| OutdoorAmbient | 165, 168, 178 |
| GlobalShadows | on, ShadowSoftness 0.3 |
| EnvironmentDiffuse / Specular | 0.6 / 0.5 |
| ColorCorrection | Saturation 0.18, Contrast 0.1, Tint 255, 252, 245 |
| Atmosphere | Density 0.14, Offset 0.2, Color 205, 228, 255, Decay 120, 170, 235, Haze 0.6, Glare 0 |
| Bloom | Intensity 0.35, Size 20, Threshold 1.6 |
| Night | ClockTime 20.5, Brightness 1.2, OutdoorAmbient 100, 110, 190 |

- Old Sky, Atmosphere and Clouds get deleted when the map builds.
- Indoors, light comes from neon skylight strips plus hanging SpotLights (Range 60, Angle 110, Brightness 1.6, colour 255, 244, 226).

## Look
- **Building:** everything is made of Parts, with Concrete, Metal, DiamondPlate, WoodPlanks and Neon for the glow.
- **Detail:** extra small parts welded on (`Config.Attach`), plus cylinders on edges so things look less blocky.
- **Text on parts:** SurfaceGui with LuckiestGuy or Fredoka One.
- **Characters / NPCs:** R6 rigs built in code (`Config.MakeR6`) with detail parts welded to the limbs.
- **Warehouse colours:**
  - concrete 164, 166, 169
  - cladding 204, 210, 218
  - steel 96, 102, 112
  - safety yellow 255, 196, 0
  - rack blue 30, 88, 170
  - rack orange 242, 114, 24
- **UI:**
  - **Font:** Fredoka One.
  - **Palette:** ink outline 20, 16, 32; panel 38, 34, 60; card 52, 46, 82; gold 255, 205, 50; green 70, 215, 85; red 255, 72, 88; blue 60, 155, 255.
  - **Sizing:** designed at 1280 x 720 (960 x 540 on phones) with ZIndexBehavior Sibling. Text is TextScaled with a max size.
  - **Motion:** bouncy spring animations.
  - **Round buttons:** `UIAspectRatioConstraint` with DominantAxis Height keeps them round on wide screens.

## Saving and networking
- **DataStores:** `StealABox_v5` (player saves), `StealABox_Admins` (admins, bans, hidden players), and ordered stores for leaderboards.
- **Save safety:**
  - Saves are session-locked to one server, autosave every 60 s, and save on leave and in `BindToClose`.
  - A save that failed to load is never overwritten.
  - Developer-product receipts are stored in the save first, so a purchase is never given twice or lost.
- **Remotes:** one `Action` RemoteFunction handles everything, rate-limited. Notifications, sync and effects use RemoteEvents. Announcements reach all servers through MessagingService.
- **Collision groups:** players walk through everything except parts named Floor, Wall, Ceiling, and so on.

## Rules that kept it safe
1. The server re-checks every request: who's asking, prices, distance, cooldowns.
2. Numbers sent by the client get a whitelist, a cap and a rate limit.
3. Admin code sits in ServerStorage, is checked on the server, and kicks people who aren't admins.
4. Text typed by players goes through Roblox text filtering.

## Lessons learned
- **The 200-local limit crashes in real Roblox, not in normal checks.** Put big blocks in their own function (`function X_INIT() ... end X_INIT()`) and always run the strict compile check.
- **Saving in Studio:** turn on Game Settings > Security > Enable Studio Access to API Services.
- **Welds:** a viewport or fake engine doesn't move welded parts. `Model:PivotTo` moves the whole model.
- **Physics:** players own their character's physics, so check movement with distance and time limits on the server.
- **Part count:** about 14,000 anchored parts runs fine. Cap NPC counts.
