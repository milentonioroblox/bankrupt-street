# Bankrupt Street

**Game Design Document (Implementation-Ready)**  
**Platform:** Roblox  
**Genre:** Social tycoon / live-auction survival  
**Working title:** Bankrupt Street  
**Document status:** v1.0 — build from this  
**Audience:** Claude (Claude Code) implementing the game in Luau, plus the design owner

> **Every numeric value in this document is a starting design value, not live data.**  
> Put all of them in a single shared `Config` module. Do not hard-code numbers in systems. Tune after playtests without rewriting logic.

---

## 0. How to use this with Claude

This GDD is the source of truth for building **Bankrupt Street** in Luau with Rojo. Follow it in this order:

1. **Do not invent a different core loop.** The hook, rent/crash/auction/rescue cycle, house levels, streets, events, monetization, and moat features are already decided. Implement them as specified. If a detail is missing, add it to `Config` and keep it consistent with the formulas here; do not change the fantasy.
2. **Start with the Week 1 vertical slice (Milestone M1), not the full game.** One street, income, rent, crash, auction, bankruptcy, and comeback must be fun before house cosmetics, daily rewards, rebirth, or monetization.
3. **Copy the Config appendix into `src/shared/Config.lua` first.** All systems read from it. Mark every value with a comment `-- starting design value`.
4. **Server is authoritative.** The client never grants cash, items, bids, rescues, or upgrades. All remotes listed in Appendix B are requests; the server validates and replicates results.
5. **Treat the data models, state machines, and anti-exploit rules as required**, not suggestions. Especially: cash escrow for bids, session-locked DataStores, one live auction per server, and no Robux-sold random items.
6. **Build in the milestone order in Section 22.** Finish and smoke-test each milestone before starting the next. After Week 1, the only kill-criterion is: *is the 10-minute loop fun on a 12-player street?* If not, tune Config and feel; do not add features.
7. **Compliance is a build requirement**, not a polish pass. Auctions use in-game cash only. Mystery Deed and Landlord Spin are free, with odds labeled in UI. Do not sell loot boxes or random deeds for Robux.
8. When something is ambiguous at implementation time, prefer the option that (a) is server-authoritative, (b) creates a clip-worthy public moment on the street stage, and (c) cannot be abused with alt accounts.

---

## 1. Game overview

### 1.1 Pitch

**Bankrupt Street** is a 12-player social tycoon on a shared street. You start in a cardboard box, buy stalls and shops, and grow a house that everyone can see. Every 10 minutes the street collects rent. Every hour a Market Crash triples that rent. If you cannot pay, your estate goes to a **60-second live auction on a stage in the middle of the street**. Anyone can bid. Friends can chip in to rescue you. If you fall, you restart in a cardboard box with a Comeback Boost and a "Fallen Millionaire" tag — and a reason to take the house back.

**Hook line:** *Everything you own, someone else can buy.*

### 1.2 Fantasy and tone

Visible wealth, public failure, public revenge. The street is a stage. Houses are billboards. Auctions are spectator sport. The tone is sharp and funny, not cruel: bankruptcy is a plot twist, not a humiliation sim. Comeback is always possible. The biggest moments should be understandable in a 7-second screen recording.

### 1.3 Design pillars

1. **Wealth is public.** House tier, nametag, plot props, and the Hall of Fallen Millionaires make status readable at a glance.
2. **Loss is the hook, not just gain.** Rent and crashes exist so estates change hands. A game where nobody goes bankrupt has failed.
3. **One spectacle at a time.** A single live auction on the street stage. No overlapping auctions.
4. **Skill and timing beat wallets.** Auction wins and Billionaire Row rank cannot be bought with Robux.
5. **Comeback is delicious.** Bankruptcy is a reset with a boost and a story, not a dead end.

### 1.4 Target session and audience

- **Session:** 15–40 minutes typical; events pull people back on the hour and at 20:00 America/New_York on weekends.
- **Audience:** Roblox mainstream, 9+ tone (see compliance). Social, competitive, clip-friendly.
- **Success metric (post-launch):** D2–D7 retention, not launch-day CCU. Iterate weekly events and streets only if D2–D7 is healthy.

### 1.5 What this game is not

- Not a "Steal a ___" clone. You never steal a held item off another plot. You **buy** a bankrupt estate at auction, or you fail to pay and lose it.
- Not a casino. No real-money framing, no Robux wagering, no paid gacha.
- Not an idle game you can ignore. Offline income exists (8-hour cap) so people return; rent and crashes exist so they cannot truly AFK-win.

---

## 2. Core gameplay loop

### 2.1 Minute-to-minute loop

1. **Earn.** Income properties (stalls, shops, apartments) pay cash every income tick, including while offline up to 8 hours.
2. **Upgrade the plot.** Spend cash to raise the house level. The house model on the plot swaps immediately so the whole street sees the promotion.
3. **Pay rent** every 10 minutes. Rent scales with what you own (income base + house tax), then by street tier.
4. **Survive the Market Crash** every hour. During the crash window, rent is multiplied by 3. A 60-second warning precedes it.
5. **If you miss rent:** Crash Insurance may auto-pay (once per UTC day). Otherwise a live auction starts. Friends can pool a rescue. The owner can still pay (Lawyer Pass adds +15 seconds). If nobody saves the estate, it sells on stage.
6. **If you go bankrupt:** you respawn in a Cardboard Box on the same plot, cash is reset to the starting amount, you get a **2× Comeback Boost for 10 minutes**, and you wear the **Fallen Millionaire** tag. Revenge is the motive.
7. **If you win an auction:** you take the income properties and a house deed (rules in Section 7). This is the "I bought my rival's villa" moment.

### 2.2 Session loop

- First 2 minutes: claim a plot, understand income and the next rent timer.
- Mid-session: upgrade, position cash reserves before the hourly crash, spectate or bid on auctions.
- End of session: leave with offline income ticking (capped), a reason to return for a streak, a crash, Eviction Night, or a Golden Auction.

### 2.3 Long-term loop

House 1→10 on a street → **Rebirth** to the next street tier (Skid Row → Suburb Lane → Downtown → Ocean Drive → Billionaire Row) → permanent income multiplier and a new social pool. History (Hall, property owner logs, Fallen Millionaire count) never wipes.

---

## 3. Server population and street layout

### 3.1 Population

| Key | Starting design value | Notes |
|---|---|---|
| `MaxPlayersPerStreet` | 12 | One plot per player |
| `PlotCount` | 12 | Fixed on the map |
| `MinPlayersToKeepServer` | 1 | Standard Roblox |
| `ReservedServerFriendsOnly` | true for Private Street | See monetization |

Matchmaking: public servers are filtered by **street tier**. A player whose current street is Downtown only joins Downtown servers (plus a short "visit" exception if we add tourism later; *do not build tourism in M1–M3*).

### 3.2 Layout (single map, five visual themes)

One street template, themed per tier. Required props:

- **12 plots** in a row or shallow U, all visible from the center. Each plot has a house anchor, 8 property attachment slots, a cash ticker billboard, and a nameplate.
- **Auction stage** at the street center, with podium, bid jumbotron, camera spots for spectating, and a rescue contribution kiosk.
- **Hall of Fallen Millionaires** board on a wall facing the stage (live-updating text / portrait list).
- **Rent clock and crash clock** as world UI above the stage, also mirrored on the HUD.
- **Daily Rewards / Landlord Spin kiosk** near spawn.
- **Rebirth gate** at the end of the street (locked until eligible).
- **Cosmetic garage pad** on each plot (cars from Townhouse upward; helicopter pad from Private Island Portal upward).

Plot claim: first player to press the plot claim prompt on an empty plot gets it for the session. On join, if the player already has a saved plot assignment in this reserved/private server, restore it; on public servers, plots are session-claimed but **progress (house, properties, cash) is account-saved**, not plot-saved. Leaving frees the plot. Rejoin tries to reclaim any free plot and rebuilds the house/properties on it.

### 3.3 Visibility rules

- House model, nameplate (cash is optional on nameplate; default **off** for cash, **on** for house tier + Fallen Millionaire tag + VIP gold name), and property props are always visible.
- Net-worth rank crown on the current server #1.
- During auction, the bankrupt plot gets a red "ON THE BLOCK" beacon the whole street can see.

---

## 4. House levels

House level is visual status and a rent tax, and it gates property slots and property tiers. Level 1 is the bankruptcy restart.

### 4.1 Level table

All costs and slot counts are **starting design values**.

| Level | Id | Display name | Upgrade cost (cash) | Property slots | Unlocks | Visual brief |
|---:|---|---|---:|---:|---|---|
| 1 | `CardboardBox` | Cardboard Box | 0 (start / bankrupt) | 1 | Street Stall | Taped box, blanket, milk crate |
| 2 | `Tent` | Tent | 250 | 1 | Food Cart | Dome tent, camp light |
| 3 | `Trailer` | Trailer | 1,000 | 2 | Kiosk | Parked trailer, folding chair |
| 4 | `Studio` | Studio | 4,000 | 2 | Corner Shop, Studio Apartment | One-room flat, window box |
| 5 | `RowHouse` | Row House | 15,000 | 3 | Boutique | Narrow town facade, stoop |
| 6 | `Townhouse` | Townhouse | 50,000 | 3 | Luxury Store, Apartment Building, car pad | Brick townhouse, balcony |
| 7 | `Villa` | Villa | 200,000 | 4 | — (tier peak for many deeds) | Gated villa, fountain |
| 8 | `PenthouseTower` | Penthouse Tower | 800,000 | 5 | Apartment Tower, Street Mall | Slim tower, roof deck |
| 9 | `PrivateIslandPortal` | Private Island Portal | 3,000,000 | 6 | Island Resort, helicopter pad | Plot becomes a portal to a small island lobby-slice; helicopter pad |
| 10 | `BillionaireEstate` | Billionaire Estate | 12,000,000 | 8 | Corporate HQ | Estate, **helicopter**, **golden statue of the owner** (uses their avatar likeness or a stylized gold figure with their name) |

Upgrade rule: must buy the next level sequentially (no skipping with cash). Auction house deeds are the only skip (Section 7.6). Spend is deducted server-side only if `cash >= cost` and `houseLevel == target - 1`.

On upgrade: swap the house model instantly, play a short celebration VFX/SFX audible on the street, update the nameplate, recalculate rent and max slots. Existing properties stay; new slots appear empty.

### 4.2 House rent tax

Added each rent cycle, **starting design values**:

| Level | `HouseRent[level]` |
|---:|---:|
| 1 | 0 |
| 2 | 5 |
| 3 | 15 |
| 4 | 40 |
| 5 | 100 |
| 6 | 250 |
| 7 | 800 |
| 8 | 2,500 |
| 9 | 8,000 |
| 10 | 25,000 |

---

## 5. Income properties

### 5.1 Catalog

Properties are bought with cash from the Property Shop and placed in a free slot on the owner's plot. Income is paid every `IncomeTickSeconds` (1 second). The table lists **income per minute** for readability; the server stores and applies `BaseIncomePerMinute / 60` per tick.

All numbers are **starting design values**.

| Id | Display name | Type | Cost | Income / min | Min house level | Min street tier | Slots used |
|---|---|---|---:|---:|---:|---:|---:|
| `stall_street` | Street Stall | Stall | 50 | 8 | 1 | 1 | 1 |
| `stall_food` | Food Cart | Stall | 200 | 15 | 2 | 1 | 1 |
| `stall_kiosk` | Kiosk | Stall | 600 | 30 | 3 | 1 | 1 |
| `shop_corner` | Corner Shop | Shop | 2,000 | 60 | 4 | 1 | 1 |
| `apt_studio` | Studio Apartment | Apartment | 5,000 | 80 | 4 | 2 | 1 |
| `shop_boutique` | Boutique | Shop | 8,000 | 120 | 5 | 2 | 1 |
| `apt_building` | Apartment Building | Apartment | 25,000 | 200 | 6 | 2 | 1 |
| `shop_luxury` | Luxury Store | Shop | 30,000 | 250 | 6 | 2 | 1 |
| `apt_tower` | Apartment Tower | Apartment | 120,000 | 500 | 8 | 3 | 1 |
| `shop_mall` | Street Mall | Shop | 400,000 | 800 | 8 | 4 | 1 |
| `apt_resort` | Island Resort | Apartment | 1,500,000 | 2,000 | 9 | 4 | 1 |
| `shop_hq` | Corporate HQ | Shop | 6,000,000 | 5,000 | 10 | 5 | 1 |

