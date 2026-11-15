# Asset pipeline — Bankrupt Street

Master prompt for the local Claude Code session (ForgeGUI MCP + Roblox Studio MCP).
Start it with: "Read docs/prompts/asset-pipeline.md and follow it."
Run it after M0 is pushed.

---

Read first: CLAUDE.md, docs/GDD.md (Appendix E: asset checklist, Appendix D: copy,
§16: UI screens), docs/GDD-v1.1-changes.md, docs/map/skid-row-map.html.
Everything must be ORIGINAL to Bankrupt Street. Do not imitate any existing
Roblox game's UI, characters, models or branding.

## 1. Art bible (do this first, then stop and show me)

- Create one ForgeGUI style "BankruptStreet" and use it for EVERY generation.
- Look: chunky stylized cartoon, readable from far away and on phones,
  soft shading, slight exaggeration. Palette: auction red, gold, cream,
  asphalt grey; Skid Row is dusty and worn, rich streets get cleaner and shinier.
- UI: one bold display font + one clean body font, big numbers,
  red/gold/cream auction panels, rounded but not bubbly.
- Write the style rules to docs/art-bible.md (palette hex, fonts, do/don't).
- Generate 3 test assets: Cardboard Box house, auction stage, HUD cash panel.
- STOP and show me before generating anything else.

## 2. Asset list (after I approve the art bible), in this order

a. Houses 1–10 (GDD §4.1 visual briefs). Each fits a 64×64 stud footprint (up to ~120 studs tall for the towers),
   pivot at bottom centre, same scale. Low-poly for phones.
b. Auction stage, podium, gavel, jumbotron frame, rescue kiosk, Hall board,
   daily kiosk, rebirth gate.
c. 4 Skid Row properties (Street Stall, Food Cart, Kiosk, Corner Shop),
   each fits an 18×18 slot pad.
d. Skid Row props from the map plan (streetlight, dumpster, power pole,
   bus stop, bench, chain-link fence, cones, shopping cart).
e. UI: HUD, AuctionOverlay, RescueSheet, BankruptStinger, PropertyShop,
   UpgradeHouse, OfflineIncomeModal, icons (cash, rent, crash, insurance,
   lawyer, house levels 1–10).
f. Sound effects (Appendix E): rent tick, crash siren (mild), auction open,
   bid tick, gavel, rescue complete, upgrade fanfare, bankrupt sting,
   comeback sting, daily claim. Short, punchy, original.
g. Music: calm street loop, crash tension loop, auction loop, Eviction Night loop.
h. Later (M2+): cars, helicopters, golden statue, house skins.

## 3. Rules for every asset

- Name files exactly as the game uses them (e.g. House_05_RowHouse,
  Prop_Streetlight, UI_HUD_CashPanel, SFX_Gavel, MUS_Auction).
- Save source files in assets/<type>/ and record each in assets/manifest.md
  (name, ForgeGUI generation id, Roblox asset id, status).
- Import into Studio with the Studio MCP: houses to
  ReplicatedStorage.Assets.Houses, properties to .Properties, props placed
  on the map using the coordinates in docs/map/skid-row-map.html. Never move
  plot attachments (HouseAnchor, Slot1–Slot8, CarPad, HeliPad).
- Keep the part budget from the map plan. Check on a phone emulator view.
- No text baked into images except logos; UI text stays as TextLabels
  so it can change.
- Tone: GDD §19 and Appendix D. No gambling words, no crime/alcohol props.

## 4. Credits and checkpoints

- Before each section (a–h) tell me how many generations it needs and wait
  for my OK.
- If ForgeGUI says out of credits, stop and tell me.
- After each section: playtest in Studio, screenshot, commit and push.
