# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

The real surface is the World of Warcraft Forever in-game UI (Lua frames, textures and FontStrings), not a browser. `web` is the nearest value the schema allows; apply web guidance as design principles only.

## Users

Inferred from the repo, not yet confirmed: WoW Forever players, from new levellers to raiders, who want Naowh's guidance and quality-of-life tools inside the game. Many arrive through the NaowhUI installer on Forever.

## Product Purpose

NaowhForever is "Naowh's companion addon for World of Warcraft Forever": a standalone multi-module suite in one window. Every module starts off; players turn on only what they want, and anything left off costs nothing.

## Positioning

Naowh's own knowledge of Forever, as BiS lists, stat weights, a dungeon journal, a training planner, profession and gear help, inside the game in one window instead of spread across websites and separate addons.

## Operating Context

- Main window `/nf` (also `/naowh`, `/nao`). Per-module commands: `/nfbis`, `/nfjournal`, `/nfquests`, `/nftraining`, `/nfgear`, `/nfbless`, `/nfmacros`, `/nfbars`, `/nfbuffs`, `/nfthreat`, `/nfgroup`, `/nfpvp`. Also `/nf setup` (onboarding), `/nf quiz`, `/nfaim`, `/copy`.
- Game Menu (Esc) button, Bindings.xml keybinds, an Unlock/HUD editor and a Top Bar.
- Reskins RestedXP guides when present.
- The NaowhUI installer imports its profile through `NaowhForever_API.ImportProfile` and passes supporter badge claims.
- Released by a one-click Actions workflow; changelog lines come from PR descriptions; merges to main ship on the next release.

## Capabilities and Constraints

- Modules: BiS List, Stat Weights, Dungeon Journal, Discovery, Training Planner, Professions, Gear, Blessings, Macros, Action Bars, Buffs & Reminders, Threat, Group Inspect, PvP, Swing Timer, Druid Mana, Raid Debuffs, QoL (including Top Bar), Supporter Badges. Each ships as a `NaowhForever_<Module>` folder.
- Forever only (Interface 16001). No retail branches; uses classic-era spell IDs.
- Steps aside when the gamepad interface style is on ("Not available with the Gamepad interface style").
- No dependency on EllesmereUI; NaowhUI_Media is optional.
- Localized: full English catalog plus deDE, esES, esMX, frFR, itIT, koKR, ptBR, ruRU, zhCN, zhTW in `NaowhForever_Locales`. Strings are ASCII only.

## Brand Commitments

- Title `|cff0091edNaowh|r Forever`.
- Gold and bronze "Forever" palette with 1px black edges; Naowh Blue #0091ED marks the main action (`Shared/Style.lua`, CONTRIBUTING "Style").
- Text uses the Naowh font through `ns.Font`.
- Voice: plain, direct, second person. "Every module starts off. Turn on only what you want; anything you leave off costs nothing."

## Evidence on Hand

- README, CONTRIBUTING and `Shared/Style.lua` for the house style.
- No user counts, testimonials or press in this repo; do not fabricate them.

## Product Principles

1. Off until chosen: nothing runs or shows until the player turns it on.
2. One window: every module lives in the same shell and style.
3. Naowh's knowledge, in game: answers the player would otherwise look up.
4. Stand aside cleanly: when another interface (gamepad) owns the screen, step back rather than fight it.

## Accessibility & Inclusion

No formal standard. Signals: keybindings, full localization, gamepad stand-down. No colourblind mode found.