Street 1 (Skid Row) only uses the first four catalog rows (stalls + Corner Shop). That is enough for the Week 1 slice.

### 5.2 Income formula

```
effectiveIncomePerMinute =
    sum(property.BaseIncomePerMinute)
    * streetIncomeMultiplier[streetTier]
    * rebirthIncomeMultiplier          -- 1.0 + 0.15 * rebirthCount, starting design
    * (comebackActive and 2.0 or 1.0)
    * evictionNightRewardMultiplier   -- 1.0, or 2.0 during Eviction Night
    * otherTemporaryMultipliers        -- keep a single multiplier stack in IncomeService

cashAddedThisTick = effectiveIncomePerMinute / 60 * IncomeTickSeconds
```

`streetIncomeMultiplier` starting design values: `{1.00, 1.10, 1.25, 1.45, 1.75}` for streets 1–5.

Income is granted only by the server. The client shows a predicted ticker; on mismatch the server value wins.

### 5.3 Offline income

When a player leaves, store `lastSeenAt = os.time()` (UTC). On next session load:

```
elapsed = min(now - lastSeenAt, OfflineIncomeCapSeconds)     -- cap = 8 hours = 28800 s
offlineRate = VIP and 2.0 or 1.0                             -- VIP = 2× offline income, same 8h cap
offlineCash = effectiveIncomePerMinuteAtLogout / 60 * elapsed * offlineRate
```

Notes:

- Comeback Boost does **not** apply offline.
- Eviction Night and crash do **not** apply offline (those require presence). Use the player's ordinary online income rate as of logout (properties, street, rebirth multiplier only).
- VIP doubles the rate, not the cap: 8 hours offline at 2× = 16 hours of normal income, still bounded by 8 real hours.
- Grant offline cash once on load, in a modal: "While you were away: $X."
- If `elapsed < 60` seconds, skip the modal (still grant).

### 5.4 Buying, selling, slots

- Buy: server checks cash, house level, street tier, and a free slot. Deduct cash, spawn a `PropertyInstance`, attach model to the next slot.
- Sell back to the bank: `sellPrice = floor(cost * 0.4)` (**starting design value**). Not allowed if the property is `boundUntil > now` (auction binds).
- Moving between slots on your own plot is free and cosmetic.
- Co-owned Heist Bid properties cannot be sold unless all co-owners agree (majority of share, or all owners; **require 100% consent** for v1).

---

## 6. Rent, Market Crash, and missed payments

### 6.1 Timing

| Key | Starting design value |
|---|---|
| `RentIntervalSeconds` | 600 (10 minutes) |
| `CrashIntervalSeconds` | 3600 (1 hour) |
| `CrashWindowSeconds` | 600 (crash lasts one rent interval) |
| `CrashWarningSeconds` | 60 |
| `RentWarningSeconds` | 30 |
| `CrashRentMultiplier` | 3 |
| `EvictionNightRentMultiplier` | 2 |
| `MinRent` | 10 |
| `RentToIncomeRatio` | 0.35 |

Align the first crash window to start `CrashIntervalSeconds` after the server instance started, then every hour. Do **not** depend on wall-clock hour for the crash (to prevent mid-session confusion on fresh servers). Eviction Night **does** use wall-clock time (Section 10).

Show two HUD timers at all times: **Next Rent** and **Next Crash** (or "CRASH LIVE" during the window).

### 6.2 Rent formula

Computed at collection time from current ownership (not from a cached stale value):

```
incomePerMinute = sum(property.BaseIncomePerMinute)   -- raw catalog, before rebirth/street/comeback
                                                   -- starting design: tax the base, not boosted, so
                                                   -- comeback and Eviction Night rewards don't also inflate rent

cycleMinutes = RentIntervalSeconds / 60               -- 10

raw = incomePerMinute * cycleMinutes * RentToIncomeRatio + HouseRent[houseLevel]

streetMult = StreetRentMultiplier[streetTier]
-- starting design: {1.00, 1.15, 1.35, 1.60, 2.00}

eventMult = 1
if evictionNightActive then eventMult = eventMult * EvictionNightRentMultiplier end   -- ×2
if crashWindowActive then eventMult = eventMult * CrashRentMultiplier end             -- ×3
-- Eviction Night + Crash stack: ×6. This is intentional and must be announced in the HUD.

rent = max(MinRent, floor(raw * streetMult * eventMult))
```

**Worked example (starting design values):** A Skid Row player with a Corner Shop ($60/min) and a Studio house (HouseRent 40), no event:

- raw = 60 × 10 × 0.35 + 40 = 210 + 40 = 250
- rent = 250 × 1.00 = $250
- 10-minute income from the shop = $600, net +$350 if they pay

During a Market Crash: rent = $750, 10-minute income = $600, shortfall $150 unless they held cash. This is the intended tension: **spending every dollar on upgrades right before a crash should be dangerous.**

### 6.3 Collection sequence (server)

On each rent tick, for every player with a claimed plot:

1. Compute `rent`.
2. If `rentFreeUntil > now`, skip (daily reward / promo). Still show "RENT WAIVED" on their plot.
3. If `cash >= rent`, deduct and fire `rent_paid`. Done.
4. If not, and the player has a usable Crash Insurance charge and `insuranceUsedUTCDate ~= todayUTC`, consume one charge, set the date, auto-pay the shortfall first from remaining cash then from insurance (insurance covers the unpaid remainder; cash goes to 0 if needed). Fire `insurance_used`, `rent_paid`. **Do not start an auction.**
5. Otherwise start the bankruptcy auction flow (Section 7). Fire `rent_failed`.

Rent is simultaneous for the whole street (one tick). Stagger visual popups, not the deduction.

Players without a claimed plot (spectators, just joined mid-tick) are skipped.

### 6.4 Market Crash presentation

- T-60s: street-wide banner and SFX, sky/lighting shifts slightly darker, stage clock goes red.
- During window: red ambient, "MARKET CRASH — RENT ×3" on HUD and jumbotron.
- End: lighting restores, banner "Markets stabilize."

Crashes happen even if the street is empty of players (timers keep running). No auction if nobody missed rent.

---

## 7. Auction system

The auction is the soul of the game. One live auction per server, always on the center stage, always readable from any plot.

### 7.1 State machine

```
Idle
  -> Queued            (a missed rent is waiting; jumbotron shows the queue)
  -> RescueWindow      (10 seconds, starting design)
  -> LiveBidding       (60 seconds base; +15 if Lawyer Pass is invoked)
  -> SoftClose         (bid in last 5s extends by 5s, max 3 extensions)
  -> Settled           (winner pays, assets transfer, bankrupt reset)
  -> CancelledRescue   (friends + owner filled RescueCost)
  -> CancelledOwnerPay (owner paid RescueCost alone or with help, including Lawyer time)
  -> CancelledNoBids   (no valid bid at expiry: assets go to the Bank, player still bankrupt)
  -> Idle              (pop next queued case, if any)
```

Never run two `LiveBidding` states at once. If two players fail the same rent tick, queue in deterministic order: highest `FairValue` first (better spectacle), then userId.

### 7.2 Timing config (starting design values)

| Key | Value |
|---|---|
| `RescueWindowSeconds` | 10 |
| `AuctionDurationSeconds` | 60 |
| `LawyerPassExtraSeconds` | 15 |
| `SoftCloseWindowSeconds` | 5 |
| `SoftCloseExtensionSeconds` | 5 |
| `MaxSoftCloseExtensions` | 3 |
| `MinBidRatio` | 0.40 |
| `MinBidFloor` | 25 |
| `BidIncrementRatio` | 0.05 |
| `BidIncrementFloorPerStreet` | 50 × streetTier |
| `AssetBindSeconds` | 7200 (2 hours) |
| `DeedToCashRatioIfAlreadyHigher` | 0.30 |

### 7.3 Lots and fair value

A bankruptcy auction is **one estate lot** (house + all income properties + cosmetic trophies stay with the owner; cosmetics are never auctioned). This keeps the 60-second show focused.

```
FairValue = HouseUpgradeCost[houseLevel]   -- cost to reach that level from the previous one
           + sum(property.Cost for each property)
           -- starting design: use the step cost, not the sum of all house tiers.
           -- Optional later tune: sum of all step costs 2..houseLevel. Put both in Config comments;
           -- ship with STEP cost so early auctions on level 4–5 still have reachable min bids.

MinBid = max(MinBidFloor, floor(FairValue * MinBidRatio))
```

Golden Auctions use a catalog `MinBid` per item instead of this formula.

### 7.4 Bidding rules

- Currency: **in-game cash only**. Never Robux. Never "tickets" bought with Robux that convert to bids.
- To place a bid `B`: `B >= currentBid + increment` (or `>= MinBid` if first bid). `increment = max(BidIncrementFloorPerStreet, ceil(currentBid * BidIncrementRatio))`.
- **Escrow:** on accepting bid `B`, the server locks `B` from the bidder's spendable cash (`cash` stays on the profile but `reservedCash += B`). The previous bidder's escrow is released immediately. Spendable = `cash - reservedCash`. Rent, shops, and other bids use spendable only.
- The bankrupt player cannot bid on their own estate (they may only pay `RescueCost` to cancel).
- Soft-close: a valid bid with `endsAt - now <= 5s` and `extensions < 3` sets `endsAt += 5s` and increments extensions.
- Disconnect does not cancel an escrowed bid. If the bidder is gone at settlement and still has the reserved cash, they still win and assets wait in their inventory until they next claim a plot.
- Bid rate limit: 4 bids per player per 2 seconds (anti-remote-spam). Invalid bids return a reason, no escrow change.

### 7.5 Rescue (chip-in)

During `RescueWindow` **and** the entire live auction until settlement:

```
RescueCost = ceil(overdueRent * 1.10)    -- 10% late fee, starting design
```

- Up to `MaxRescuers = 4` contributing players plus the owner.
- Each non-owner contributor may pay at most `MaxSharePerRescuer = 0.75` of `RescueCost` (**rescue cap** — a single rich friend cannot silently cover everything; at least 25% must come from the owner or other friends).
- The owner has no cap; they can pay 100% alone.
- Contributions are escrowed and shown on the stage progress bar.
- If `sum(contributions) >= RescueCost` at any time: cancel auction, pay the rent + fee, refund excess, release bid escrows, owner keeps the estate. Fire `auction_rescued`.
- **Rescue caps (anti-abuse):**
  - A given player may be successfully rescued at most `MaxRescuesPerPlayerPerUTCDay = 3` times.
  - A given rescuer may contribute to at most `MaxRescueActionsPerRescuerPerUTCDay = 8` rescues.
  - Contributors must have been in **this** server for at least `MinRescuerPresenceSeconds = 120`.
  - You cannot contribute if you are the only other account that repeatedly rescues the same user (see Section 15, alt-transfer).
- If rescue cap is already exhausted, skip `RescueWindow` and go straight to `LiveBidding` (owner can still self-pay).

### 7.6 Lawyer Pass

Consumable. The **bankrupt owner** (only) may activate one Lawyer Pass at any time before settlement. Effect: `endsAt += 15`, once per auction. This is extra time to raise or receive rescue money, not a bidding advantage. Fire `lawyer_pass_used`. Cannot stack. Soft-close extensions still apply after the extra time.

### 7.7 Settlement — there is a winner

