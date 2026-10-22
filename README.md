<div align="center">

<img src=".github/assets/logo.png" width="140" alt="Naowh Forever logo">

# Naowh Forever

**Naowh's companion addon for World of Warcraft Forever**

Your BiS list, a dungeon journal, professions, a training planner, gear swaps
and a lot of quality of life, all in one window.

[![Discord](https://img.shields.io/badge/Discord-Join-5865f2?style=for-the-badge&logo=discord&logoColor=white&labelColor=0b1a24)](https://discord.gg/naowh)
[![naowh.gg](https://img.shields.io/badge/naowh.gg-Website-c8a46a?style=for-the-badge&labelColor=0b1a24)](https://naowh.gg/)
[![Download](https://img.shields.io/badge/Download-Releases-36c5d8?style=for-the-badge&logo=github&logoColor=white&labelColor=0b1a24)](https://github.com/naowh-gaming/NaowhForever/releases)
[![WoW Forever](https://img.shields.io/badge/WoW-Forever-1f7fe0?style=for-the-badge&logo=battledotnet&logoColor=white&labelColor=0b1a24)](https://www.wowhead.com/forever)

[Install](#install) &nbsp;|&nbsp; [What's inside](#whats-inside) &nbsp;|&nbsp; [Commands](#commands) &nbsp;|&nbsp; [Changelog](CHANGELOG.md) &nbsp;|&nbsp; [Contributing](.github/CONTRIBUTING.md)

</div>

---

## What's inside

| Module | What it does |
| --- | --- |
| **BiS List** | Your best-in-slot list in its own window: your gear on a paperdoll, every pick per slot ranked with stars, where each drops and where to run next. Marked on tooltips and called out when it drops. Open it with its own key too. |
| **Stat Weights** | What each stat is worth to your spec, with your own changes: a line on gear tooltips ("Fire: +9% upgrade" and what it is weighed against), and the BiS List's upgrades and enchants. On BiS List's Stat Weights tab. |
| **Dungeon Journal** | Every dungeon on Forever, the new ones included, and the raids: its bosses in order and what they drop, your BiS marked, your quests there with what to do first, a tip from Naowh for each boss and how many times you have killed it. A map of each classic dungeon with every boss on it, and in a dungeon the world map (M) shows it, with the Journal beside it. Open it with its own key too. |
| **Discovery** | Library books to find around Azeroth and who to hand them to, and the Cozy Sleeping Bag's chain step by step. Its Quest List tab has every quest of every zone for your character, your progress per zone, and every quest chain with the step you are on; its Rares tab every rare of every zone on the map, with an alert when you see one. Open the Quest List with `/nfquests`. |
| **Training Planner** | What you can train now, what each level brings and what it costs, with the way to your nearest trainer. |
| **Professions** | Recipes, reagents and crafting in one window, including the recipes you have not learned yet. |
| **Gear & Trinkets** | Swap equipment sets from a bar, or automatically while you ride or rest. |
| **Blessings** | Paladin blessings by class and player, shared with your group's paladins. |
| **Macros** | Class, consumable and focus macros, written and kept up to date for you. |
| **Action Bars** | Your action bars saved by name and put back whenever you want them. |
| **Buffs & Reminders** | Buff, consumable and campfire reminders, and a low health warning. |
| **Threat Meter** | Threat on your target for the whole group, and a warning before you pull. |
| **Group Inspect** | Everyone in your party or raid in one window: their Naowh Score, item level, gear, talents and stats, and who runs Naowh Forever. Also on a party or raid member's right-click menu. |
| **PvP** | What your target is doing in a fight: their short buffs and the crowd control on them, and battleground displays. |
| **Swing Timer** | Your swings from the game's own timer, with marks for timing around them. |
| **Raid Debuffs** | The raid debuffs you pick on your target, Sunder Armor to the warlock curses, with the missing ones easy to spot, in combat too. |
| **Quality of Life** | Questing, loot and bag space, alerts, casting, tooltips, trainer ranks, flight and camp, mail and more, and the Top Bar: friends, guild, the clock and your addon buttons across the top of the screen. |
| **Supporter Badges** | The Naowh Forever N next to the name of Naowh, the devs, the mods and our Legendary and Epic patrons. See [Supporter badges](#supporter-badges). |

> [!TIP]
> Every module starts **off**. Turn on only what you want; anything you leave off costs
> nothing, not even a registered event. Supporter badges are the exception: they start on so
> everyone sees them, and each part can be turned off.

Settings live in **Profiles**, so you can switch between them, copy them to another
character or share them with a friend.

## Install

1. Download the newest `NaowhForever-<version>.zip` from
   [Releases](https://github.com/naowh-gaming/NaowhForever/releases).
2. Extract it into your Forever `Interface\AddOns` folder, so that you end up with
   `Interface\AddOns\NaowhForever\NaowhForever.toc` and each module's
   `Interface\AddOns\NaowhForever_<Module>` folder beside it.
3. Log in, or type `/reload` if you are already in game, then open it with `/nf`.

## Commands

| Command | Opens |
| --- | --- |
| `/nf` | The main window (also `/naowh` and `/nao`) |
| `/nfbis` | Your BiS list |
| `/nfjournal` | Dungeon Journal (also `/nfdj`) |
| `/nfquests` | Quest List: your quests and rares per zone, and quest chains (`/nfcompleto` too) |
| `/nfdiscovery` | Discovery |
| `/nftraining` | Training Planner |
| `/nfgear` | Gear Sets |
| `/nfbless` | Blessings |
| `/nfmacros` | Macros |
| `/nfbars` | Action Bars |
| `/nf ab <name>` | Imports a saved action bar set; `/nf ab` alone lists them |
| `/nfbuffs` | Buffs & Reminders |
| `/nfthreat` | Threat Meter |
| `/nfgroup` | Group Inspect (also `/nf group`) |
| `/nfpvp` | PvP |
| `/nf setup` | The onboarding, to pick your profile, skin and modules again |
| `/nf quiz` | A WoW quiz for flights and campfires |
| `/nfaim` | The Aim Trainer |
| `/nf junk` | Your Junk List (Junk Marker, QoL > Loot & Items); `/nf scrap` still works |
| `/nf shopping` | Your Shopping List window (Professions > Shopping List) |
| `/copy` | The text under your mouse, ready to copy (turn on Global Copy in QoL > Interface) |
| `/nf badges id` | Your badge code, for all your characters (see [Supporter badges](#supporter-badges)) |

You can also open the window from the addon compartment next to the minimap.

## Supporter badges

Naowh, the developers, the moderators and the Legendary and Epic patrons on Naowh's Patreon get the
Naowh Forever N next to their name in chat. Hover the name for their card. If you turn it
on, a banner also shows when they join your group.

Everyone with Naowh Forever sees them. You can turn each part off in **QoL > Interface >
Supporter Badges**: chat badges, the hover card and the tooltip line start on, the group
banner starts off, and there's an option to skip the banner for your own guild.

| Badge | Who |
| --- | --- |
| Founder (gold) | Naowh |
| Developer (blue) | The people building Naowh Forever |
| Moderator (red) | The people keeping the community running |
| Legendary Patron (orange) | Legendary tier on Naowh's Patreon |
| Epic Patron (purple) | Epic tier on Naowh's Patreon |

### Getting your badge

The badge is tied to your characters, not your name, so we need their IDs. You only do this
once.

1. Log into every character you want the badge on, once. The addon remembers them.
2. Type `/nf badges id`. A box opens with one code for all of them, like
   `90:Player-4613-006EB819,Player-4613-00ABCDEF`.
3. Press **Ctrl+C** to copy it.
4. Send it:
   - **Legendary and Epic patrons:** send it in a support request on
     [Discord](https://discord.com/invite/naowh) to be added.
   - **Developers and moderators:** send it to Dieman or Glyalith.

Your badge shows up with the next release. Made a new alt? Log into it, run `/nf badges id`
again and send the new code.

**Don't have the addon yet?** This line prints the same code for the character you're on:

```
/run print(GetCurrentRegion()..":"..UnitGUID("player"))
```

Run it on each character. To send several at once, keep the number before the `:` once and
join the rest with commas: `90:Player-4613-006EB819,Player-4613-00ABCDEF`. The first time,
the game may ask you to allow scripts.

The code only has your region and your characters' IDs. No names, nothing else.

### Adding staff (maintainers)

Staff are in `Core/Badges/Staff.lua`, by region and then character ID. The
number before the `:` in the code is the region. Forever has its own region numbers, not
retail's 1 to 5, so always copy it from the code. For `90:Player-4613-006EB819`:

```lua
[90] = {
    ["Player-4613-006EB819"] = { tier = "developer", title = "Lead Developer" },
},
```

Tiers are `naowh`, `developer` and `moderator`; `title` is optional. Add one line per
character in the code. Don't edit `Core/Badges/Patrons.lua`: the patron sync
writes it. Staff can check a badge with
`/nf badges preview [naowh|developer|moderator|legendary|epic]` and `/nf badges toast`.

## Contributing

Bug fixes and ideas are welcome. Read the [contributing guide](.github/CONTRIBUTING.md)
before you start: it has the rules every change is reviewed against, how to set up the
checks, and how commits and pull requests are named. All UI is built from the shared
components in [`Shared/`](Shared/README.md): use them, extend them, or add a new one there,
never a copy inside a module. For anything bigger than a fix,
message Glyalith on [Discord](https://discord.gg/naowh) first.

By submitting a contribution you confirm it is your own work, or that you have the right
to submit it, and you take responsibility for it: nothing may be copied from another
addon, site or tool against its license or terms. See
[Your responsibility for what you submit](.github/CONTRIBUTING.md#your-responsibility-for-what-you-submit).

## Releasing a new version

For maintainers. A release is one click:

1. Check that everything for the release is merged into `main`. On an up-to-date `main`,
   `GH_REPO=naowh-gaming/NaowhForever python Tools/release/release.py pending` (needs `gh`) prints
   `## Unreleased` as the release will write it, with the `## Changelog` lines from the
   merged PRs' descriptions; fix a line by editing that PR's description.
2. Open **Actions > Release > Run workflow** and keep the branch on `main`.
3. Pick the **Bump** and click **Run workflow**:

   | Bump | From `1.0.6` |
   | --- | --- |
   | patch (default) | `1.0.7` |
   | minor | `1.1.0` |
   | major | `2.0.0` |

   **Version** takes an exact version instead, for anything the bumps can't express.

The workflow then:

- adds the merged PRs' changelog lines to `## Unreleased` and renames it to the version,
  sets every TOC's `## Version` (the core's and each module addon's) and `ns.CODE_BUILD`,
  and pushes that as `chore(release): <version>` to `main`;
- tags the commit, and the tag starts a second Release run that builds the zip,
  publishes the GitHub release with the player notes and every commit since the last
  tag, uploads to CurseForge, and posts the notes to Discord;
- puts an empty `## Unreleased` back at the top of the changelog on `main`.

The push uses the `RELEASE_DEPLOY_KEY` secret: a deploy key with write access, on Protect
main's bypass list. Without it, `main` rejects the release commit and nothing is published.

It stops before changing anything if there is nothing for `## Unreleased`, it is not the
newest section, a merged PR's changelog line does not start with `Added:`, `Changed:` or
`Fixed:` (the error names the PR), the tag already exists, or the version is not like
`1.0.7`. Pushing a tag by hand still releases, but only with what `CHANGELOG.md`
already says: the PRs' lines are added by the workflow.

### On a schedule

- **Every day at 15:30 UTC**, after the US realms' daily reset, the same release runs by itself,
  as a patch. On a day with nothing for players since the last release, its one changelog line
  is the day's Daily Word (`Changed: Daily Word #N is out`). A release whose notes are only that
  line uploads to CurseForge and GitHub but posts nothing to Discord or the website; a day with
  changes for players releases them as usual, with the Discord post.
- **Every night at 22:00 UTC** a beta: main's version is stamped on a commit of its own and
  tagged `<next>-beta.<n>` (after `1.0.6`: `1.0.7-beta.1`, `1.0.7-beta.2`, ...). That commit is
  never pushed to `main`. CurseForge publishes it on the beta channel, and the GitHub release's
  notes are `## Unreleased` as `pending` prints it. Betas post nothing to Discord, and a night
  with nothing new on `main` since the last release or beta tags nothing.
- **Run workflow** with **beta** ticked tags tonight's beta at once.

Betas never move the release's number: the next release counts from the newest version
without a suffix.

## License

Copyright 2026 the Naowh Forever authors, all rights reserved. The bundled libraries keep
their own licenses, listed in [LICENSE.md](LICENSE.md).
