# Combat

One addon, `NaowhForever_Combat`, holding eight modules, seven of which used to ship as addons of their own:
Consumable Bar, Gear & Trinkets, Blessings, AuraBuffs, Threat Meter, PvP, Swing Timer and Raid Debuffs. Each keeps its
own folder, its own XML, its own settings store and its own switch under Settings > Modules; only the
AddOns list shows one line for all eight.

## Layout

```
NaowhForever_Combat/
  NaowhForever_Combat.toc   its metadata, and one file line: Combat.xml
  Combat.xml                each module's XML, in load order
  ConsumableBar/            Consumable Bar (each module's README has its files)
  GearSets/                 Gear & Trinkets
  Blessings/                Blessings
  AuraBuffs/                AuraBuffs, with its campfire art in AuraBuffs/Media
  ThreatMeter/              Threat Meter
  PvP/                      PvP
  SwingTimer/               Swing Timer
  RaidDebuffs/              Raid Debuffs
  README.md                 this file
```

## Why

- Each module's entry in `MODULES` (`Core/Options/Modules.lua`) keeps its old addon name as its
  `addon` and names this addon as its `host`. The old name is still the module's id in the
  per-character module list, the presets' `modulesOff` and shared profiles, so none of them change.
- A module here is on when this addon is enabled and its switch is on. The core keeps this addon
  enabled for a character while any of the eight is switched on and disables it once none is
  (`ns.SetModuleState`, `ns.ReconcileModules`, the onboarding's Apply), so a player with all eight off
  loads none of them.
- Switching one of the eight on or off while this addon is loaded takes effect at once, with no
  reload: each checks its own switch before it registers an event, hooks or builds a frame, and
  stops when it goes off. One that is off costs only its loaded code and a few idle frames.
- This addon loads after `NaowhForever_Utilities` (`OptionalDeps`), so the Consumable Bar finds the
  Macros module's Smart Macros, and before Quality of Life, which lists this addon under its own
  `OptionalDeps` so the Food & Drink Bar's card finds the Consumable Bar.
- An old folder (`NaowhForever_GearSets` and the rest) left behind is switched off at login
  (`RETIRED_ADDONS` in `Core/Core.lua`), with a reload offered when it loaded. In that one session
  the old addon has the module: each module asks once, as it loads, whether its old folder is
  enabled (`OLD_COPY` on its table), and while it is, its switch reads off and its card files
  declare nothing, since a second card with the same id stops the copy that declares it. Some old
  folders load before this addon and some after, so it is the enable state that is asked, not
  whether it has loaded yet. It is asked for all characters: a folder enabled only on another
  character costs that module for one session.