1. Deduct the escrowed winning bid (already reserved). Excess reserved above the final bid should not exist; if it does, release the difference.
2. Credit **nothing** to the bankrupt player from the sale (starting design). The street "tax office" absorbs the bid. This keeps bankruptcy painful and avoids a loophole where friends buy your house back with your implicit cash. *Config flag `AuctionPayoutToBankruptRatio = 0` so it can be tuned later (e.g. 0.1) without a rewrite.*
3. Transfer all income properties to the winner: new owner, append property history, set `boundUntil = now + 2h`. If the winner's plot does not have enough slots, overflow goes to `pendingDeeds` / inventory and can be placed later or auto-sold to the bank at 40% when they dismiss the overflow prompt.
4. **House deed:** winner receives `HouseDeed{level = bankruptHouseLevel}`.
   - If `winner.houseLevel < deed.level`, they may **apply** it immediately or later: `houseLevel = deed.level` (this is the allowed skip). Applying is a deliberate button, so they can choose timing.
   - If `winner.houseLevel >= deed.level`, auto-convert to cash: `floor(HouseUpgradeCost[deed.level] * 0.30)`.
5. Reset the bankrupt player (Section 8).
6. Append Hall of Fallen Millionaires and property history. Announce on the jumbotron: `"[Winner] bought [Bankrupt]'s [House Name] for $X"`.
7. Fire `auction_won`, `auction_bankrupt`.

### 7.8 Settlement — no bids

Assets go to the **Bank** (system). Player still goes bankrupt (Section 8). Banked properties can reappear as Golden Auction lots (prefer this over deleting them). Fire `auction_no_bids`.

### 7.9 Bid sniping rules (product + technical)

- Soft-close as above (primary anti-snipe).
- No hidden bids. The jumbotron shows current bid, bidder display name, time left, and increment.
- Server timestamp only; client clocks never decide `endsAt`.
- Late remotes with `clientTime` after `endsAt` are rejected even if they "look" on time on the client.

### 7.10 Queue and Billionaire Row

On streets 1–4, play queued auctions back-to-back (5-second beat between).

