# Steal a Box: everything we built (project summary)

A reference for starting the next game: what Steal a Box is, how the project is set up, every asset and
product ID, the lighting and look, the numbers behind the economy, the systems, what we tried and
removed, and the Roblox lessons learned along the way.

- Repo: `zefanjaensarah-dot/rblx`, branch `claude/github-connection-check-w5yifr`
- Place file: `StealABox_v5.rbxl` in the repo, rebuilt from `src/` every time. The last version sent was **v66**.
- Owner / admin: **thisgenerationbruh**, user id **5790145019**

---

## 1. The game in one paragraph

You steal boxes from a long, guarded warehouse with 15 areas, each harder and deeper than the last.
Each area has a boss that sleeps until you steal from it, then chases you through the whole warehouse
until you get out the door. You carry the box home to your plot and it unboxes over time into an item.
Items go on your shelf, and NPC shoppers walk in and buy from it, so you earn cash per second. You
spend that cash on treadmill levels (speed), shoppers, payouts, unbox speed and trails, so you can
reach deeper areas without getting caught. Late areas take days. On top of that there's an Index
(collect all 4 items per area), daily rewards, quests, codes, gifts, achievements, surprise events,
a phone with 8 mini games and a leaderboard, a Robux shop, an owner-only admin panel, and
leaderboards.

---

## 2. How the project is set up

### Files (in `src/`, built into the place by `tools/build.luau`)

| File | Goes to | What it does |
| --- | --- | --- |
| `StealABoxConfig.luau` (~1,300 lines) | ReplicatedStorage | **All balance and data**: areas, boxes, items, item models, rarities, mutations, sizes, prices, formulas, codes, quests, achievements, events, boss moves, phone games, admin ids, music ids, icon sheets |
| `StealABoxShop.luau` | ReplicatedStorage | Every game pass and developer product with its id and price |
| `StealABoxServer.server.luau` (~4,900 lines) | ServerScriptService | Everything server-side: saving, stealing, guardians + boss AI, unboxing, shoppers, shop purchases, leaderboards, admin panel, friend bonus, phone leaderboard |
| `StealABoxMap.server.luau` (~2,200 lines) | ServerScriptService | Builds the whole map from code: lighting, lobby, plots, warehouse, bosses, signs |
| `StealABoxErrors.server.luau` | ServerScriptService | Studio-only: sends server errors to the on-screen error box |
| `StealABoxClient.client.luau` | StarterPlayerScripts | Starts every client module and the Studio-only red error box |
| `client/UI.luau` | module | The UI toolkit: colours, fonts, buttons, windows, icons, sounds |
| `client/Hud.luau` | module | Always-on-screen HUD: cash, speed, menu, timers, notifications |
| `client/Panels.luau` | module | Right-side Items and Unboxing panels |
| `client/Windows.luau` | module | Index, Quests, Trails, Gifts, Daily, Codes, Settings windows |
| `client/ShopWindow.luau` | module | The Robux shop window |
| `client/Phone.luau` | module | The phone: home screen, Snake, Block Blast, Archery, game-module loader |
| `client/PhoneGame_*.luau` | modules | Stack, Flappy Box, Box Merge, Whack-a-Thief, Box Catcher, Scores (the leaderboard app) |
| `client/Tutorial.luau` | module | Step-by-step tutorial with a pointer |
| `client/WorldFX.luau` | module | Everything 3D on your screen: unbox cutscenes, reveal, camera shake, living world |
| `client/BossFX.luau` | module | Boss title cards, special-move warnings and effects, chase trails |
| `client/Admin.client.luau` | **ServerStorage** | The admin panel. Only handed to admins; clients can't see it |

### Tools

- **Build:** `lune run tools/build.luau StealABox_v5.rbxl StealABox_v5.rbxl` reads the place, swaps in every
  script from `src/` and saves it. It also regenerates ServerStorage > BuildMapInStudio.
- **Strict compile check:** `lune run tools/check_compile.luau src/*.luau src/client/*.luau`. It compiles every
  script the way Studio does (optimisation 0, debug 2), which catches Luau's **200-local-register limit**.
  Always run it: a register overflow passes normal checks and then crashes in real Roblox.
- **Smoke tests:** from `tools/test`, run `lune run test_server.luau ../../StealABox_v5.rbxl` and
  `lune run test_client.luau ../../StealABox_v5.rbxl`. A fake Roblox engine (`env.luau`) runs the real
  scripts: stealing, chases, flings, boss moves, purchases and receipts, saving and session locks, admin
  panel, phone scores, and every window and button on the client.
