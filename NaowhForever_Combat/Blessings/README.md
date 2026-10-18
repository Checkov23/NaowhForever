# Blessings

Paladin blessings: a blessing per class, or per player where one needs something else, shared with
the group's other paladins running Naowh Forever, and a bar that casts it. A class button blesses
the next member of that class who needs it; a class's player list blesses one person. Aura and
Righteous Fury buttons sit at the front. The group leader and assistants can set every paladin's
plan, in the Blessings window (`/nfbless`, Assignments on a class button's menu, Open Blessings on
its settings page). Its settings are in the QoL store (`blessings` and the `bless*` keys), on the
Blessings/Settings page, whose preview edits the bar on plain frames, never its secure ones.

## Layout

```
NaowhForever_Combat/Blessings/
  Blessings.xml                every file, in load order, included by Combat.xml
  Blessings.lua                the module table (ns.Blessings, B), your saved plan, the class list
  Data/
    Spells.lua                 the blessings, auras and Righteous Fury, every rank, and plan codes
  Lookup.lua                   the spells by key, code and spell ID, and which ranks you know
  Group.lua                    your group: each member's names, class and GUID, who can plan
  Buffs.lua                    who has which blessing for how long, who is in range, who is next
  Plans.lua                    plans shared with the group's paladins over addon messages
  AutoAssign.lua               Auto-Assign and the saved preset
  View/
    Look.lua                   the bar's look, on the bar and the preview (B.Look)
    Watch.lua                  Blizzard's managed aura display over a button
  UI/
    BlessButton.xml            the template the group headers build their buttons from
    Recipient.lua              a secure button that follows one named player
    Keys.lua                   the Next Blessing and Next Greater Blessing key bindings
    Menus.lua                  the right-click menus
    PlayerList.lua             a class's player list above the bar
    Bar.lua                    the Blessing Bar and its events
    Assignments.lua            the window's grid of every paladin's plan
    SettingsPage.lua           its settings page, declared as cards, with the editable preview
    Window.lua                 the Blessings window
  README.md                    this file
```

## Why

- A bar button's hover and pressed look are the shared flat fills (`Parts.Press`), and the preview's
  buttons hover the same way (`Parts.Hover`).
- `blessLayout` is the bar's Growth Direction, on the Anchor card beside where the bar sits. It keeps its old saved values: `horizontal` grows Right and
  `vertical` grows Down (`ItemBar.GrowOf`), beside the new `LEFT` and `UP`, so no saved profile changes.
- The ranks are lowest first, from Forever's spell data (build 1.60.1.69913).
- Forever names carry a surname: `UnitName` gives only the first name ("Glyadin"), while
  `UnitFullName` and addon message senders give the whole one ("Glyadin Skywolf"). Names are kept as
  senders carry them: the realm only when it is not ours. Another paladin's plan is kept by that
  name (realm when not ours): `{ classes, aura, known }`.
- The saved plan once held only `{ CLASS = blessing }`, before per-player choices and auras; such a
  plan is read into the new shape.
- Unit identity and auras can come back secret in restricted content; those are skipped. A member
  whose data has not arrived yet reads "Unknown" with no class; the next roster or aura update picks
  them up.
- A group header matches its `nameList` against `UnitName` in a party and `GetRaidRosterInfo` in a
  raid, which on Forever can be the first name alone. Every name the header could compare for a
  member is counted once per member (`NAME_SLOTS`); a name two members share (two of them "Bob" to
  the header) is left out for both, so the header cannot pick the wrong one, and the class buttons
  skip them.
- A Greater Blessing reaches the whole class, so it is only cast when everyone in the class is down
  for the same blessing; otherwise the single one, so nobody's own choice is replaced. It uses a
  Symbol of Kings (`SYMBOL_OF_KINGS`), and covers the whole class, so it is cast once.
- A buff's state is present (with the time left when it runs out), missing, or nil when unreadable.
  Aura access can be withdrawn outside combat lockdown too (seen on boss pulls), and
  `GetAuraDataByIndex` then raises instead of returning nil, so the restriction is checked before the
  call. Reads are remembered for one refresh, so every ask in it reads a member's buffs once.