On **Billionaire Row**, collapse bankruptcies into **one server-wide auction per hour** (the street's spectacle). Additional failures wait in queue and are combined into that hourly show when possible (highest FairValue estate goes live; others wait for the next hour). The hourly slot should land near the crash window so the whole street is already watching. Jumbotron lists the queue.

---

## 8. Bankruptcy, Comeback Boost, Fallen Millionaire

On bankruptcy (auction settled with or without bids, including no-bid):

1. `cash = StartingCash` (starting design: **75**). Release any of the bankrupt player's reserved cash that is not a bid they placed on *someone else's* still-live auction (rare; handle carefully).
2. `houseLevel = 1`. Swap model to Cardboard Box on the **same plot** (public shame + revenge hook).
3. Clear placed properties (they already transferred or went to the Bank).
4. `comebackBoostUntil = now + 600`. Income ×2 while online only, 10 minutes.
5. `fallenMillionaire = true` (tag remains until they reach house level 5 again, starting design). Increment `lifetimeBankruptcies`.
6. Nameplate shows **"Fallen Millionaire"** and a muted crown icon.
7. Full-screen but skippable stinger: "YOU'RE BANKRUPT — 2× Comeback, 10:00. Take it back."
8. Pending house deeds in their inventory are kept (they earned those; do not wipe). Cosmetics kept. Gamepasses kept. Streak kept.
9. Crash Insurance already would have prevented this; do not also consume it here.

---

## 9. Streets and rebirth

### 9.1 Streets (tiers)

| Tier | Id | Display name | Rebirths required | Character | Extra event |
|---:|---|---|---:|---|---|
| 1 | `SkidRow` | Skid Row | 0 | Cheap, chaotic, small auctions, tutorial feel | — |
| 2 | `SuburbLane` | Suburb Lane | 1 | First real shops and renters, lawns, mailboxes | — |
| 3 | `Downtown` | Downtown | 2 | Towers, crashes hit everyone hard | — |
| 4 | `OceanDrive` | Ocean Drive | 3 | Luxury villas, neon dusk | **Tax Raid** (Section 10.3) |
| 5 | `BillionaireRow` | Billionaire Row | 4, plus Top 1% gate | Marble, gold trim, one hourly spectacle auction | Hourly queued auction (Section 7.10) |

**Billionaire Row Top 1% gate (starting design):** in addition to 4 rebirths, the player's `lifetimeEarnings` must be at or above the 99th percentile of lifetimeEarnings among players who have 4 rebirths, refreshed daily from OrderedDataStore. If the percentile is not yet meaningful (fewer than `MinPlayersForPercentile = 200` at that rebirth band), use a fallback threshold `BillionaireRowFallbackLifetimeEarnings = 50,000,000`. Players who later fall out of the top 1% **keep access** (no demotion); the gate is entry-only.

### 9.2 Rebirth rules

A player may rebirth when **all** are true (starting design values):

| From → To | Min house level | Min lifetime earnings | Other |
|---|---:|---:|---|
| Skid Row → Suburb Lane | 5 (Row House) | 25,000 | — |
| Suburb Lane → Downtown | 7 (Villa) | 250,000 | — |
| Downtown → Ocean Drive | 8 (Penthouse Tower) | 2,000,000 | — |
| Ocean Drive → Billionaire Row | 10 (Billionaire Estate) | 20,000,000 | Top 1% gate above |

On rebirth:

- `rebirthCount += 1`, `streetTier += 1`.
- `rebirthIncomeMultiplier = 1.0 + 0.15 * rebirthCount`.
- House resets to a **street start level**, not always cardboard: `{1, 3, 4, 5, 6}` for arrivals on streets 1–5 (**starting design**). This avoids a brutal empty feeling after a long grind while still giving a new climb.
- Income properties: convert to cash at `0.4 * cost` (same as sell) and clear slots. Do not take properties up a street (keeps each street's economy intact).
- Cash: keep current cash, plus `RebirthGrant[newStreet]` starting design `{0, 2,000, 15,000, 75,000, 300,000}`.
- Cosmetics, Hall history, deeds, gamepasses, streak: kept.
- Teleport the player to a server of the new street tier (ReserveServer or matchmaking teleport).

Rebirth is always a confirm modal with a clear loss/keep list. It cannot be bought with Robux.

### 9.3 Street rent and income multipliers

Repeated here for the Config module:

| Street | Rent multiplier | Income multiplier |
|---:|---:|---:|
| 1 Skid Row | 1.00 | 1.00 |
| 2 Suburb Lane | 1.15 | 1.10 |
| 3 Downtown | 1.35 | 1.25 |
| 4 Ocean Drive | 1.60 | 1.45 |
| 5 Billionaire Row | 2.00 | 1.75 |

---

## 10. Timed events

### 10.1 Golden Auction — every 2 hours

| Key | Starting design value |
|---|---|
| `GoldenAuctionIntervalSeconds` | 7200 |
| `GoldenAuctionDurationSeconds` | 60 (same machine as player auctions, no rescue window) |
| `GoldenAuctionWarningSeconds` | 120 |

The system places **one rare lot** on the stage. Lots rotate from a weighted table (free / in-game, **not** a Robux crate):

| Lot | Weight (starting) | Min bid (starting) | Notes |
|---|---:|---:|---|
| Rare furniture kit | 40 | 2,000 | Cosmetic plot set |
| Auction Purse cash crate (fixed cash, not random at purchase — the lot is a known cash amount shown up front, e.g. $5,000) | 25 | 2,500 | Show the exact cash on the jumbotron |
| House Deed: Row House (5) | 15 | 8,000 | |
| House Deed: Townhouse (6) | 10 | 25,000 | |
| House Deed: Villa (7) | 6 | 80,000 | The clip lot |
| Unique Golden Auction-only house trim | 4 | 15,000 | Cosmetic, not paid random — the lot is the specific trim announced in advance |

**Announce the exact lot and min bid at T-120s.** Players must know what they are bidding on. Weights above are for *which lot the server rolls when it schedules the event*, and that roll happens at announce time, not at settle time.

If a Bank-held bankruptcy property exists, it has priority over a random furniture kit (still announced in advance).

Golden Auctions use the same escrow / soft-close rules. They yield to a live bankruptcy auction: if a bankruptcy starts, wait until it finishes, then run Golden (do not skip the interval forever; run as soon as the stage is free, then schedule +2h from the actual start).

### 10.2 Eviction Night (weekend)

- **When:** Friday 20:00 to Sunday 23:00 **America/New_York** (US Eastern, handles DST via a proper timezone library or a maintained offset table). This is the "8pm US time" peak mentioned in the concept; the Friday 20:00 open is the flagship moment.
- **Prime window:** Saturday 20:00–22:00 America/New_York — extra stage VFX, system message, and a guaranteed Golden Auction at 20:30 if one is not already due.
- **Effects:** rent ×2, income rewards ×2 (`EvictionNightRewardMultiplier = 2`). Stacks with crash (HUD must say "EVICTION NIGHT + CRASH — RENT ×6").
- **Presentation:** purple/red lighting, "EVICTION NIGHT" banner, special SFX. Push a Roblox notification to subscribed players at T-30 minutes if they opted into notifications (optional, post-M3).

### 10.3 Tax Raid (Ocean Drive only)

| Key | Starting design value |
|---|---|
| `TaxRaidIntervalSeconds` | 1800 |
| `TaxRaidWarningSeconds` | 90 |
| `TaxRaidAmount` | `max(MinRent, floor(currentRent * 0.5))` using the player's *ordinary* (non-crash, but including Eviction Night if active) rent |
| `TaxRaidPayWindowSeconds` | 90 |

NPC "City Tax" inspectors appear on the street. Each plotted player is billed `TaxRaidAmount`. Pay from spendable cash in 90 seconds or the standard auction flow starts (insurance can still save them; counts as a missed payment). This is an **extra bill**, not a replacement for the 10-minute rent.

Do not run a Tax Raid and a Market Crash window at the same time; delay the raid until the crash window ends.

### 10.4 Heist Bid

A party of **3 or 4 friends** co-bids on a **Villa-tier or higher** lot (bankruptcy estate with `houseLevel >= 7`, or a Golden Villa+ deed).

Rules:

- Leader opens a Heist Bid party (server-side party object). Invites only friends (Roblox friend check) in the same server.
- Members deposit cash into a pool (escrow). A member's share = their deposit / total pool.
- The party cannot go live with fewer than 3 funded members or with `pool < MinBid`.
- Only the leader submits bids, using the pool as the cash source. Members see the bid UI.
- On loss or cancel: 100% refund to members.
- On win: the lot is **co-owned**. Income is split each tick by share. Placement: the property models sit on the **leader's plot** (v1). Other members see a "Heist Share" line in their HUD income.
- Applying a co-owned house deed: the **highest share** member (ties: leader) gets the apply right. Others receive cash equal to `DeedToCashRatioIfAlreadyHigher` of their share of house step cost (starting design), so they are not unpaid.
- Selling a co-owned property requires 100% consent.
- Heist Bid cannot be used to rescue (rescue is a separate pool).
- Anti-abuse: a player may participate in `MaxHeistBidsPerUTCDay = 5` parties. Alts: Section 15.

---

## 11. Daily rewards, streaks, Landlord Spin

Timezone for all daily systems: **UTC date**. Show "resets in HH:MM" on the UI.

### 11.1 7-day streak (days 1–7, then weekly cycle)

Streak increments when the player claims the daily chest (not merely joins). Miss a UTC day → streak would reset to 0 unless they **streak-save**.

| Day | Reward (starting design values) |
|---:|---|
| 1 | Cash: `250 * streetTier` |
| 2 | Rent-Free Day: `rentFreeUntil = now + 24h` (waives rent and Tax Raid bills; crash insurance unused) |
| 3 | Rare furniture (random from the *Rare* furniture pool; **free**, odds labeled) |
| 4 | Auction Boost (consumable, see below) |
| 5 | House skin (from the "Streak Week" cosmetic pool; if already owned, cash fallback `500 * streetTier`) |
| 6 | Crash Insurance ×1 charge |
| 7 | **Mystery Deed** (free roll, odds labeled, can roll up to a Villa) |

After day 7, the 7-day pattern repeats for rewards 1–7, but the streak counter keeps climbing for day 14 / 28 milestones.

### 11.2 Day 14 and 28 skins

| Milestone | Reward |
|---|---|
| Streak day 14 (cumulative, not necessarily the first 14 calendar days if they saved) | Exclusive house skin **"Leaseholder"** — cannot be bought with Robux |
| Streak day 28 | Exclusive house skin **"Landlord Emeritus"** — cannot be bought with Robux |

Each is granted once per account. If they drop streak and rebuild, they do not get duplicates; cash fallback `5,000` / `15,000`.

### 11.3 Mystery Deed odds (free, labeled in UI)

Starting design values. Show this exact table in the reward preview:

| Result | House level granted | Chance |
|---|---:|---:|
| Trailer Deed | 3 | 40% |
| Studio Deed | 4 | 30% |
| Row House Deed | 5 | 18% |
| Townhouse Deed | 6 | 8% |
| Villa Deed | 7 | 4% |

Apply rules same as auction deeds (Section 7.6). Never sell Mystery Deeds or re-rolls for Robux.

### 11.4 Auction Boost (day 4 item)

Single-use consumable. If the holder **wins** an auction within 24 hours of activation (or of grant if auto-active): they receive a **20% cash rebate** of the winning bid (`AuctionBoostRebateRatio = 0.20`). One boost per win. Expires unused after 24 hours. Not purchasable for Robux in v1 (keep it a streak reward).

### 11.5 Landlord Spin (daily, free)

One free spin per UTC day at the kiosk. **Do not sell extra spins for Robux.** Odds labeled on the wheel UI before spinning.

Starting design odds:

| Prize | Chance | Notes |
|---|---:|---|
| Cash `100 * streetTier` | 35% | |
| Cash `400 * streetTier` | 20% | |
| Common furniture | 20% | |
| Rare furniture | 10% | |
| Auction Boost | 7% | |
| Crash Insurance ×1 | 5% | |
| Street Stall property (or cash fallback if no slot and they already have 2+ stalls) | 2.5% | |
| House Deed: Studio (4) | 0.5% | |

### 11.6 Streak save

If the player missed yesterday (UTC) and their streak was ≥ 1, the daily UI offers **Restore Streak** for 24 hours after midnight UTC:

- In-game cash price (starting design): `StreakSaveCash = 500 * streakDays * streetTier` (capped at `25,000`).
- Or Robux product `StreakSave` (suggested price in Section 16).
- Restoring keeps the same streak count and allows today's claim.
- Cannot buy a streak save "ahead of time." Cannot restore after the 24-hour window (streak is then 0).

---

## 12. Hall of Fallen Millionaires and property history (moat)

These exist so a copy of the game starts empty and feels empty.

### 12.1 Hall of Fallen Millionaires

A permanent, world-space board plus a UI page.

Each entry:

```
{
  entryId, timestamp,
  bankruptUserId, bankruptName,
  winnerUserId, winnerName,          -- nil if no bids (Bank)
  houseLevel, houseName,
  salePrice,                         -- 0 if Bank
  streetTier, serverJobId (debug)
}
```

- **Server board** shows the most recent 20 events that happened **in this server instance**, plus a "World Hall" ticker of the global last 10.
- **Global Hall** is cross-server: every settlement publishes to MemoryStore and is flushed to a DataStore log (Section 17).
- Entries are never deleted (retention: keep the latest `HallMaxGlobalEntries = 5000` in the rolling DataStore; the all-time count can still increment).
- Clicking an entry opens a read-only profile snippet: times bankrupt, houses lost, houses bought.

### 12.2 Property history

Every `PropertyInstance` and every **plot house lineage** carries:

```
history = { { userId, displayName, at, reason } }  -- reason: "bought" | "auction_win" | "deed" | "spin" | "mystery" | "bank" | "sold"
```

Prompt on any property or house: **"This villa has had 47 owners"** (count of unique userIds, and a scrollable list of the last 20 transfers with names and dates).

House lineage lives on the **instance that transfers** (the deed carries history; when applied, it merges onto the winner's house record as a new chapter). A brand-new cash upgrade adds a "bought" chapter.

This is also a clip hook ("this house has had 47 owners — I just became #48").

---

## 13. Economy balancing

### 13.1 Design goals

- A new Skid Row player can afford a Street Stall immediately and a Tent within a few minutes.
- By the first Market Crash (~60 minutes), a reasonably active player can survive if they did not spend every dollar, and can go bankrupt if they did. **Both outcomes must happen on a full street.**
- Rent should feel tight during crashes, comfortable between them.
- Auction min bids on early houses must be reachable by peers, not only by a runaway leader.
- Monetization speeds comfort (insurance, time, cosmetics, offline), never street rank or auction power.

### 13.2 Global economy constants

All **starting design values**:

| Key | Value |
|---|---|
| `StartingCash` | 75 |
| `IncomeTickSeconds` | 1 |
| `SellBackRatio` | 0.40 |
| `RebirthIncomeBonusPerRebirth` | 0.15 |
| `ComebackIncomeMultiplier` | 2.0 |
| `ComebackDurationSeconds` | 600 |
| `OfflineIncomeCapSeconds` | 28800 |
| `VIPOfflineIncomeMultiplier` | 2.0 |
| `InsuranceMaxUsePerUTCDay` | 1 |

### 13.3 Early-game walkthrough (sanity check, not data)

Player buys Street Stall ($50), leftover $25. Income $8/min ≈ $80 per 10 minutes. Rent at house 1 with $8/min: raw = 8×10×0.35 + 0 = 28, rent $28 (above `MinRent` 10). Net ≈ $52 / 10 min. Tent costs $250 ≈ 50 minutes of this net, faster if they also save and buy a Food Cart after Tent. This is slow enough that auctions stay interesting, fast enough that session one feels like progress. **Retune `StartingCash`, stall income, and Tent cost together if Week 1 feel is off.**

### 13.4 Approximate time-to-house (solo, no auction deeds, Skid Row, starting values)

These are planning estimates, not promises. They assume the player buys the best affordable property, keeps a crash reserve of ~1× crash rent, and is mostly online.

| Reach house | Rough online time |
|---|---|
| Tent | 30–60 min |
| Trailer | 1.5–3 h |
| Studio | 4–8 h |
| Row House | 1–2 days of normal play |
| Townhouse and up | Multi-day, helped by auction deeds and rebirth later |

### 13.5 Formula summary (copy into comments in `IncomeService` / `RentService`)

```
spendableCash = cash - reservedCash

effectiveIncomePerMinute =
    sum(baseIncomePerMinute)
    * streetIncomeMultiplier
    * (1 + 0.15 * rebirthCount)
    * (comebackActive and 2 or 1)
    * (evictionNightActive and 2 or 1)

rent = max(10, floor(
    (sum(baseIncomePerMinute) * 10 * 0.35 + HouseRent[level])
    * streetRentMultiplier
    * (evictionNightActive and 2 or 1)
    * (crashWindowActive and 3 or 1)
))

FairValue = HouseUpgradeCost[level] + sum(property.Cost)
MinBid    = max(25, floor(FairValue * 0.40))
increment = max(50 * streetTier, ceil(currentBid * 0.05))
RescueCost = ceil(overdueRent * 1.10)
```

### 13.6 Cash sinks (keep these, don't add silent decay)

House upgrades, properties, rescue late fees, Tax Raid, streak saves, cosmetic furniture bought with cash (a small catalog, optional), and auction bids. There is **no** daily tax that deletes AFK cash beyond rent (which requires a plot and presence at collection, except Tax Raid on Ocean Drive while present).

### 13.7 Tuning knobs if week 1 is "nobody goes bankrupt"

Raise `RentToIncomeRatio` in 0.05 steps, or widen `CrashWindowSeconds` so more rent ticks fall inside it, or slightly raise `HouseRent`. If "everyone goes bankrupt every crash," lower the ratio or raise `StartingCash` / early incomes. Change one knob at a time.

---

## 14. Monetization

**Hard rule:** auction wins, rebirth, street access (except the earned Billionaire Row gate), income rates (except VIP's **offline** multiplier), rent amounts, bid power, and Hall rank cannot be sold for Robux.

### 14.1 Product list (MarketplaceService)

Suggested Robux prices are **suggestions only**, not data. Confirm against live price points of comparable sim/tycoon passes before launch. Use developer products for consumables, gamepasses for permanent unlocks.

| Config id | Type | Suggested Robux | Grant |
|---|---|---:|---|
| `CrashInsurance1` | Developer product | 79 | +1 Crash Insurance charge |
| `CrashInsurance5` | Developer product | 299 | +5 charges (best value on the insurance line) |
| `LawyerPass1` | Developer product | 39 | +1 Lawyer Pass |
| `LawyerPass5` | Developer product | 129 | +5 Lawyer Passes |
| `StreakSave` | Developer product | 49 | Restore yesterday's streak (only if eligible; otherwise refund via `ProcessReceipt` not-granted and do not charge — actually on Roblox you must grant or the charge still happens; **validate eligibility before prompting purchase**, and if receipt arrives ineligible, grant a cash consolation `StreakSaveIneligibleFallbackCash = 1,000` and still return `PurchaseGranted`) |
| `VIPLandlord` | Gamepass | 399 | Permanent: 2× offline income, gold nametag, small VIP icon, VIP chat tag |
| `PrivateStreet` | Gamepass | 199 | Allows creating / using a Private Street (see below). Also configure Roblox paid private servers in Game Settings as the actual instance mechanism (suggested private-server monthly price: 99 Robux — set in Creator Hub, not in MarketplaceService code) |
| `HouseSkin_NeonSign` | Developer product | 99 | Cosmetic house trim |
| `HouseSkin_MarbleFacade` | Developer product | 199 | Cosmetic house trim |
| `HouseSkin_GoldTrim` | Developer product | 399 | Cosmetic house trim (not the day 14/28 exclusives) |
| `Car_Beater` | Developer product | 99 | Cosmetic car, Townhouse pad required to display |
| `Car_Sports` | Developer product | 249 | Cosmetic car |
| `Car_Limo` | Developer product | 399 | Cosmetic car |
| `Heli_News` | Developer product | 349 | Cosmetic helicopter, pad required (level 9+) to display; still owned if bought earlier |
| `Heli_Gold` | Developer product | 799 | Cosmetic helicopter |

**Crash Insurance is the expected bestseller.** Surface it contextually: when the crash warning starts, if the player is short on a projected crash rent and has no charge, show a non-blocking "Protect me once today" purchase prompt (never a modal that steals input during the 10-second rescue).

### 14.2 Crash Insurance rules

- Inventory: integer `insuranceCharges`.
- At most **one use per UTC day**, even if the player holds 20 charges (`InsuranceMaxUsePerUTCDay = 1`).
- A use is consumed only on a successful auto-pay of a missed rent or Tax Raid (Section 6.3).
- Daily streak day 6 and rare Landlord Spin awards can add charges.
- Charges persist across bankruptcy and rebirth.
- UI: "Insurance: 2 ready · already used today" is clearer than hiding the stack.

### 14.3 Lawyer Pass and VIP

- Lawyer Pass: stackable integer, one use per auction, only by the bankrupt owner.
- VIP Landlord: checked via `MarketplaceService:UserOwnsGamePassAsync` and cached on the profile. Gold nametag is visible on the plot and nametag. **Does not** multiply online income, rent, or bid power.

### 14.4 Private Street

A private Roblox server running the same game. The owner (gamepass holder) can invite friends, pick the street **theme** they have unlocked (cannot pick Billionaire Row unless they have access), and optionally toggle:

- `FriendlyRent` (starting design: rent multipliers ×0.75) — **off by default**, and **Private Street progress is the same profile** so this could be abused to grind cheaply. **v1 decision: do not offer reduced rent.** Private Street is the same economy, quieter, with friends. Anti-alt wealth transfer still applies.
- The hook here is "play with friends and Heist Bid," not a farm.

### 14.5 What cannot be sold

- Auction wins, bid credits, cash bundles (no "buy $100,000").
- Mystery Deed, Landlord Spin, extra spins, random house deeds, random furniture crates.
- Billionaire Row access, rebirth skips, "skip rent forever" passes.
- Day 14 / day 28 skins.

Cash bundles are deliberately absent to protect the auction economy and to avoid gambling-adjacent "buy chips" framing.

---

## 15. Anti-exploit and integrity

### 15.1 Authority

- The server is the only place that mutates cash, reservedCash, properties, house level, street, charges, streaks, and auction state.
- All remotes are requests. Validate types, finite numbers, non-negative amounts, ownership, and cooldowns.
- Never trust client-supplied prices, rent, income, or `endsAt`.
- Use a single `EconomyService.AddCash` / `TrySpend` that rejects if `spendable < amount`, logs the reason, and is the only write path.

### 15.2 Movement and world

Standard Roblox anti-fly/anti-teleport is optional for v1 (this is not a competitive fighter). Do not put payouts or claim buttons solely at the client. Plot claim, kiosk use, and bid buttons must have server range checks (`MaxInteractDistance = 24` studs, starting design), except auction bid/rescue, which are allowed from anywhere on the street so people can bid from their plot. Bid remotes still require the player to have a character in this server and not be kicked/banned.

### 15.3 Remote spam and invalid states

- Bid: max 4 / 2s. Rescue contribute: max 2 / 2s. Shop buy: max 2 / 1s.
- Ignore bids when auction is not `LiveBidding` / `SoftClose`.
- Clamp all numbers; reject NaN / Inf.

### 15.4 Alt-account wealth transfer (required)

There is **no player-to-player cash send**. The only legal cash movements between players are auction settlement (to the tax office, not to the bankrupt player), rescue contributions, and Heist Bid pools.

Additional guards:

1. **Rescue caps** as in Section 7.5 (amount share, daily counts, presence time).
2. **Pair limits:** if account A has contributed to account B's rescue or has won B's bankruptcy auction more than `MaxPairRescueOrWinPerUTCDay = 2` times in a day, or `MaxPairRescueOrWinPerUTCWeek = 5` times in 7 days, block further rescue from A→B and block A from bidding on B's estate for 24 hours. Message: "Rescue / buy-back limit reached with this player."
3. **Account age gate for high bids:** if `AccountAge < 7` days, cap bids at `NewAccountMaxBid = 5,000` (starting design). New accounts can still play and bid small.
4. **Same-server create-time cluster:** if two accounts with `AccountAge < 3` days and similar join times repeatedly move value (rescue, heist, auction) one way, flag for analytics `integrity_flag` and apply the pair limit immediately (threshold: 2 transfers).
5. **Auction bind:** properties won at auction cannot be sold for 2 hours, reducing instant cash-out to an alt.
6. **No off-street trades.**
7. Log `fromUserId`, `toUserId`, `kind`, `amount` for every rescue, heist deposit, and auction win to a server log / analytics for later manual review.

Roblox does not give a reliable hardware id. These rules are the v1 mitigation. Do not claim they are perfect.

### 15.5 Bid sniping and auction integrity

Already specified: server clock, escrow, soft-close, no hidden bids, no owner bidding on own estate, late remote rejection.

Also:

- A player's bid cannot exceed spendable cash (checked atomically).
- Do not allow multiple pending bid remotes to double-lock cash; process bids sequentially on one auction mutex (`AuctionService.Lock`).
- If a bidder is found exploiting (speed hacks are irrelevant; remote spoofing is the risk), reject and optionally kick; never roll back a *settled* auction except via a live ops tool.

### 15.6 Duplicate session and DataStore

Session lock: a profile can be active in only one server. Use MemoryStore or a DataStore lock with a heartbeat (`SessionLockTTL = 90s`, heartbeat every 30s). If a second join happens, the old server releases on lock expiry or on `PlayerRemoving`; the new server waits up to 10 seconds for the lock, then steals if the heartbeat is stale. Never load two writable profiles at once.

### 15.7 Economy exploits to regression-test

- Buying a property with stale client price.
- Bidding after `endsAt`.
- Rescue overflow refunds (do not leave reserved cash stuck).
- Insurance used twice in one UTC day by toggling the clock (server UTC only).
- Rebirth grant farm by rebirth + immediate... (rebirth is one-way; cannot descend).
- Private server + FriendlyRent (not shipped).
- ProcessReceipt replay: always persist `receipt.PurchaseId` and return `PurchaseGranted` if already granted.
- Negative bid or contribution amounts.

---

## 16. UI screens

Build in the order listed in Section 22. Every screen has a name the client module should use.

| Screen id | Purpose | Key elements |
|---|---|---|
| `HUD` | Always on | Cash (spendable), income/min, Next Rent timer, Next Crash timer / CRASH LIVE, house level icon, street name, insurance charges, comeback timer if active, Eviction Night banner slot |
| `PlotClaim` | Empty plot prompt | "Claim this plot" |
| `UpgradeHouse` | House shop | Next level name, cost, preview, Buy |
| `PropertyShop` | Buy income properties | Filtered by unlocks, cost, income/min, slots free |
| `PropertyInspect` | World prompt on a property or house | Owner, income, **owner history count and list** |
| `AuctionOverlay` | Full-street spectacle, also usable from plot | Lot title, owner, fair value hidden or shown? **Show house name + property count, show current bid, increment, time, bidder, rescue bar, Bid button, Rescue button, Lawyer button (owner only)** |
| `AuctionQueue` | Jumbotron + optional panel | Upcoming lots |
| `RescueSheet` | Contribute cash | Slider/caps, own remaining cap, confirm |
| `BankruptStinger` | Skippable after 1.5s | Comeback 10:00, Fallen Millionaire |
| `ComebackToast` | Small HUD | Time remaining, 2× |
| `OfflineIncomeModal` | On join if grant > 0 | "$X while you were away" |
| `DailyRewards` | 7-day chest row | Streak count, claim, odds preview for day 7, streak-save CTA if eligible |
| `LandlordSpin` | Wheel | Labeled odds, spin once, prize reveal |
| `StreakSaveModal` | Cash or Robux | Prices, time left to save |
| `InsurancePrompt` | Contextual, non-blocking | During crash warning if short |
| `RobuxShop` | Catalog | Insurance, Lawyer, VIP, cosmetics, Private Street; clear "does not affect bids / rank" footer |
| `Cosmetics` | Owned skins, cars, helis | Equip / unequip, pad requirements |
| `InventoryDeeds` | House deeds and overflow properties | Apply / place / sell overflow |
| `HallOfFame` | Board + full UI | Local recent, World Hall ticker, search self |
| `Leaderboards` | Three boards | Net worth, lifetime earnings, estates bought (auction wins) |
| `RebirthModal` | Confirm | Requirements checklist, what you keep / lose / gain, destination street |
| `HeistParty` | Create / invite / deposit / shares | Friend list, pool vs min bid |
| `EventBanner` | Golden, Eviction, Tax Raid, Crash | Timers, effects in plain language ("Rent ×3") |
| `TaxRaidBill` | Pay window | Amount, timer |
| `Settings` | Music, SFX, nameplate cash toggle, reduce motion, notifications opt-in | |
| `Tutorial` | First session, 5 beats | Claim plot, buy stall, see rent timer, watch or dummy-explain auction, survive or watch a crash warning. Skippable. No blocking after first 10 minutes. |
| `PrivateStreetPanel` | Owner only | Invite, street theme they unlocked |
| `LegalOdds` | Reusable | Any random free reward must link a readable odds table |

World jumbotron mirrors `AuctionOverlay` numbers so spectators who never open the UI still understand the show.

---

## 17. Server architecture and data

### 17.1 Principles

- One experience, street tier chosen at matchmaking / teleport.
- **Server-authoritative** simulation: income ticks, rent, crashes, auctions, events run on the server (Heartbeat or a 1s tick).
- Profile loaded before the player can spend. If DataStore fails, the player is a spectator with a retry prompt — do **not** create a throwaway rich profile.

### 17.2 Session locking and profile load

Recommended: a ProfileService-style pattern, or a custom equivalent.

1. On `PlayerAdded`, acquire lock key `session:{userId}` in **MemoryStore** (`AddAsync` with TTL 90s). Heartbeat `UpdateAsync` / refresh every 30s.
2. Load DataStore key `player:{userId}` (versioned schema `schemaVersion = 1`).
3. If lock held by a live other session, wait ≤10s, else steal if `heartbeatAt` is older than 90s.
4. On `PlayerRemoving` or server close: grant nothing new, flush profile, release lock.
5. Autosave every `AutosaveSeconds = 60`, and immediately after: purchases, auction settlement, rebirth, insurance use, streak claim.

`UpdateAsync` for all DataStore writes. Never `SetAsync` for player profiles (race-safe).

### 17.3 Player DataStore schema (`player:{userId}`)

```lua
-- schemaVersion = 1
PlayerProfile = {
  schemaVersion = 1,
  userId = 0,
  createdAt = 0,
  lastSeenAt = 0,
  cash = 0,                 -- integer, cents not required; use integer dollars
  reservedCash = 0,         -- should be 0 when no live session; never persist a stale reserve across sessions without an auction escrow table
  houseLevel = 1,
  streetTier = 1,
  rebirthCount = 0,
  rebirthIncomeMultiplier = 1.0,
  properties = { --[[ PropertyInstance ]] },
  pendingDeeds = { --[[ HouseDeed ]] },
  pendingProperties = { --[[ overflow PropertyInstance ]] },
  cosmeticsOwned = { --[[ string ids ]] },
  cosmeticsEquipped = { houseSkin = "", car = "", heli = "" },
  insuranceCharges = 0,
  insuranceUsedUTCDate = "", -- "YYYY-MM-DD" or ""
  lawyerPasses = 0,
  auctionBoostExpiresAt = 0,
  rentFreeUntil = 0,
  comebackBoostUntil = 0,
  fallenMillionaire = false,
  houseHistory = { --[[ history chapters ]] },
  streak = {
    count = 0,
    lastClaimUTCDate = "",
    longest = 0,
    claimed14 = false,
    claimed28 = false,
  },
  lifetimeEarnings = 0,
  lifetimeSpentCash = 0,
  lifetimeBankruptcies = 0,
  lifetimeAuctionsWon = 0,
  lifetimeRescuesReceived = 0,
  gamepassesCached = { VIPLandlord = false, PrivateStreet = false },
  receiptIds = { --[[ [purchaseId] = true ]] },
  settings = { nameplateShowCash = false, music = true, sfx = true, reduceMotion = false },
  integrity = {
    rescuesReceivedUTCDate = "",
    rescuesReceivedToday = 0,
    rescueActionsUTCDate = "",
    rescueActionsToday = 0,
    heistUTCDate = "",
    heistToday = 0,
    pairEvents = { --[[ key "a:b" = { countDay, day, countWeek, weekStart } ]] },
  },
}
```

`reservedCash` in a mid-auction crash (server shutdown): persist `openEscrows` on a **separate** `auction_recover` MemoryStore or DataStore so a shutdown mid-auction can refund or complete. v1 acceptable behavior: on unexpected shutdown, refund all escrows and abort the live auction without transferring assets (owner keeps estate, rent remains unpaid → immediately re-queue on the next server they join, or forgive that one rent). **Prefer refund + forgive that rent tick** to avoid double-charging. Log it.

### 17.4 PropertyInstance

```lua
PropertyInstance = {
  instanceId = "",      -- GUID
  propertyId = "",      -- catalog id
  ownerUserIds = { 0 }, -- one id, or several for Heist (shares aligned)
  shares = { 1.0 },     -- same order as ownerUserIds, sum == 1
  slotIndex = 1,
  acquiredAt = 0,
  acquiredHow = "bought",
  boundUntil = 0,
  history = {
    -- { userId, displayName, at, reason }
  },
}
```

### 17.5 Auction runtime (server memory, not the player profile)

```lua
AuctionState = {
  auctionId = "",
  kind = "Bankruptcy", -- or "Golden"
  state = "Idle",
  bankruptUserId = nil,
  lots = {},           -- estate or golden lot
  fairValue = 0,
  minBid = 0,
  currentBid = 0,
  currentBidderId = nil,
  bidHistory = {},
  endsAt = 0,
  extensions = 0,
  lawyerPassUsed = false,
  rescueCost = 0,
  rescue = { --[[ userId = amount ]] },
  escrow = { --[[ userId = amount ]] },
  queue = {},
}
```

Replicate a **public DTO** to all clients (no other players' spendable cash).

### 17.6 MemoryStore

| Key pattern | Use |
|---|---|
| `session:{userId}` | Session lock + heartbeat |
| `hall:recent` | MemoryStoreSortedMap or a queue of the last 10–50 global Hall entries for instant cross-server ticker |
| `hall:pubsub` | MemoryStoreQueue or UnsortedMap ping so other servers refresh the ticker |
| `match:{streetTier}` | Optional custom matchmaking later; v1 can use built-in servers + teleport to reserved servers per street |

MemoryStore is volatile. Hall ticker can drop; persistence is the DataStore.

### 17.7 Hall and recovery DataStores

| Key | API | Purpose |
|---|---|---|
| `hall:log:{shard}` | DataStore, append via `UpdateAsync` | Rolling global Hall entries (shard by day or by 1000-entry buckets) |
| `hall:index` | DataStore | Pointer to current shard and total count |
| `lb:netWorth` | **OrderedDataStore** | Leaderboard: current net worth = cash + FairValue of holdings + pending deeds valued at step cost |
| `lb:lifetimeEarnings` | OrderedDataStore | Leaderboard + Billionaire Row percentile |
| `lb:estatesBought` | OrderedDataStore | Auction wins |
| `lb:rebirth4Earnings` | OrderedDataStore | Population for the top 1% gate |

Update OrderedDataStores at most every 60s per player, and on bankruptcy / auction / rebirth. Clamp scores to integers (`math.floor`).

Net worth for boards should **exclude reserved cash that is escrowed in a losing way**; simplest v1: `cash + property costs + sum of house step costs 2..level` (do not subtract escrow, to avoid flicker).

### 17.8 Cross-server Hall write path

On settlement:

1. Write the entry to the in-server board immediately.
2. `MemoryStore` push for the live ticker.
3. `UpdateAsync` append to `hall:log:{shard}` (retry with backoff). If this fails, keep a `pendingHall` in the server and retry; do not fail the auction because the Hall write failed.

### 17.9 Services (logical)

`Config`, `ProfileService` (or `ProfileManager`), `EconomyService`, `IncomeService`, `RentService`, `CrashService`, `AuctionService`, `RescueService`, `PropertyService`, `HouseService`, `RebirthService`, `EventService` (Golden, Eviction, Tax Raid), `HeistService`, `DailyRewardService`, `SpinService`, `InsuranceService`, `MonetizationService` (ProcessReceipt), `HallService`, `HistoryService`, `LeaderboardService`, `MatchmakingService` / `TeleportService` wrapper, `AnalyticsService`, `IntegrityService`, `Replication` / `Net`.

---

## 18. Analytics

Use `AnalyticsService` (Roblox) and/or a thin wrapper that also `print`s in Studio. All events include `userId`, `sessionId`, `streetTier`, `houseLevel`, `rebirthCount`, `serverJobId`, `t`.

### 18.1 Required events

| Event | When | Extra fields |
|---|---|---|
| `session_start` | Profile loaded | `isNew`, `accountAge`, `offlineCashGranted` |
| `session_end` | PlayerRemoving | `sessionLengthSec`, `cashDelta`, `auctionsSeen`, `auctionsBid` |
| `rent_paid` | Success | `amount`, `crash`, `eviction`, `insurance` |
| `rent_failed` | Missed | `amount`, `shortfall`, `crash`, `eviction` |
| `insurance_used` | Auto-pay | `chargesLeft` |
| `crash_start` / `crash_end` | Window | `playersAtRisk` (spendable < projected rent) |
| `auction_queued` | Missed rent → queue | `fairValue`, `bankruptUserId` |
| `auction_started` | LiveBidding begins | `auctionId`, `kind`, `minBid`, `fairValue` |
| `auction_bid` | Accepted bid | `auctionId`, `bid`, `bidderId` |
| `auction_rescued` | Rescue filled | `auctionId`, `contributors`, `amount` |
| `auction_won` | Settlement with winner | `auctionId`, `price`, `winnerId`, `bankruptUserId`, `houseLevel` |
| `auction_no_bids` | No bidder | `auctionId` |
| `auction_bankrupt` | Reset applied | `lifetimeBankruptcies` |
| `lawyer_pass_used` | | `auctionId` |
| `house_upgrade` | | `from`, `to`, `cost` |
| `property_bought` / `property_sold` | | `propertyId`, `price` |
| `deed_applied` | | `level`, `source` |
| `rebirth` | | `fromStreet`, `toStreet` |
| `daily_claim` | | `streak`, `dayIndex`, `rewardId` |
| `spin` | | `prizeId` |
| `mystery_deed` | | `levelRolled` |
| `streak_save` | | `method` (`cash`/`robux`) |
| `robux_purchase` | ProcessReceipt granted | `productId`, `robux` (if known), `receiptId` |
| `heist_start` / `heist_win` / `heist_cancel` | | `members`, `pool` |
| `event_golden_start` | | `lotId` |
| `event_eviction_start` | | |
| `event_tax_raid` | | `paid`, `amount` |
| `tutorial_step` / `tutorial_skipped` | | `step` |
| `integrity_flag` | Pair limits, etc. | `kind`, `otherUserId` |

### 18.2 Derived product metrics (dashboards)

Compute from the events; do not invent a second logger:

- **D1 / D7 retention:** share of `session_start` users with `isNew=true` on day 0 who have a `session_start` on day 1 and day 7 (UTC). This is the launch north star along with D2–D7.
- **Session length:** distribution of `session_end.sessionLengthSec`. Aim later; no target baked into the game.
- **Auction participation:** `unique bidders / players present at auction_started`, plus `auctionsBid > 0` per session.
- **Bankruptcy rate per crash** and **insurance attach rate**.
- **Funnel:** claim plot → buy first property → first rent paid → first auction seen → first bid.

Do not delay the vertical slice on a perfect dashboard; fire the events from day one of M1 (even if only logged).

---

## 19. Roblox compliance and policy

Non-negotiable implementation requirements:

1. **Auctions use in-game cash only.** No Roblox, no paid tokens that act as chips, no "wager." UI copy says "bid $X cash," never "bet," "jackpot," or "odds of winning the auction" as if it were a prize draw. The auction is a sale of in-game property.
2. **No paid random items.** Do not sell Mystery Deeds, mystery skins, loot boxes, or extra Landlord Spins for Robux, including in regions where paid random items are allowed. This avoids regional restrictions and review risk. Free random rewards (daily Mystery Deed, Landlord Spin, day 3 furniture) **must display odds** in the UI before the player claims or spins.
3. **If policy ever changes and a paid random product is added (do not in v1):** it must be disabled in restricted regions and show odds everywhere. Leave a single `MonetizationService.ArePaidRandomItemsAllowed(player)` stub that returns `false`.
4. **Age guidelines / tone:** no real-world gambling framing, no alcohol/tobacco, no sexualized content, no graphic crime. "Steal" may appear in marketing as a hook comparison, but in-game verbs are **buy, bid, auction, evict, bankrupt, rescue.** Tax Raid is cartoon inspectors, not SWAT.
5. **Eviction / bankruptcy** is comedic and reversible (Comeback Boost, same plot). No slurs, no player-written signs without a filter (`TextService` filtering on any custom name).
6. **UGC / text:** display names from Roblox; any custom plot name is filtered and length-capped (`MaxPlotNameLength = 24`).
7. **Private servers and child safety:** standard Roblox voice/chat settings; this GDD does not require voice. Do not build custom unsafeguarded DMs.
8. **Experience questionnaire / maturity:** keep content mild (9+ / suitable for everyone as far as design is concerned). Final labels follow Creator Hub settings at publish time.
9. **Trading:** no open player trading. Reduces scams and age-policy risk.
10. **Ads / third-party payments:** none.
11. **ProcessReceipt** must always eventually return `PurchaseGranted` after granting or after a documented consolation grant; never leave a user charged without a grant path.
12. **Attribution:** third-party music only with a license. Use Roblox audio or originally licensed tracks.

---

## 20. Clip strategy (TikTok / Shorts)

Distribution is part of the design, not an afterthought. The game must produce a readable moment without a narrator.

### 20.1 Built-in clip affordances

- Stage camera: a "Watch Auction" button snaps to a cinematic camera (side 3/4 on the podium + jumbotron in frame).
- Optional **Replay buffer** later; v1 at least freezes a 3-second pose at settlement with big text: `PLAYER bought HOUSE for $X`.
- Distinct audio sting on final gavel.
- Comeback and "box to villa" upgrades have street-visible VFX.

### 20.2 Shot list for the first 10 launch clips (Week 3)

Record original edits; **never upload the same video twice** or across multiple accounts. Vary hook and cut each time.

1. "Everything you own, someone else can buy." — 60-second auction, gavel, new owner walks onto the plot.
2. "My friend's villa sold in 60 seconds."
3. "I bought my rival's villa for $1." (only if a $MinBidFloor or a collapsed bid actually happens; do not fake currency; if min bids are higher, title honestly: "I bought my rival's villa for $X.")
4. "Market Crash — rent ×3 — he had 10 seconds."
5. "From cardboard box to [house] in one session." (honest timeframe; the conceptual "box to billionaire in 1 hour" should only be used if a speed-run or deed makes it true; otherwise "box to Row House" is fine.)
6. "Friends chip in to rescue him at 00:02."
7. "Eviction Night, rent ×6 with the crash."
8. "This house has had 47 owners. I just became #48."
9. "Fallen Millionaire 2× comeback — then he bought the house back."
10. Golden Auction: "The whole street just bid on a Villa deed."

Production rules: one primary account per platform, unique hook and unique cut per clip, no stolen assets, no misleading "$1" if the bid was not $1. Clips are marketing; they are not a Roblox ranking input (Discovery uses retention, not TikTok traffic).

---

## 21. Rojo project structure

Create a Rojo project at the repo root. Suggested layout:

```
bankrupt-street/
  default.project.json
  aftman.toml                  -- optional: rojo, wally, stylua
  wally.toml                   -- optional packages
  src/
    shared/
      Config.lua               -- ALL starting design values
      Types.lua                -- type aliases for profiles, auctions, properties
      Enums.lua                -- house ids, streets, auction states, reward ids
      Formulas.lua             -- pure functions: rent, min bid, income, fair value, net worth
      ProductIds.lua           -- Marketplace product / gamepass ids (fill after Creator Hub)
      Odds.lua                 -- Mystery Deed + spin tables, helpers to roll server-side
      Remotes.lua              -- remote names, optional typings
    server/
      init.server.lua          -- wires services
      services/
        ProfileManager.lua
        EconomyService.lua
        IncomeService.lua
        RentService.lua
        CrashService.lua
        AuctionService.lua
        RescueService.lua
        PropertyService.lua
        HouseService.lua
        RebirthService.lua
        EventService.lua
        HeistService.lua
        DailyRewardService.lua
        SpinService.lua
        InsuranceService.lua
        MonetizationService.lua
        HallService.lua
        HistoryService.lua
        LeaderboardService.lua
        TeleportService.lua
        AnalyticsService.lua
        IntegrityService.lua
        PlotService.lua
        EventClock.lua         -- Eviction Night timezone
      net/
        RemoteHandler.lua      -- one inbound dispatcher with validation
    client/
      init.client.lua
      controllers/
        HUDController.lua
        AuctionController.lua
        ShopController.lua
        DailyController.lua
        HallController.lua
        TutorialController.lua
        CameraController.lua
        AudioController.lua
        PromptController.lua
        ShopRobuxController.lua
      ui/                      -- ScreenGui modules or prefab instances
        ...screens from Section 16
    server-runtime/            -- ServerScriptService entry (Rojo map)
    client-runtime/            -- StarterPlayerScripts entry
  assets/                      -- (not required in Rojo if built in Studio)
    README.md                  -- house models, stage, streets, SFX list
```

### 21.1 `default.project.json` mapping (intent)

- `src/shared` → `ReplicatedStorage.Shared`
- `src/server` → `ServerScriptService.Server`
- `src/client` → `StarterPlayer.StarterPlayerScripts.Client`
- A `ReplicatedStorage.Remotes` folder created at runtime if not in the place file.

Do not put secrets in the repo. Product ids are public but live in `ProductIds.lua`.

### 21.2 Modules rules

- `Formulas.lua` is **pure** (no DataStore, no Players). Unit-test it in Studio with a simple `src/shared/Formulas.spec.lua` or a server debug command.
- `Config.lua` is the only numeric source. Services may not define local magic numbers except animation times under 0.5s.
- Prefer one remote dispatcher over dozens of unbound RemoteEvents, but individual remotes per domain are acceptable if listed in Appendix B.

### 21.3 Place file / map

A Studio place (`.rbxl` or a Rojo-managed `map/` folder) contains: street art for Skid Row first, 12 plots with well-named attachments (`HouseAnchor`, `Slot1`..`Slot8`, `Nameplate`, `CarPad`, `HeliPad`), the stage, jumbotron SurfaceGuis, Hall board, kiosks, lighting presets for Default / Crash / Eviction / TaxRaid. Other street themes can be palette/kit swaps of the same rig in M3+.

---

## 22. Build plan and prioritized task list

All numeric feel-tuning is allowed inside Config. Do not expand scope mid-milestone.

### Milestone M0 — Project skeleton (half day)

1. Rojo project, folders, empty services, `Config.lua` copied from Appendix A, `Types.lua`, `Enums.lua`, `Formulas.lua` with rent / income / min-bid functions and a Studio smoke test.
2. Remote folder + dispatcher stub.
3. `ProfileManager` with session lock, schema v1 default profile, autosave, steal-stale-lock, Studio mock store fallback.
4. Blank Skid Row map with 12 claimable plots and a stage blockout (greybox is fine).

**Exit:** two playtesters can join, claim plots, persist cash after a Studio relog.

### Milestone M1 — Week 1 vertical slice (must be fun)

5. Plot claim / release, spawn, nameplates.
6. `EconomyService` and `IncomeService` (1s tick, HUD cash and income/min).
7. Property catalog (Skid Row four properties), buy/place/sell, slot limits, house level 1 only first, then house upgrades **through level 4 (Studio)** minimum for the slice; implementing all 10 models is not required, but the data for all 10 costs should already be in Config. Greybox house swaps are OK.
8. `RentService` + HUD timers, rent formula, simultaneous collection.
9. `CrashService` + warning, lighting, ×3 rent in window.
10. `AuctionService` + `RescueService` end-to-end: rescue window, 60s bids, escrow, soft-close, Lawyer stub (item can be granted by a debug command), settlement, no-bid path, queue.
11. Bankruptcy reset, Comeback Boost 10 min 2×, Fallen Millionaire tag, same-plot cardboard box.
12. Auction overlay + jumbotron + stage focus camera.
13. Offline income 8h cap (VIP multiplier can wait, but hook the rate).
14. Analytics events for session, rent, auction, bankrupt (print in Studio).
15. Tutorial five beats, skippable.
16. Anti-exploit v1: spendable cash, escrow, no owner self-bid, remote validation, session lock.
17. **Playtest gate (do not start M2 until this is true):** on a 6–12 player street, within 30–60 minutes, at least some players go to auction and the table finds it funny / tense, not confusing or hopeless. Tune Config if not.

**Out of scope for M1:** rebirth, streets 2–5, daily rewards, Hall persistence, Robux products, Heist, Golden Auction, Eviction Night, cosmetics.

### Milestone M2 — Week 2

18. All 10 house levels (models can still be stand-ins with clearly different silhouettes). Billionaire Estate golden statue + helicopter pad hook.
19. Remaining property catalog unlocked by house (street 2+ items can stay locked by `minStreet` but should exist in data).
20. Daily rewards 1–7, UTC streak, Mystery Deed with labeled odds, day 14/28 skins (placeholders).
21. Landlord Spin, labeled odds, one per day, no Robux extras.
22. Streak save (cash + Robux product hook).
23. Crash Insurance full rules + contextual prompt + developer products (even if product ids are test ids).
24. Lawyer Pass product + activation.
25. Hall of Fallen Millionaires in-server board + UI; start MemoryStore ticker + DataStore flush.
26. Property / house history inspect UI ("this villa has had N owners").
27. `ProcessReceipt` with receipt idempotency.
28. Leaderboards (OrderedDataStore) stub: net worth, lifetime earnings.

### Milestone M3 — Week 3

29. Rebirth to **Suburb Lane** only (second street): requirements, payouts, property sell-off, teleport to a Suburb-themed copy of the map (palette swap acceptable).
30. Street multipliers live.
31. Golden Auction every 2h, announced lots, Bank-held property priority.
32. VIP gamepass (2× offline, gold nametag).
33. First cosmetics (1–2 house skins, 1 car) and the Robux shop screen.
34. Eviction Night clock (America/New_York) even if testing via a debug force-on.
35. Heist Bid v1 (3–4 friends, villa+ lots, income split).
36. Integrity pair limits + new-account bid cap.
37. Record the first 10 clips (content task, not code). Unique hook and cut each; one account per platform.
38. Analytics dashboard wiring for D1, session length, auction participation (events already firing).

### Milestone M4 — Week 4 launch candidate

39. Streets 3–5 (Downtown, Ocean Drive + Tax Raid, Billionaire Row + top 1% gate + hourly auction queue). Can theme as kit swaps.
40. Private Street gamepass + private server instructions.
41. Remaining cosmetics (cars, helicopters).
42. Full Hall world ticker reliability, shard log.
43. UI polish, settings, reduce motion, text filtering if any custom names.
44. Compliance pass: copy review (no "bet/jackpot"), odds visible, no paid random, ProcessReceipt consolation.
45. Load test auction mutex with 12 bidders; soft-close; server shutdown refund/forgive path.
46. Soft launch / friends-and-family, watch D1 and auction participation, tune Config only.
47. Launch. After launch: weekly content = one new event or one new street prop set, **guided by D2–D7**, not by idea volume.

### Post-launch (do not pull into M1–M4 unless a blocker)

- Replay buffer / better clip camera.
- Notifications for Eviction Night.
- Additional Golden lots and furniture catalog.
- Mobile HUD pass.
- Localized strings (English ships first).

### Suggested Claude work order inside each milestone

1. Config + formulas + types.
2. Server service + tests with fake players / debug commands (`/givecash`, `/forcrent`, `/forcecrash`, `/forceauction`, `/sethouse` — **Studio or admin-only**, gated by a group rank or `RunService:IsStudio()`).
3. Replication + UI.
4. Persistence.
5. Analytics hooks.
6. Playtest and tune.

---

## 23. Debug and live-ops commands

Admin or Studio only:

| Command | Effect |
|---|---|
| `/givecash n` | Add cash |
| `/sethouse n` | Set house level, rebuild model |
| `/giveprop id` | Grant property if slot free |
| `/forcerent` | Run a rent collection now |
| `/forcecrash [seconds]` | Start a crash window |
| `/forceauction user` | Queue a bankruptcy auction as if they missed rent (does not steal cash first unless flagged) |
| `/forcegolden [lotId]` | Start a Golden Auction |
| `/forceeviction on\|off` | Toggle Eviction Night |
| `/forcetax` | Tax Raid now (Ocean Drive) |
| `/resetday` | Clear daily claim / insurance used (Studio only) |
| `/givetitem insurance\|lawyer\|boost` | Grant consumables |
| `/teleportstreet n` | Admin teleport |

Log every admin command.

---

## Appendix A — `Config.lua` reference

Copy, then fill product ids when they exist. Every value is a **starting design value**.

```lua
-- src/shared/Config.lua
-- STARTING DESIGN VALUES, not live data. Tune after playtests.

local Config = {}

Config.SchemaVersion = 1
Config.MaxPlayersPerStreet = 12
Config.PlotCount = 12
Config.MaxInteractDistance = 24
Config.MaxPlotNameLength = 24
Config.AutosaveSeconds = 60
Config.SessionLockTTL = 90
Config.SessionLockHeartbeat = 30

Config.StartingCash = 75
Config.IncomeTickSeconds = 1
Config.SellBackRatio = 0.40
Config.OfflineIncomeCapSeconds = 8 * 3600
Config.VIPOfflineIncomeMultiplier = 2.0

Config.RentIntervalSeconds = 600
Config.RentWarningSeconds = 30
Config.RentToIncomeRatio = 0.35
Config.MinRent = 10

Config.CrashIntervalSeconds = 3600
Config.CrashWindowSeconds = 600
Config.CrashWarningSeconds = 60
Config.CrashRentMultiplier = 3

Config.ComebackIncomeMultiplier = 2.0
Config.ComebackDurationSeconds = 600
Config.FallenTagUntilHouseLevel = 5

Config.RescueWindowSeconds = 10
Config.AuctionDurationSeconds = 60
Config.LawyerPassExtraSeconds = 15
Config.SoftCloseWindowSeconds = 5
Config.SoftCloseExtensionSeconds = 5
Config.MaxSoftCloseExtensions = 3
Config.MinBidRatio = 0.40
Config.MinBidFloor = 25
Config.BidIncrementRatio = 0.05
Config.BidIncrementFloorPerStreet = 50 -- multiplied by streetTier
Config.AssetBindSeconds = 2 * 3600
Config.DeedToCashRatioIfAlreadyHigher = 0.30
Config.AuctionPayoutToBankruptRatio = 0
Config.RescueFeeRatio = 0.10
Config.MaxRescuers = 4
Config.MaxSharePerRescuer = 0.75
Config.MaxRescuesPerPlayerPerUTCDay = 3
Config.MaxRescueActionsPerRescuerPerUTCDay = 8
Config.MinRescuerPresenceSeconds = 120
Config.MaxPairRescueOrWinPerUTCDay = 2
Config.MaxPairRescueOrWinPerUTCWeek = 5
Config.NewAccountMaxBid = 5000
Config.NewAccountAgeDaysForBidCap = 7
Config.AuctionGapSeconds = 5

Config.InsuranceMaxUsePerUTCDay = 1

Config.RebirthIncomeBonusPerRebirth = 0.15
Config.StreetStartHouseLevel = { 1, 3, 4, 5, 6 }
Config.RebirthGrant = { 0, 2000, 15000, 75000, 300000 }
Config.MinPlayersForPercentile = 200
Config.BillionaireRowFallbackLifetimeEarnings = 50000000
Config.RebirthRequirements = {
  -- toStreet = { minHouseLevel, minLifetimeEarnings }
  [2] = { minHouseLevel = 5, minLifetimeEarnings = 25000 },
  [3] = { minHouseLevel = 7, minLifetimeEarnings = 250000 },
  [4] = { minHouseLevel = 8, minLifetimeEarnings = 2000000 },
  [5] = { minHouseLevel = 10, minLifetimeEarnings = 20000000, topPercentile = 0.01 },
}

Config.StreetRentMultiplier = { 1.00, 1.15, 1.35, 1.60, 2.00 }
Config.StreetIncomeMultiplier = { 1.00, 1.10, 1.25, 1.45, 1.75 }

Config.HouseUpgradeCost = { 0, 250, 1000, 4000, 15000, 50000, 200000, 800000, 3000000, 12000000 }
Config.HouseRent = { 0, 5, 15, 40, 100, 250, 800, 2500, 8000, 25000 }
Config.HousePropertySlots = { 1, 1, 2, 2, 3, 3, 4, 5, 6, 8 }
Config.HouseDisplayNames = {
  "Cardboard Box", "Tent", "Trailer", "Studio", "Row House",
  "Townhouse", "Villa", "Penthouse Tower", "Private Island Portal", "Billionaire Estate",
}
Config.HouseIds = {
  "CardboardBox", "Tent", "Trailer", "Studio", "RowHouse",
  "Townhouse", "Villa", "PenthouseTower", "PrivateIslandPortal", "BillionaireEstate",
}

Config.StreetNames = { "Skid Row", "Suburb Lane", "Downtown", "Ocean Drive", "Billionaire Row" }
Config.StreetIds = { "SkidRow", "SuburbLane", "Downtown", "OceanDrive", "BillionaireRow" }

Config.GoldenAuctionIntervalSeconds = 7200
Config.GoldenAuctionDurationSeconds = 60
Config.GoldenAuctionWarningSeconds = 120

Config.EvictionNight = {
  Timezone = "America/New_York",
  Start = { weekday = 6, hour = 20, minute = 0 },  -- Friday 20:00 (weekday: Sunday=1 ... Saturday=7, ISO-like: document in EventClock; use Friday=6 if Sunday=1)
  Stop  = { weekday = 1, hour = 23, minute = 0 },  -- Sunday 23:00
  PrimeSaturday = { startHour = 20, endHour = 22 },
  RentMultiplier = 2.0,
  RewardMultiplier = 2.0,
}

Config.TaxRaidIntervalSeconds = 1800
Config.TaxRaidWarningSeconds = 90
Config.TaxRaidPayWindowSeconds = 90
Config.TaxRaidRentFraction = 0.5

Config.HeistMinMembers = 3
Config.HeistMaxMembers = 4
Config.HeistMinHouseLevel = 7
Config.MaxHeistBidsPerUTCDay = 5

Config.StreakSaveCashPerDayPerStreet = 500
Config.StreakSaveCashCap = 25000
Config.StreakSaveWindowHours = 24
Config.DailyCashDay1PerStreet = 250
Config.RentFreeDurationSeconds = 24 * 3600
Config.AuctionBoostRebateRatio = 0.20
Config.AuctionBoostDurationSeconds = 24 * 3600
Config.Day14FallbackCash = 5000
Config.Day28FallbackCash = 15000
Config.Day5SkinFallbackPerStreet = 500

Config.MysteryDeedOdds = {
  { level = 3, chance = 0.40 },
  { level = 4, chance = 0.30 },
  { level = 5, chance = 0.18 },
  { level = 6, chance = 0.08 },
  { level = 7, chance = 0.04 },
}

Config.LandlordSpinOdds = {
  { id = "cash_small", chance = 0.35 },
  { id = "cash_med", chance = 0.20 },
  { id = "furniture_common", chance = 0.20 },
  { id = "furniture_rare", chance = 0.10 },
  { id = "auction_boost", chance = 0.07 },
  { id = "insurance", chance = 0.05 },
  { id = "stall_street", chance = 0.025 },
  { id = "deed_studio", chance = 0.005 },
}

Config.SpinCashSmallPerStreet = 100
Config.SpinCashMedPerStreet = 400

Config.HallServerBoardSize = 20
Config.HallWorldTickerSize = 10
Config.HallMaxGlobalEntries = 5000
Config.LeaderboardUpdateSeconds = 60

Config.NewAccountClusterAgeDays = 3
Config.RateLimit = {
  Bid = { max = 4, window = 2 },
  Rescue = { max = 2, window = 2 },
  Shop = { max = 2, window = 1 },
}

Config.SuggestedRobux = { -- suggestions only, not data
  CrashInsurance1 = 79,
  CrashInsurance5 = 299,
  LawyerPass1 = 39,
  LawyerPass5 = 129,
  StreakSave = 49,
  VIPLandlord = 399,
  PrivateStreet = 199,
  HouseSkin_NeonSign = 99,
  HouseSkin_MarbleFacade = 199,
  HouseSkin_GoldTrim = 399,
  Car_Beater = 99,
  Car_Sports = 249,
  Car_Limo = 399,
  Heli_News = 349,
  Heli_Gold = 799,
}
Config.StreakSaveIneligibleFallbackCash = 1000

Config.Properties = {
  { id = "stall_street", name = "Street Stall", type = "Stall", cost = 50, incomePerMinute = 8, minHouse = 1, minStreet = 1 },
  { id = "stall_food", name = "Food Cart", type = "Stall", cost = 200, incomePerMinute = 15, minHouse = 2, minStreet = 1 },
  { id = "stall_kiosk", name = "Kiosk", type = "Stall", cost = 600, incomePerMinute = 30, minHouse = 3, minStreet = 1 },
  { id = "shop_corner", name = "Corner Shop", type = "Shop", cost = 2000, incomePerMinute = 60, minHouse = 4, minStreet = 1 },
  { id = "apt_studio", name = "Studio Apartment", type = "Apartment", cost = 5000, incomePerMinute = 80, minHouse = 4, minStreet = 2 },
  { id = "shop_boutique", name = "Boutique", type = "Shop", cost = 8000, incomePerMinute = 120, minHouse = 5, minStreet = 2 },
  { id = "apt_building", name = "Apartment Building", type = "Apartment", cost = 25000, incomePerMinute = 200, minHouse = 6, minStreet = 2 },
  { id = "shop_luxury", name = "Luxury Store", type = "Shop", cost = 30000, incomePerMinute = 250, minHouse = 6, minStreet = 2 },
  { id = "apt_tower", name = "Apartment Tower", type = "Apartment", cost = 120000, incomePerMinute = 500, minHouse = 8, minStreet = 3 },
  { id = "shop_mall", name = "Street Mall", type = "Shop", cost = 400000, incomePerMinute = 800, minHouse = 8, minStreet = 4 },
  { id = "apt_resort", name = "Island Resort", type = "Apartment", cost = 1500000, incomePerMinute = 2000, minHouse = 9, minStreet = 4 },
  { id = "shop_hq", name = "Corporate HQ", type = "Shop", cost = 6000000, incomePerMinute = 5000, minHouse = 10, minStreet = 5 },
}

return Config
```

Weekday convention for `EventClock`: **Sunday = 1, Saturday = 7** (Roblox `os.date("*t").wday`). Friday start is `wday == 6`. Implement timezone conversion properly; do not assume the server is in US Eastern.

---

## Appendix B — Remote contracts

All are **client → server requests** unless marked. Server replicates through a `StatePush` remote or attribute/folders. Payload fields are the allowed client inputs; the server ignores extra keys.

| Name | Direction | Request | Success result (server → caller or broadcast) |
|---|---|---|---|
| `ClaimPlot` | C→S | `{ plotId }` | `{ plotId }` or error `occupied` / `already_has_plot` |
| `UpgradeHouse` | C→S | `{}` | `{ newLevel, cash }` or `cannot_afford` / `max` |
| `BuyProperty` | C→S | `{ propertyId, slotIndex? }` | `{ instance }` or `locked` / `no_slot` / `cannot_afford` |
| `SellProperty` | C→S | `{ instanceId }` | `{ cash }` or `bound` / `need_consent` |
| `PlaceProperty` | C→S | `{ instanceId, slotIndex }` | `{ }` |
| `ApplyDeed` | C→S | `{ deedId }` | `{ newLevel }` |
| `Bid` | C→S | `{ auctionId, amount }` | broadcast `AuctionUpdate` or `too_low` / `cannot_afford` / `closed` / `own_estate` / `new_account_cap` |
| `RescueContribute` | C→S | `{ auctionId, amount }` | broadcast rescue bar or cap errors |
| `UseLawyerPass` | C→S | `{ auctionId }` | `{ endsAt }` or `not_owner` / `none` / `already` |
| `ActivateAuctionBoost` | C→S | `{}` | `{ expiresAt }` |
| `ClaimDaily` | C→S | `{}` | `{ reward, streak, odds? }` |
| `SpinDaily` | C→S | `{}` | `{ prize, odds }` or `already` |
| `StreakSaveCash` | C→S | `{}` | `{ streak }` or `ineligible` / `cannot_afford` |
| `PromptRobux` | C→S | `{ productKey }` | server calls `PromptProductPurchase` / `PromptGamePassPurchase` only after eligibility checks |
| `StartRebirth` | C→S | `{}` | teleport begins or `requirements` |
| `HeistCreate` | C→S | `{ auctionId? }` | `{ partyId }` |
| `HeistInvite` | C→S | `{ partyId, userId }` | `{ }` or `not_friend` |
| `HeistDeposit` | C→S | `{ partyId, amount }` | `{ pool, share }` |
| `HeistLeave` | C→S | `{ partyId }` | refund |
| `EquipCosmetic` | C→S | `{ kind, id }` | `{ }` or `locked_pad` |
| `SetSetting` | C→S | `{ key, value }` | `{ }` |
| `RequestHall` | C→S | `{ cursor? }` | `{ entries, cursor }` |
| `PayTaxRaid` | C→S | `{}` | `{ }` or `cannot_afford` |
| `StatePush` | **S→C** | — | profile public slice, timers, auction DTO, events |
| `WorldPush` | **S→C** (all) | — | plots, hall ticker, event flags, jumbotron |

Error shape: `{ ok = false, code = "cannot_afford", message = "Not enough cash." }`. The `message` is UI-safe and already filtered if it ever includes names.

---

## Appendix C — Formula test cases (starting design values)

Use these as unit checks in `Formulas.spec.lua`.

**Rent, Skid Row, Corner Shop only, Studio house, no events**  
incomePerMinute = 60, HouseRent = 40, streetMult = 1  
raw = 60×10×0.35 + 40 = 250  
rent = 250  

**Same during crash**  
rent = 750  

**Same during Eviction Night + crash**  
rent = 1500  

**Min bid, Studio house step cost 4000 + Corner Shop 2000**  
FairValue = 6000, MinBid = max(25, floor(6000×0.40)) = 2400  

**Increment on a bid of 2400, street 1**  
max(50×1, ceil(2400×0.05)) = max(50, 120) = 120; next bid ≥ 2520  

**RescueCost on overdue 750**  
ceil(750×1.10) = 825  
Max one friend can pay = floor(825×0.75) = 618  

**Offline 8h, income 60/min, no VIP**  
60/60 × 28800 × 1 = 28,800 cash  

**Same with VIP**  
57,600 cash  

**Comeback** does not apply offline.

If a later Config tune breaks these numbers, update the tests to match Config, not the other way around — but change one knob at a time.

---

## Appendix D — Copy and naming

- Game title: **Bankrupt Street**
- Hook: **Everything you own, someone else can buy.**
- Auction gavel line: **SOLD — [Name]'s [House] for $[price].**
- Bankruptcy stinger: **YOU'RE BANKRUPT.** Sub: **2× Comeback for 10 minutes. Take it back.**
- Crash: **MARKET CRASH — rent ×3**
- Eviction + crash: **EVICTION NIGHT + CRASH — rent ×6**
- Do not use: bet, wager, jackpot, loot box, gacha, steal (in official UI verbs).
- Fallen Millionaire is a badge of story, not an insult. Do not add mockery VO.

---

## Appendix E — Asset checklist (for Studio, not a blocker for greybox)

**Must be readable in silhouette:** 10 house tiers, 12 property models (can reuse kitbash), stage + gavel + jumbotron, Hall board, 5 lighting states (default, crash, eviction, tax raid, golden), cardboard-box restart, golden statue (level 10), helicopter and car pads, Comeback VFX, insurance shield VFX, rescue bar.

**Audio (short, original or licensed):** rent tick, crash siren (mild), auction open, bid tick, gavel, rescue complete, upgrade fanfare, bankrupt stinger, comeback loop sting, daily claim, eviction theme.

**UI:** one typeface pair, a red/gold/cream auction palette, big numerals on the jumbotron (readable on mobile recordings).

---

## Appendix F — Glossary

| Term | Meaning |
|---|---|
| Spendable cash | `cash - reservedCash` |
| Fair value | House step cost + property catalog costs |
| Estate lot | The whole bankruptcy package sold as one auction |
| Bank | System holding no-bid assets for later Golden Auctions |
| Street | Server tier via rebirth, not a physical second map requirement (theme swap allowed) |
| Rebirth | One-way climb to the next street |
| Crash window | 10-minute period when rent is ×3 |
| Deed | Token to apply a house level, or cash if already at/above |
| Starting design value | A number to ship and then tune; not a live-ops metric |

---

## Document history

| Version | Notes |
|---|---|
| 1.0 | First implementation-ready GDD for Bankrupt Street. Core loop, streets, events, economy, monetization, moat, compliance, data, remotes, Rojo layout, and M0–M4 build order. |

**End of GDD.** Build M0 → M1, and do not leave the Week 1 slice until the auction is fun.
