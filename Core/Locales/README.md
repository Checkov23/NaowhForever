# Locales

The player-facing strings, by language. `enUS.lua` is the source catalog: its keys are the
English strings the addon uses, and `true` means the English key is also the displayed value.
The other files translate those keys. These load straight from the TOC, before everything else.

## Layout

```
Core/Locales/
  enUS.lua   the English catalog, and the fallback for every locale
  deDE.lua   German
  ruRU.lua   Russian
```

## Adding a language

1. Copy `deDE.lua` and name the copy with the WoW locale code, such as `frFR.lua` or `ptBR.lua`.
2. Translate the values on the right and keep every key exactly.
3. Add the file to `NaowhForever.toc` with an `AllowLoadTextLocale` condition.

## Why

- Locales stay in the TOC rather than an XML: `AllowLoadTextLocale` is a TOC option, so the
  client loads only the active language's file.
- Use `ns.L("English text")` for new player-facing text. It falls back to the English text when the
  active locale has not translated that key.
- Spell and item logic stays on IDs; Blizzard supplies their localized names.
- A key that would mean two things gets its context in brackets, and `enUS.lua` gives its English
  text: `L["Back (slot)"] = "Back"` keeps the cloak slot apart from the Back button.
- The repository is ASCII only, except the translations: `ruRU.lua` keeps its Cyrillic as UTF-8.