- Range is true, false, or nil when the game gives no answer (left to the cast); a secret answer
  counts as no answer.
- A class button blesses, in order: missing first, then running out (under `EXPIRING`, five
  minutes), then whoever has the least left, skipping anyone dead, offline or out of range. Only a
  member in range the button can reach lights it: red when someone is missing the class blessing,
  yellow when only running out, blue when only players on their own blessing need theirs. With
  Apply Theme to Status Colours they are the theme's Accent, its lighter Accent and a deeper shade.
- A class button's left-click goes to the next member of its queue, so in combat (where the queue is
  the one from before the pull) repeated clicks go through those who needed it, round again after
  the last, as a missed click cannot be told from a cast. The button is its group header's child, and
  the header finds that member by name, wherever the raid has moved them. One the header no longer
  finds (they left) leaves the button without a unit, and a spell with none would go to the current
  target, so they are skipped. Out of combat a click reads the class again first.
- A mouse click acts on release, so the class buttons take up clicks only: one step per click. Addon
  buttons otherwise follow `ActionButtonUseKeyDown` and act only on the press. The key bindings are
  key down only, so a press casts and steps once whatever that setting is.
- The key bindings (Key Bindings > AddOns, `Bindings.xml`) are aimed again on every refresh out of
  combat; in combat, where buffs cannot be read, each steps through the list it had when the fight
  began, one press per entry: the single blessing for everyone due, and a Greater one per class whose
  members all share its blessing, cast on the most urgent of them.
- The secure group header owns its button's unit, so the button follows one named player through
  raid reordering, even in combat. Headers only build their button while visible, so the parent must
  be shown when one is made. The secure class button hides while nobody can be blessed; the menu
  still opens from the icon.
- Secure buttons only change out of combat; a change asked for in one waits. So does one asked for
  while auras are unreadable: every buff would read unknown and the class buttons would lose their
  spell, then stay empty once combat locks them. The bar is only built out of combat (a reload in
  one builds it once the fight ends), and cannot be dragged in combat.
- Blizzard's managed aura display draws a buff's presence and time left, in combat too, without addon
  code reading secret aura data. The frame under it stays red, so only a missing buff shows red.
  Forever may not ship the display, so it is optional. Its button sits over the button's own icon, so
  the black border still shows; not with `PixelInset`, since a Blizzard aura button's `IsVisible` is
  secret and refitting it raises. When the header points a player-list button at another unit mid
  fight, the display follows.
- A plan travels as ten characters: a blessing code per class in `CLASSES` order, then the aura's,
  "-" for none. Salvation travels beside it, so an older client still reads the plan: `s` in the list of
  what a paladin knows, `Y` in the same list when they give it, and `V|name|1` or `V|name|0` when a leader
  or assistant sets it for them. An older client's class Salvation (an `s` in the plan, or in a player's
  choice) reads as Salvation given. Per-player choices travel as GUID=code pairs in batches; "P|1|" starts the list over,
  so an empty one clears what the others had, and at most `MAX_PLAYER_CHOICES` are kept per paladin.
- Messages are parsed as data: only valid codes from a paladin in the group are kept, and only the
  leader or an assistant can set someone else's plan. Nothing is sent in combat: what would have
  been is kept, the latest per kind and target, and sent once combat ends. Every client asks on a
  roster change, so answers are batched into one send a second later.
- Auras and the roster change constantly in a raid: one rescan a second at most, and one exchange of
  plans per second. Except right after your own cast: the bar shows the blessing landing on the next
  frame, so a click is not answered by a second of the old red; that window stays open for a second,
  at most one rescan a frame, since in a group other auras change first and a Greater Blessing's class
  can land over more than one frame. `UNIT_AURA` fires for every unit the client tracks; a queued
  rescan already covers it, and in combat a refresh would only mark the bar dirty, so both skip the
  unit test. Range and time left change with nothing to announce them, so the bar rescans every
  `TICK` seconds out of combat.
