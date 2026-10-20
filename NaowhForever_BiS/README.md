# BiS List addon

The `NaowhForever_BiS` addon: five modules, each in its own folder with its own XML, README and
Why. The TOC lists only `BiS.xml`, which loads them in this order:

| Module | What it is |
| --- | --- |
| [`NaowhScore/`](NaowhScore/README.md) | one number for a character's gear, yours shared and others' inspected |
| [`StatWeights/`](StatWeights/README.md) | what each stat is worth to your spec, and how much stronger an item makes you |
| [`BiS/`](BiS/README.md) | your best-in-slot lists, their window, where they drop, Drop Alert, Bag Marks |
| [`CharacterPanel/`](CharacterPanel/README.md) | the game's character panel in the BiS List's look |
| [`InspectPanel/`](InspectPanel/README.md) | the game's inspect window in the same look, with a pane for the player inspected |

## Layout

```
NaowhForever_BiS/
  NaowhForever_BiS.toc   its metadata, and one file line: BiS.xml
  BiS.xml                each module's XML, in load order
  NaowhScore/            the Naowh Score, with its own README
  StatWeights/           Stat Weights, with its own README
  BiS/                   the BiS List, with its own README
  CharacterPanel/        the Character Panel, with its own README
  InspectPanel/          the Inspect Panel, with its own README
  README.md              this file
```

## Why

- Under Forever's Gamepad interface style (`ns.GamepadStandDown()`) the Roll Frame Badge stays off:
  the game's roll frames are not hooked, as EllesmereUI's loot roll skin stands down there too.
- The order is layering: the Naowh Score and Stat Weights are read by the BiS List's paperdoll,
  upgrades and enchants; the Character Panel shows the BiS List's stars, upgrades and enchant dots;
  the Inspect Panel reuses the Character Panel's parts.
- A module's on/off default is read from `ns.FEATURES` (`Core/Features.lua`): Stat Weights'
  store is `statWeights`; the others' switches live in the QoL store (`bis`, `bisLootAlert`,
  `naowhScore`, `characterPanel`, `characterPanelSlotMarks`, `inspectPanel`).
