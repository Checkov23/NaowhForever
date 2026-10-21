# Utilities

One addon, `NaowhForever_Utilities`, holding six modules. Instance Tracker, Journeys, Macros, Group
Inspect, and Action Bars used to ship as addons of their own. Racial and Class Tracking ships here
from the start. Each keeps its own folder, its own XML, its own settings store and its own switch
under Settings > Modules; only the AddOns list shows one line for all six. It works as
`NaowhForever_Combat` does (its README has the module switches, the AddOns list entry and the old
folders); this file has what differs.

## Layout

```
NaowhForever_Utilities/
  NaowhForever_Utilities.toc   its metadata, and one file line: Utilities.xml
  Utilities.xml                each module's XML, in load order
  InstanceTracker/             Instance Tracker (each module's README has its files)
  Journeys/                    Journeys, with its route icons in Journeys/Media
  Macros/                      Macros
  GroupInspect/                Group Inspect
  ActionBars/                  Action Bars
  TrackingReminder/            Racial and Class Tracking
  README.md                    this file
```

## Why

- Group Inspect needs the BiS List, but this addon does not depend on it, so the other five load for
  a player with the BiS List off. `OptionalDeps` loads `NaowhForever_BiS` first when it is on. When it
  is not loaded, `GroupInspect.lua` returns before making `ns.GroupInspect` and every other Group
  Inspect file returns when there is none, so nothing is made, listened to or hooked. Settings > Modules
  counts a module as loaded only while what it `needs` is loaded too, so Group Inspect turns on through
  the reload prompt, bringing the BiS List with it.
- Journeys' walking maps stay in `NaowhForever_JourneysData`, an addon of their own that Journeys
  loads by name (`C_AddOns.LoadAddOn`) on the first journey, so a player who never plans one never
  loads them.
- This addon loads before `NaowhForever_Combat`, which lists it under `OptionalDeps`, so the
  Consumable Bar finds the Macros module's Smart Macros. Nothing here needs Combat or Quality of Life
  at load.
- An old folder (`NaowhForever_Macros` and the rest) left behind is switched off at login with the
  same line and reload as Combat's, and each module asks whether its old folder is enabled
  (`OLD_COPY`), as Combat's do.