- Auto-Assign: each class's blessings, most wanted first. Salvation is not one of them: it stacks with the
  class blessing, so it is a switch on the paladin's plan (`salv`), given to everyone but tanks. The first
  paladin in the order below who knows it gets it, once for the group. Whoever knows least picks first, so a
  paladin with few blessings is not left with none, and each wanted
  blessing goes to the first paladin still free who knows it; one aura each. Another paladin's plan
  is kept here until their broadcast confirms it, and sent to them; planning everyone's needs the
  leader or an assistant when another paladin is involved.
- Salvation is its own cell on the bar, after the class buttons, shown while you give it (Give Salvation in a
  class button's menu, the Salvation row of the settings card, or its column in the Blessings window). It is for
  every member whose assigned role is not Tank; a secret role counts as not a tank, and `PLAYER_ROLES_ASSIGNED`
  rescans. A class with a tank in it is blessed one player at a time. A class with no tank gets one Greater
  Salvation when two or more of it need it and a Symbol of Kings is carried, a single one otherwise, so the
  reagent is not spent on one player. The cell's queue is every class's, most urgent first, trimmed like a class
  button's: those due, or the one with least left. The key bindings step through the same list.
- Salvation used to be one of the five class blessings. A saved plan with it for a class or a player is read
  once into "Salvation on" with that class or player cleared (`salvSplit`), and one turned off stays off.
- The preset is one saved set of plans for the account, by paladin name. Loading it plans only the
  paladins in it who are here now, each keeping to what they have learned.
- A class label too long for its slot under the bar (the button plus the gap after it) first shrinks,
  down to `LABEL_MIN`, then drops to its first three letters at that size, and is cut off if even
  that is too long, so neighbours never run into each other. Letters are counted in whole UTF-8
  characters, so a localized name never splits. Nothing sits beside a column's names, so only a row's
  are fitted. The class icon (Class Label Style: Class Icon) is two thirds of the button, kept between
  `CLASS_ICON_MIN` and `CLASS_ICON_MAX`, and made the first time it is asked for.
- The bar holds its first button, so a class joining or leaving never shifts the buttons already
  there. Its place is saved by the edge Growth Direction grows from (`blessPos` LEFT, RIGHT, BOTTOM or
  TOP of the bar, from the screen centre); a spot the HUD Editor saves by its centre, or one saved
  before, is turned into that edge once the bar has its size. That rewrite of `blessPos` is one way:
  the old centre is not kept, and the bar sits where it did. Changing Growth Direction keeps the bar
  where it is.
- The bar starts above Buff Reminders (AuraBuffs), held there by the HUD Editor's own Anchor, so it
  follows Buff Reminders, shows on the HUD Editor's tag, and lets go like any other element. It is
  tied to their centre, not their edge: Buff Reminders grows both ways as reminders come and go, and
  the bar's buttons must not slide under the cursor while blessing. The first button sits over
  that centre; growing down it sits under Buff Reminders instead, so it never grows into them. Each
  profile is anchored once (`blessDocked`), only if the bar was never moved there, so a spot or an
  anchor the player chose stays. Without AuraBuffs the anchor is kept and waits: the HUD Editor
  applies it once the Buff Reminders mover is made, and until then the bar sits where it last was, or
  above the action bars (`HOME_Y`) the first time. Reset Position anchors it again.
- Anchor to a Unit Frame is the shared item bar anchor (`blessAnchor` and the rest of the `bless`
  anchor keys); the bar then grows from the point picked there.

## Checking

- `lua Tools/regression/test-blessing-autoassign.lua`: Auto-Assign's plans.
- `lua Tools/regression/test-blessing-names.lua`: the names a group header can find each member by.
- `lua Tools/regression/test-blessing-range.lua`: what lights a class button, and its click queue.
- `lua Tools/regression/test-blessing-preview.lua`: the settings preview and its edits.
- `lua Tools/regression/test-import-safety.lua`: another paladin's per-player choices are capped.
- `lua Tools/regression/test-combat-perf.lua`: a bar refresh reads each member's buffs once.
