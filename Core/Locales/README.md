# Locales

The player-facing strings, by language. `enUS.lua` is the source catalog: its keys are the
English strings the addon uses, and `true` means the English key is also the displayed value.
The other languages live in one load-on-demand addon, `NaowhForever_Locales`, which loads only
when the language in use is not English.

## Layout

```
Core/Locales/
  enUS.lua   the English catalog, and the fallback for every locale
NaowhForever_Locales/        load on demand, one addon for every language
  NaowhForever_Locales.toc   lists every <code>.lua
  deDE.lua    the strings
  esES.lua  esMX.lua  frFR.lua  itIT.lua  koKR.lua  ptBR.lua  ruRU.lua  zhCN.lua  zhTW.lua
```

## Adding a language

1. Copy `NaowhForever_Locales/deDE.lua` to `<code>.lua` and change `deDE` to `<code>` in its
   header comment and in the `NaowhForever.LOCALE` check on its second line.
2. Translate the values on the right and keep every key exactly.
3. List `<code>.lua` in `NaowhForever_Locales.toc`, and add the code and its name to `LANGUAGES`
   and `LANGUAGE_NAMES` in `Core/Core.lua`.

## Why

- The language is the one picked in Settings (Language), else the client's. Core.lua picks it before
  any file reads a string, because most files translate their strings once, as they load. The pick
  is saved for this computer, in `NaowhForeverDB.account.language`, and `NaowhForever.toc` has
  `## LoadSavedVariablesFirst: 1`, so the game loads `NaowhForeverDB` before the addon's first
  file and Core.lua can read it there (`ns.LANGUAGE_PICK`). The Forever client's own addons use the
  same TOC line. A new pick needs a /reload.
- The pick used to live in its own always-loaded addon, `NaowhForever_Language`
  (`NaowhForeverLanguageDB`), because without that TOC line the saved variables load after the
  files. An old folder left behind loads after Naowh Forever now; at login its pick is copied into
  `account.language` when none is saved yet, and the folder is retired with a reload offered, so
  that pick is in use after the reload. Where the update removed the folder, its saved file is no
  longer read and the language starts from the client's again.
- The languages are one load-on-demand addon whose TOC lists every language file; Core.lua loads it
  with a single `LoadAddOn`, and only when the language is not English, so an English client parses
  none of it (EllesmereUI's locales addon works the same way). Every file in the TOC runs, but each
  starts with a `NaowhForever.LOCALE` check and returns at once unless it is the language in use, so
  only that catalog is built. Each file is about 600 KB of source, and ten of them are compiled
  whenever the player is not on English; that cost is accepted, as EllesmereUI accepts it. They used
  to be one addon per language, which put ten entries in the AddOn list.
- Korean and Chinese text needs the game's own fonts (`ns.LocaleFont`): no font the addon ships
  or offers has those characters, so every font path turns into the language's. Naowh covers
  Cyrillic; only Friz Quadrata (the Forever skin's font) swaps to its Cyrillic cut for Russian.
  `ns.LocaleFont` takes the font's requested name as well as its resolved path, and keys the
  Russian swap off the name (`FONT_CLASSIC`), not the resolved path: LibSharedMedia controls that
  path, not this addon, so matching the request is the stable half of the comparison.
- Use `ns.L("English text")` for new player-facing text. It falls back to the English text when the
  active locale has not translated that key.
- `Core.lua` keeps only the catalog's entries that are not `true` (the bracketed keys) and drops
  the global: a `true` entry says the key is its own text, which `ns.L` falls back to anyway, and
  holding every one of them cost each player over half a megabyte.
- Spell and item logic stays on IDs; Blizzard supplies their localized names.
- The shared parts translate what they show: settings rows, cards, groups and footers, tooltips,
  dialogs, title bars, tabs, links, section titles, notes and the HUD Editor's element names.
  Modules hand them the English text, which stays the key for saved data, caches, cog menus and
  the search index; the search also indexes the shown words, so both languages find a row.
- `ns.Upper` and `ns.Lower` change the case of accented letters too (Lua's own are byte-wise and
  leave "ü" as it is), and `ns.Upper` writes "ß" as "SS".
- A key that would mean two things gets its context in brackets, and `enUS.lua` gives its English
  text: `L["Back (slot)"] = "Back"` keeps the cloak slot apart from the Back button.
- The repository is ASCII only, except the translations, which are UTF-8.
