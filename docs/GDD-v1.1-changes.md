# Bankrupt Street — GDD v1.1 changes

These override `docs/GDD.md` (v1.0) where they conflict. Everything else in v1.0 still applies.
All numbers are **starting design values** and live in `src/shared/Config.luau`.

## 1. No dodging rent by leaving (fixes a core-loop exploit)

v1.0 only charges rent to online players, while offline income is risk-free. Optimal play was "leave during the crash warning."

- If a player leaves during a crash warning or crash window, rent for that tick is **charged on leave** at the crash rate (`ChargeRentOnLeaveDuringCrash`). If they cannot pay, the estate goes to auction **in absentia** on the next stage slot.
- Offline income is paid at `OfflineIncomeRate = 0.5` of the online rate (VIP still ×2 on top, same 8h cap). Being online should earn more than being away.

## 2. Something on stage every ~5 minutes

v1.0 has one crash per hour; most 15–40 minute sessions would never see an auction.

- `RentIntervalSeconds = 300`, `CrashIntervalSeconds = 1200`, `CrashWindowSeconds = 300` (exactly one rent tick per crash). Rent per tick is still `income × cycleMinutes × 0.35`, so the rent-to-income balance is unchanged.
- **Bank Foreclosure lots:** if the stage has been idle for `BankForeclosureIdleSeconds = 300`, the Bank auctions an NPC estate sized to the street's median wealth. Same auction machine, no rescue window.

## 3. Works with 1–3 players

- `MaxPlayersPerStreet = 8`, `PlotCount = 8` (fills faster; still a crowd on stage).
- **NPC bidders** join auctions while fewer than `NpcBidders.MaxRealPlayers` real players are present. They bid up to a random 45–85% of fair value, so real players usually win if they want it. NPCs never rescue and never bid on Golden Auctions.

## 4. Faster first 15 minutes, softer bankruptcy

- `StartingCash = 150`. House 1–5 costs `{0, 150, 600, 2500, 10000}`. Slots `{2, 3, 3, 4, 4, 5, 5, 6, 7, 8}`.
  Target: 3–4 purchases in the first 15 minutes, first crash survived-or-not around minute 20.
- Bankruptcy drops the house by `BankruptcyHouseLevelDrop = 3` levels (minimum Cardboard Box), not straight to level 1. Properties are still lost. Comeback Boost stays ×2 but lasts `ComebackDurationSeconds = 900`.
- **Rent-safety warning:** any purchase that would leave spendable cash below the next projected rent shows "You won't be able to pay rent in M:SS" with Confirm / Cancel.

## 5. Launch scope

Launch = M0 + M1 + M2 + **two streets** (Skid Row, Suburb Lane).
Moved to post-launch: Heist Bid, Tax Raid, Billionaire Row top-1% gate, Private Street.

## 6. Tech

- Prefer the ProfileStore library for player data if it is added via Wally; until then `ProfileManager` implements the v1.0 §17.2 session lock itself.
- Eviction Night is 51 hours long; keep it, but call it **Eviction Weekend** in UI copy.
- v1.0 §4.1 and §11.3 reference deed rules as "Section 7.6"; they are in §7.7.

## 7. Clips and accounts

- Multiple TikTok/Shorts accounts are fine **if each posts its own original edits**. Never repost the same video across accounts, and no bought views/followers — platforms detect duplicate content and suppress or ban the whole network.
- No alt Roblox accounts to fill servers, bid, or rescue. It breaks the integrity rules in v1.0 §15 and risks moderation of the experience.