- **Map preview:** `tools/render/dump_map.luau` writes every part of the built map to JSON, and
  `tools/render/view.html` draws it with three.js in a browser (headless Chromium for screenshots).
  Bosses show as a pile at the origin there because the fake engine doesn't move welded parts.
- **Lune** is the runtime for all of this (https://lune-org.github.io/docs).

### The routine after every change
1. strict compile check
2. build the place
3. both smoke tests
4. commit (with the Claude co-author lines) and push
5. copy to `StealABox_vN.rbxl` and send

---

## 3. Every ID used

### Game passes (`StealABoxShop.Passes`)
| Pass | ID | Robux | Effect |
| --- | --- | --- | --- |
| VIP | 2022698386 | 249 | +50% cash, VIP Trail (x8), gold VIP sign |
| 2x Cash | 2021768374 | 199 | x2 cash |
| Fast Unboxing | 2023232367 | 149 | boxes open 2x faster |
| Lucky Hands | 2022398364 | 179 | plain boxes get 1 extra mutation roll |
| Bigger Base | 2021672384 | 99 | +4 unboxing pads (10 instead of 6) |

### Developer products (`StealABoxShop.Products`)
| Product | ID | Robux | What it gives |
| --- | --- | --- | --- |
| Pile of Cash | 2026130420 | 25 | 10 min of income, min $2,500 |
| Bag of Cash | 2027072413 | 75 | 45 min, min $15,000 |
| Vault of Cash | 2025860415 | 199 | 180 min, min $120,000 |
| Mountain of Cash | 2025584439 | 499 | 720 min, min $900,000 |
| Instant Unbox | 2026892405 | 39 | every box on your plot ready now |
| Lucky Box | 2026760392 | 99 | guaranteed Rainbow box (1 in 5 Galaxy) |
| Server Luck | 2025986457 | 149 | 2x mutation luck for everyone, 15 min, stacks |

### Speed boosts (one developer product per tier, bought in order, `Shop.SpeedBoostIds`)
| Tier | ID | Robux |
| --- | --- | --- |
| 2x | 2021456395 | 3 |
| 4x | 2022440376 | 6 |
| 8x | 2023430376 | 12 |
| 16x | 2021942387 | 24 |
| 32x | 2021420400 | 48 |
| 64x | 2021714396 | 96 |
| 128x | 2021918388 | 192 |
| 256x | 2021678386 | 384 |
| 512x | 2022656368 | 668 |
| 1024x | 2021282403 | 1336 |

An id of `0` means: free in Studio (for testing), "Soon" in live servers.

### Images / decals
| What | ID | Notes |
| --- | --- | --- |
| Icon sheet 1 (transparent) | **121181129357514** | backpack, crown, gift, lock, book, calendar, box, boot, close, check, plus |
| Icon sheet 2 (transparent) | **119828445968430** | cash, coin, ticket, star, gear, heart, shop, rebirth, bolt, home, skull, clover |
| Old icon uploads (don't use) | 113628952516465, 71822476584863 | screenshots with a light background, so every icon sat on a white square |
| Classic face | `rbxasset://textures/face.png` | built-in, on NPC heads |
| Tutorial cursor | `rbxasset://textures/Cursors/KeyboardMouse/ArrowFarCursor.png` | built-in |
| Bacon hair (mesh/accessory id) | 63690008 | for the Bacon Hair shoppers |

- The icon sheets are 10 x 5 grids. The cell centres are in `SHEET_GRID` in `client/UI.luau`, and the
  icon-name to `{sheet, row, column}` map is `ICON_CELLS`.
- The server resolves each id with `InsertService:LoadAsset`: if the id is a **Decal**, it takes the image
  inside it, then publishes it as the ReplicatedStorage attributes `IconSheet1` / `IconSheet2`.
  That's how a decal id still works as an image.
- Any icon not on a sheet falls back to an emoji (`UI.EMOJI_ICON`). `UI.IMAGE_ICON` lets you set a
  single uploaded image per icon.
- `assets/` in the repo holds `IconSheet1.png`, `IconSheet2.png`, `StudTile.png` and `Sunburst.png`.
  The stud and sunburst textures were made for the UI but aren't wired in any more.

### Music (`Config.MusicIds`, tried in order; the first one that loads plays)
- 1846088038: "Morning Mood (f. Peer Gynt Suite No.1)", Roblox's licensed APM library (also used by Grow a Garden)
- 1844291580: "Peer Gynt #1 - Morning Mood" (backup)
- 1843564290: "Peer Gynt Suite No.1 1st Mov. Morning" (backup)
- Volume 0.3. There's a Music switch in Settings. `Config.MusicId` overrides the list.

### Animations
| | R6 (guardians, R6 shoppers) | R15 (R15 shoppers) |
| --- | --- | --- |
| idle | 180435571 | 507766666 |
| walk | 180426354 | 507777826 |
| point | 128853357 | 507770453 |
| cheer | 129423030 | 507770677 |
| laugh | 129423131 | 507770818 |
| wave | 128777973 | 507770239 |
| dance | 182435998 | 507771019 |

### Sounds
- `rbxasset://sounds/electronicpingshort.wav` (pickups, reveals) and `rbxasset://sounds/collide.wav` (flings) are used.
- **`rbxasset://sounds/swoosh.wav` is NOT allowed in published games.** It was removed from the UI after it
  broke. Some built-in rbxasset sounds work in Studio but not live; use Creator Store audio ids.

---

## 4. Lighting and look

### Lighting (set in code at the top of `StealABoxMap.server.luau`)
| Setting | Value |
| --- | --- |
| ClockTime | 14 |
| Brightness | 2.6 |
| Ambient (indoor) | RGB 150, 152, 160 |
| OutdoorAmbient | RGB 165, 168, 178 |
| GlobalShadows | **true** (was false for the old cartoon look) |
| ShadowSoftness | 0.3 |
| EnvironmentDiffuseScale / SpecularScale | 0.6 / 0.5 |
| ColorCorrection | Saturation 0.18, Contrast 0.1, Tint RGB 255, 252, 245 |
| Atmosphere | Density 0.14, Offset 0.2, Color RGB 205, 228, 255, Decay RGB 120, 170, 235, Glare 0, Haze 0.6 |
| Bloom | Intensity 0.35, Size 20, Threshold 1.6 |

- Old Sky, Atmosphere and Clouds are removed on build, so nothing from older versions lingers.
- **Day / night** (server): a day is 240 s and a night is 30 s. Night tweens Lighting to ClockTime 20.5,
  Brightness 1.2, OutdoorAmbient RGB 100, 110, 190. During the night the warehouse door closes, everyone
  inside is sent home, and the shelves restock. Morning tweens back to ClockTime 14.
  *Known gap:* the morning tween still uses the old values (Brightness 3, OutdoorAmbient 175, 175, 185)
  instead of 2.6 / 165, 168, 178.
- Earlier looks we went through: a bright cartoon (shadows off, saturation 0.35, lime studded grass,
  checker floors, bunting), then the "reference look" (studded plastic, wooden signs), and now a
  realistic warehouse with shadows.

### The warehouse look (v62, current)
- **Floor:** concrete (`Material.Concrete`, RGB 164, 166, 169) with saw-cut joints every 14 units, yellow
  (255, 196, 0) aisle lines, a dashed white forklift lane, and a yellow/black hazard band where each area starts.
- **Walls:** a concrete-block base with mortar lines, metal cladding (204, 210, 218) with ribs every 6 units,
  a department-colour band and a white trim. Steel I-beam columns (96, 102, 112) have yellow guards at the
  foot, and some carry fire extinguishers.
- **Roof:** a metal deck, purlins, two neon skylight strips, steel trusses over every column line, and
  hanging high-bay lamps (SpotLight, Range 60, Angle 110, Brightness 1.6, colour 255, 244, 226).
- **Racking:** blue uprights (30, 88, 170), orange beams (242, 114, 24), diamond-plate decks and zig-zag
  bracing. Wrapped cardboard stock sits on the top level. Boxes spawn on levels 1 and 2.
- **Props:** detailed pallets in yellow floor boxes (spawns for big boxes), a parked forklift, stacked
  pallets and bollards. A hanging department sign over each entrance plus wall signs show "AREA N" and
  the area name in its colour.
- **Front:** cladding on a concrete plinth, an orange band, a steel canopy with lights, striped door
  guards, 6 numbered loading docks with roll-up doors, and flood lights.
- **Boxes:** a lid, a tape cross, rounded corner posts (cylinders), rolled lid and bottom edges, a flap
  seam, a printed shipping label (rarity band, name, barcode) and "this side up" arrows. Rare boxes get
  silver rims and epic boxes get gold rims and a gem.
- About 14,000 parts in the map.

### UI style
- **Font:** Fredoka One everywhere (`Config.Font`). Luckiest Guy and Gotham Black are used for a few big titles.
- **Palette** (`UI.C`):
  - ink outline 20, 16, 32
  - panel 38, 34, 60
  - panelDark 25, 22, 42
  - card 52, 46, 82
  - hud 22, 19, 38
  - green 70, 215, 85
  - blue 60, 155, 255
  - yellow 255, 200, 45
  - gold 255, 205, 50
  - red 255, 72, 88
  - purple 165, 100, 255
  - orange 255, 150, 45
  - pink 255, 95, 170
  - cyan 40, 205, 240
  - money 125, 255, 80
- **Layout:**
  - Designed at 1280 x 720 (960 x 540 on phones, so phones get bigger UI).
  - Cash and speed bottom-left, timers bottom-right (top-right on phones).
  - The menu is on the left and the side panels on the right.
  - Everything bounces (spring-in windows, wiggling icons).
  - `ZIndexBehavior = Sibling`.
- Emoji are stripped from text (`Config.StripEmoji`) because the UI draws its own icons.

---

## 5. World layout (studs)

- `Config.Layout`:
  - frontZ = -4 (inside face of the warehouse front)
  - halfWidth = 63 (warehouse 126 wide)
  - floorY = 0.75
  - wallHeight = 45
  - scale = 1.5 (map design units x 1.5)
  - sectionLen = 90
- **Area length:** `90 + (min(area, 10) - 1) * 14` (area 1 = 90, area 10+ = 216). Areas go back to back
  toward -Z; the whole warehouse runs from z = -4 to about -2,616.
- **Lobby / court:** x -112..112, z 0..300.
  - Lime grass and a grey street.
  - 6 plots (3 per side, 92 x 92 each).
  - A square in front of the warehouse with Top Money / Top Speed leaderboards and the Trails Shop.
  - A Hall of Fame board at the back (z = court length - 9), a fountain, trees, benches and lamps.
  - The lobby spawn is at z 330.
- **Plot:**
  - A shop floor with a 45-slot display shelf at the back.
  - Unboxing pads.
  - A treadmill with an upgrade sign.
  - An UPGRADES board (shoppers, payouts, unbox speed, trails).
  - The phone on a stand.
  - Round podiums, an Expand Plot pad, and a "Your Plot" label.
- **Server size: 6 players** (6 plots). Set Max Players to 6.

---

## 6. The 15 areas and their bosses

| # | Area | Boss | Accent RGB | Boss speed | Fling | Boss special move (areas 4-15) | Chase style |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Dusty Storage | Sleepy Watchman | 200,165,110 | 12 | 60 | none | normal |
| 2 | Farm Barn | Rookie Guard | 230,80,60 | 19 | 90 | none | normal |
| 3 | Toy Factory | Mall Cop | 90,170,255 | 26 | 120 | none | normal |
| 4 | Candy Shop | Candy Bouncer | 255,110,200 | 33 | 150 | Sugar Slam (circle) | hop |
| 5 | Pirate Cove | Pirate Brute | 60,170,220 | 40 | 180 | Anchor Wave (strip) | sway |
| 6 | Dino Museum | Riot Guard | 130,200,80 | 48 | 210 | Shield Bash (strip) | charge |
| 7 | Frozen Lab | Yeti Guard | 140,220,255 | 56 | 240 | Blizzard Roar (strip) | gallop |
| 8 | Tech Lab | Security Mech | 60,150,255 | 64 | 270 | Laser Sweep (strip) | skate |
| 9 | Alien Hangar | Alien Enforcer | 90,255,90 | 73 | 300 | Tractor Beam (pulls you in) | hover |
| 10 | Galaxy Vault | Void Warden | 180,90,255 | 82 | 340 | Black Hole (circle + pull) | float |
| 11 | Lava Forge | Magma Golem | 255,110,40 | 92 | 380 | Eruption Slam (circle) | stomp |
| 12 | Haunted Manor | Phantom Knight | 150,90,220 | 103 | 420 | Spectral Slash (strip) | glide |
| 13 | Crystal Caverns | Crystal Titan | 90,230,255 | 115 | 460 | Prism Quake (circle) | stomp |
| 14 | Sky Kingdom | Storm Giant | 255,220,110 | 128 | 500 | Thunder Call (5 strikes) | fly |
| 15 | Dragon's Hoard | Dragon King | 255,60,80 | 142 | 560 | Inferno Breath (strip) | gallop |

- Each area has 3 boxes (common / rare / epic). For example, area 1 has Old Box $5, Dusty Crate $12 and
  Antique Chest $30; area 15's boxes are worth hundreds of thousands. Each area also has 4 themed items
  (common to legendary). Areas 11-15 pay x5 per area and open x1.8 slower per area.
- **Bosses** are classic R6 rigs (`Config.MakeR6`) with hundreds of detail parts welded on: faces with
  eyelids that close while they sleep, uniforms, weapons, glowing orbs, a name plate, Zzz, "!" and rage
  particles. They sleep at their post and wake when you steal *their* area's box. They point at you, then
  chase until you're out the door. When they catch you they fling you and laugh, then walk back.
- **Boss special moves:** every 6-9 s of a chase the boss stops and charges. A glowing warning fills up
  on the floor, then the move fires. If it hits, your speed is halved for 2.2 s. Each move has its own
  effects (water wave, laser, lightning, black hole, fire cone and so on). There's a title card when a boss
  wakes for you ("AREA 7 BOSS / YETI GUARD / SPECIAL MOVE: BLIZZARD ROAR"), plus themed chase trails.
  Printed text: SECURITY (Candy Bouncer's back), POLICE + RIOT on the shield (Riot Guard), SEC-08 (Security Mech).
- **Boss gallery** (a web page, not in the game): https://claude.ai/artifact/NYpoxzLRor8zBQtm6Cu72G.
  It's a three.js toon-shaded 3D showcase of bosses 4-15:
  - each boss has an ability, an ULTIMATE mode, an entrance and a title card
  - blocky detailed models (no circles) with textures and decals
  - octagon arenas
  - a TikTok caption + Record mode for filming

---

## 7. Economy and progression (the numbers)

- **Rarities** (per box):
  - Common: weight 60, carry slow 1, hold 0.4 s
  - Rare: weight 30, slow 2, hold 0.8 s
  - Epic: weight 10, slow 3, hold 1.3 s
- **Mutations** (chance % / cash multiplier):

  | Mutation | Chance % | Cash x |
  | --- | --- | --- |
  | Normal | 70 | 1 |
  | Gold | 14 | 2 |
  | Diamond | 8 | 3 |
  | Lava | 5 | 4 |
  | Rainbow | 2.5 | 6 |
  | Galaxy | 0.5 | 10 |

- **Sizes:** a random number with no limit. `s = exp((r1 + r2 + r3 - 1.5) * 0.45)`, and 4% of boxes get a
  big-tail boost: `s *= 1 + (1/r - 1)^0.55`. The minimum is 0.35, and boxes on shelves are capped at 1.35.
  Value is x `s^2.4`. Carry slowdown is `(s - 1) * 4`, max 40; small boxes make you faster.
- **Item tiers** (income multiplier / drop % from common, rare, epic boxes):

  | Tier | Income x | Drop % (common / rare / epic box) |
  | --- | --- | --- |
  | Common | 1 | 79 / 55 / 35 |
  | Uncommon | 2 | 15 / 28 / 32 |
  | Rare | 4 | 5 / 13 / 23 |
  | Legendary | 10 | 1 / 4 / 10 |

- **Unbox time:** `(8 + area * 6) * {1, 1.6, 2.4}[rarity] * sqrt(size)`, x1.8 per area past 10 (a common
  area-15 box takes about 30 min). The Unbox upgrade multiplies it (0.46 at level 10, about 0.12 at 100,
  never under 0.05). The Fast Unboxing pass halves it.
- **Speed:** a big number that starts at 100. Walk speed = `16 + 2.6 * log2(points / 100)`, max 200.
  The recommended speed per area is about 0.88 x the boss speed + 2.
- **Treadmill** (no level cap):
  - Rate: `3 * 1.25^(min(L, 30) - 1) * 1.4^max(0, L - 30)` speed per second.
  - Cost: `250 * 1.6^(L - 2)`; the first upgrade costs $50.
- **Upgrades** (no level cap):
  - Shoppers: +0.3x per level up to 10, then +0.15x. Cost `120 * 1.7^(L - 1)`.
  - Payouts: +0.15x per level. Cost `300 * 1.7^(L - 1)`.
  - Unbox speed: cost `200 * 1.7^(L - 1)`.
- **Trails** (speed multiplier / price):

  | Trail | Speed x | Price |
  | --- | --- | --- |
  | Dust | 1.25 | $150 |
  | Leaf | 1.6 | $700 |
  | Ocean | 2.2 | $3K |
  | Fire | 3 | $12K |
  | Electric | 4.2 | $50K |
  | Candy | 6 | $200K |
  | Galaxy | 9 | $900K |
  | Rainbow | 14 | $4M |
  | VIP (pass only) | 8 | |

- **Shelf:** you start with 8 slots and can unlock up to 45. The next slot costs `2500 * 1.45^(slots - 8)`.
  Inventory holds 60 items.
- **Shoppers:** up to 4 per shop at once, a new one at most every 1.2 s. Each pays everything the shop
  earned since the last sale, so the shop earns exactly its $/s.
- **Index:** collect all 4 items of an area, then claim 15 min of those items' income plus **+10% cash
  forever** (all 15 areas = x2.5).
- **Daily streak (7 days):**
  1. cash: 5 min of income, min $500
  2. cash: 10 min, min $1,500
  3. a free box
  4. cash: 20 min, min $6,000
  5. cash: 30 min, min $15,000
  6. a free box
  7. a Lucky (Rainbow) box
- **Codes:** RELEASE ($2,500), STEALABOX (a free box), ZOOM (+500 speed).
- **Playtime gifts:** at 1, 3, 6, 10, 15, 20, 30, 45 and 60 min; each is cash or a box. There's also a free
  lobby gift every 15 min.
- **Quests:** 3 per day, the same on every server (seeded by the day number), with rewards that grow with
  your income. Types: steal, open, sales, run on the treadmill, rare unboxes, deep steals (area 3+).
- **Secret achievements** (15 of them): for example First Heist, Master Thief, BONK!, Bouncy Castle,
  Dragon Slayer, Millionaire, Billionaire, Speed Demon.
- **Surprise events:** every 150-360 s, one of: DOUBLE CASH (90 s), SPEED RUSH (3x treadmill, 90 s),
  GOLDEN BOX RAIN (60 s), LUCKY TIME (2x mutations, 120 s).
- A special Rainbow or Galaxy box appears every 120 s.
- **Offline earnings:** 25% of your income, up to 8 hours, if you were away more than 2 minutes.
- **Friend bonus:** +10% cash per Roblox friend in the server, max +50%. The HUD shows "(+20% friends)"
  and you get a message when a friend joins.
- **Shelf restock** after a box is taken: `8 + area + rarity * 4` seconds.
- Starting values: speed 100, $0.

---

## 8. Systems (how things work)

- **Stealing:**
  - Hold the prompt; hold time depends on rarity and size.
  - The server checks you're close, inside the warehouse, and that no wall or closed door is between you
    and the box (a raycast against parts named "Wall").
  - The box is welded to you and slows you. Drop it with the Drop button (G on PC).
  - Walking onto your plot auto-places it; clicking your floor places it.
  - Dropped boxes stay 15 min.
- **Collision:** players walk *through* everything except named solid parts (Floor, Wall, Ceiling, Tile,
  Street, PlotFloor, BackWall, CourtWall, WallCap and so on). Collision groups: `SAB_Players` and
  `SAB_Passthrough`.
- **Unboxing:** 6 pads (10 with the pass). Open plays a cutscene (charge-up, lightning, the item pops out
  in 3D, spins, then flies to its shelf slot). Better items charge up longer.
- **Shoppers:** R6 Noobs and Bacons plus funny R15 avatars. They walk in, take a product and pay. Players
  pass through them.
- **Phone** (on every plot, by the treadmill):
  - A real home screen with a clock, battery, a best-scores widget and a 4 x 2 app grid.
  - 8 games: Snake, Block Blast, Archery, Stack, Flappy Box, Box Merge, Whack-a-Thief, Box Catcher.
  - The dock holds the **Leaderboard** app: this-server and global top 10 per game, plus your best and rank.
  - Best scores are saved. The server accepts a score only for a known game, as a whole number under that
    game's cap (`Config.PhoneGames`), and at most once every 2 s.
- **Leaderboards:**
  - Top Money and Top Speed boards in the lobby, with rank badges and avatars, from global ordered stores
    (values stored as log10 x 1e6 so huge numbers fit).
  - A Hall of Fame board that admins curate, showing each person's money and speed.
- **Admin panel** (F2 or a button; owner + people the owner promotes):
  - **Players tab:** player cards with stats.
    - Set or add cash and speed.
    - Set upgrade levels.
    - Kick, ban (saved) or unban.
    - Go to or bring a player.
    - Remove someone from the leaderboards or put them back.
  - **Boxes tab:** give or spawn a box with any area, box, mutation and **any size**, or fill the warehouse.
  - **Server tab:** announcements (text-filtered; this server or all servers via MessagingService), start
    events, server luck, and money, speed or upgrades for everyone.
  - **Tools:** fly, noclip, god mode (bosses ignore you), spectate.
  - **Admins tab:** give or remove admin (saved).
  - **Hall of Fame:** choose who's on it, with an optional filtered title.
  - **Security:**
    - The panel script lives in ServerStorage and is only given to admins.
    - Every request is checked again on the server.
    - Non-admins who call it get kicked after 3 tries.
    - The owner and admins can't be banned.
- **Tutorial:** step by step, with a glowing line to the target and a big yellow-tinted cartoon mouse cursor
  (Roblox's own cursor image) that walks new players through stealing, placing, unboxing, equipping and the
  treadmill upgrade.
- **Settings:**
  - Sound effects
  - Music
  - Screen effects (shake / flash)
  - Product labels
  - Slow mode
  - Replay the tutorial
- **Studio error box:** in Studio only, server and client errors show in a red box at the bottom of the
  screen, so problems in real Roblox are easy to report with a screenshot.

---

## 9. Data, saving and networking

- **DataStores:**

  | Store | Kind | What it holds |
  | --- | --- | --- |
  | `StealABox_v5` | DataStore | player saves, key `player_<userId>` |
  | `StealABox_Admins` | DataStore | keys `admins`, `bans`, `lbHidden`, `featured` (Hall of Fame) |
  | `StealABox_TopMoney`, `StealABox_TopSpeed` | ordered stores | lobby leaderboards |
  | `StealABox_Phone_<Game>` | ordered store | one per phone game (e.g. `StealABox_Phone_Snake`) |

- **Saving:**
  - Autosave every 60 s and on leave; `BindToClose` saves everyone.
  - **Session lock:** a save is claimed by one server at a time (`SessionActive` / `SessionJob`), so a
    fast rejoin can't load stale data.
  - If a save fails to load, the player is marked `dontSave` so their real save is never overwritten.
- **Receipts:** every developer-product receipt id is stored in the save *before* telling Roblox it's
  granted. A purchase is never given twice and never lost.
- **Profile fields:**
  - Money and progress: Cash, Stolen, Boxes, Mutations, ItemsFound, Items, Unboxing, Treadmill,
    SpeedPoints, Customers, SpeedBoost, PayoutLevel, UnboxLevel, ExtraStands
  - Collections and rewards: Trails, Trail, IndexClaimed, Daily, Codes, Achievements, Flings, PhoneBest
  - Bookkeeping: TutorialDone, Receipts, Settings, SaveVersion (2)
- **Remotes** (`ReplicatedStorage.StealABoxRemotes`):
  - Notify, Drop, Sync, Fling, FX, Reveal, PlaceBox, ShopEvent
  - Action (RemoteFunction)
  - AdminAction (RemoteFunction), Announce
- **Action names** (one RemoteFunction, rate-limited to 1 per 0.12 s):
  - Data and setup: GetData, TutorialDone, SetSetting, SlowMode, Home, Warehouse, RedeemCode
  - Upgrades: BuyUpgrade, UpgradeTreadmill, UpgradeShoppers, UpgradePayout, UpgradeUnbox, ExpandPlot, BuyStand
  - Items: PlaceItem, EquipAll, RemoveItem, SellItem, Booth
  - Boxes: OpenBox, OpenAll
  - Rewards: ClaimGift, ClaimQuest, ClaimIndex, ClaimDaily
  - Shop: BuySpeed, BuyProduct, BuyPass
  - Phone: PhoneScore, PhoneBoard
- **MessagingService** topic `SAB_Announce` sends announcements to all servers.
- **Useful attributes:**
  - On the player: Cash, Income, SpeedPoints, WalkSpeed, Carrying, CarryLabel, Chased, FriendBonus, PlotName
  - On ReplicatedStorage: IsNight, PhaseEndsAt, SpecialAt, ServerLuckUntil, EventId, IconSheet1/2

---

## 10. Security rules we followed (reuse these)

1. **Never trust the client.** Every action re-checks who's asking, what they own, the price, the
   distance and the cooldowns on the server.
2. **Anti-teleport:** carrying a box home faster than `(topSpeed * time * 1.6) + 60` studs drops it
   ("Whoa, too fast! The box fell apart.").
3. Client-reported numbers (phone scores) get a whitelist, a cap and a rate limit.
4. The admin panel sits in ServerStorage, is checked on every request, and kicks non-admins.
5. Text from players (announcements, Hall of Fame titles) goes through Roblox text filtering. Feeds and
   captions are game-generated only.
6. Developer products use receipts in the save and are idempotent.
7. Admin-hidden players are left off every leaderboard, including the phone boards.

---

## 11. Roblox / Luau lessons learned (save yourself the pain)

- **200 local-register limit:** big scripts hit it, but only Studio's settings (O0, debug 2) show it.
  Fixes:
  - Put big blocks inside their own function (`function ADMIN_INIT() ... end ADMIN_INIT()`); the code
    uses this pattern (`BOSS_INIT`, `FRIENDS_INIT`, `PHONE_INIT`, `WAREHOUSE_BAYS`, `BOSS_DECALS`).
  - Or use tables or globals.
  - **Always run `check_compile.luau`.** This once crashed the live server.
- **Sounds:** `rbxasset://sounds/swoosh.wav` and some other built-in sounds aren't allowed in published games.
- **Decal vs image ids:** an uploaded Decal id isn't an image id. Use `InsertService:LoadAsset(id)` on the
  server and read the Decal's `.Texture`.
- Uploading icons as screenshots gave every icon a white square. Upload **transparent PNGs**.
- **Saving in Studio** needs Game Settings > Security > Enable Studio Access to API Services.
- **UI:**
  - `UIAspectRatioConstraint` with `DominantAxis = Height` keeps round buttons round on wide screens.
  - Use TextScaled with a max size, so text is never tiny and never overlaps.
- **Welds don't move in a viewport or the fake engine;** `Model:PivotTo` moves the whole model.
- **Client physics:** players own their character's physics, so speed and movement can't be fully
  server-validated. Use distance and time checks instead.
- **Parts:** about 14K anchored parts is fine. Don't spawn hundreds of NPCs (shoppers are capped at 4 per shop).
- **Emoji** may not render the same everywhere; the UI draws its own icons instead.
- **Things to set up before publishing:**
  - Max Players 6
  - Studio API access
  - pass and product ids
  - music ids you're allowed to use
  - upload the icon sheets

---

## 12. Things we tried and removed

| Version | What | Why it went |
| --- | --- | --- |
| v6 | "Mega Mart" supermarket version | replaced by the warehouse again |
| ~v9 | Bike Obby phone app | removed in the phone overhaul |
| v18 | Floating-island biomes + critters around the lane | too heavy; walls instead |
| ~v35 | Bats, then mines (knock boxes loose / blow players away) | removed |
| v20s | Cartoon warehouse (checker floors, bunting, polka dots, themed props) | replaced by the real warehouse (v62) |
| v63 | BoxTok (TikTok-style feed on the phone) | removed at your request |
| v65 | Movement system (dash, double jump, wall run, slide) | didn't work for you; removed in v66 |
| v62 | (4-legged dragon boss) | only in the web gallery: bosses in-game are R6 rigs, so a quadruped would need a custom rig + animations |

---

## 13. Version timeline (short)

- **v5:** Robux shop, new GUI, Index rewards, daily rewards, codes, offline earnings, server luck, save locking, receipts.
- **v6-v15:** side panels, quests, day/night, phone with games, epic unbox cutscene, surprise events,
  achievements, size RNG, trails shop, leaderboards, cartoon then reference look, icon sheets.
- **v40s:** pass and product ids, music, phone overhaul (Snake swipe, Block Blast drag, slingshot Archery).
- **v47:** tester fixes (auto-place, Expand Plot sign, dropped boxes stay).
- **v48-v52:** 15 areas (Lava Forge to Dragon's Hoard), upgrades with no level cap, days-long endgame, admin panel.
- **v53-v58:** admin v2 (tabs, announcements, bans), compile-crash fix, Hall of Fame, set upgrade levels, no
  flying coins.
- **v59-v60:** random box sizes, no stealing through walls, better leaderboards, phone model, admin redesign
  + tools, 5 new phone games.
- **v61:** boss special moves, title cards, themed chases.
- **v62:** real warehouse, industrial front, shadows, rounded boxes, friend bonus.
- **v63:** BoxTok.
- **v64:** BoxTok removed, phone Leaderboard app.
- **v65:** movement system.
- **v66:** movement removed (current).

---

## 14. Starting the next game: a checklist from this one

1. Keep the same split: one **Config** module for all numbers and data, one **Shop** module for products,
   a server script, a map-builder script, and client modules (UI kit, HUD, windows, world FX).
2. Copy over the tooling: `tools/build.luau`, `tools/check_compile.luau`, `tools/test/env.luau`, and
   `tools/render/` for map previews.
3. Copy over the systems that are already solid:
   - session-locked saving
   - receipt-safe developer products
   - the admin panel (ServerStorage + server checks)
   - leaderboards with log encoding
   - the Studio error box
   - the UI kit (palette, fonts, bouncy buttons)
   - the icon sheets
4. Decide the lighting early. Shadows on (GlobalShadows) look much better but change how indoor spaces
   need to be lit (skylights and lamps).
5. Set Max Players and turn on Studio API access before testing saves.
6. Reuse the IDs above only where they fit. Game passes and products belong to *this* experience, so a
   new game needs its own.
