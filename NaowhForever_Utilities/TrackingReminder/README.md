# Tracking Reminder

A row of icons for the racial and class tracking you know but have not turned on. Click an icon to start that tracking. Players see it as Racial and Class Tracking. Its settings card is on Quality of Life > Interface (`QoL/Interface`), and its switches and defaults come from `ns.FEATURES.trackingReminder`.

## Layout

```
NaowhForever_Utilities/TrackingReminder/
  TrackingReminder.xml                every file, in load order
  TrackingReminder.lua                the settings and the module table (ns.TrackingReminder)
  Data/
    Spells.lua                        racial and class tracking spell IDs (TR.Data)
  UI/
    Reminder.lua                      the HUD row of secure icons and its mover (TR.Look)
    SettingsPage.lua                  the settings page, declared as cards, with a preview
  README.md                           this file
```

## Why

- Forever can track more than one thing at once, so each missing racial or class tracking gets its own icon. A hunter has eight, and three mouse buttons cannot cast them all.
- Each icon is a secure button. Its spell is set out of combat, and the row hides when combat starts, so combat never changes a secure attribute.
- The card sits on Quality of Life > Interface but keeps its own `trackingReminder` store and its module switch under Settings > Modules, so saved settings carry over. It has no sidebar page (`tabs = {}`).
- The buttons are built on first enable, and tracking events are registered only while the feature is on.
- Racial and class tracking start on, and a pick with no saved value is on. Turning the module on reminds you of every tracking you know, until you turn that spell off.
- The spell IDs are Forever's classic-era IDs: Find Treasure, the hunter tracks, Druid Track Humanoids, Sense Undead, and Sense Demons.
- Druid Track Humanoids only works in Cat Form, so its icon shows only in Cat Form, and shapeshift events are watched only once a druid knows it.
- The row homes at 260, 170 so it sits above the Professions gather icon at 260, 120, without reading that addon.
- A minimap slot is turned on with SetTracking, so Unlock Mode cannot toggle it off. A spell with no slot is cast from the secure button, and the icon clears once that aura is on the player. While auras are secret, the last aura state read is kept.
- GetTrackingInfo is read as a table or as the older tuple.
