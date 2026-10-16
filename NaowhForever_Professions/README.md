# Professions

Naowh's profession window in place of the game's: your recipes by category with the ones you
have not learned below them, the chosen recipe in the middle (reagents, profit, craft buttons, or
where to learn it), Blizzard's own profession tabs on its edge, and an overview card for each
profession. Around it: craft orders from another player's link, buying reagents on the auction
house or at a merchant, a shopping list, your favourite recipes at the trainer and the auction
house, a next-rank alert, a batch craft timer and a tracking reminder. Laid out like the
[Dungeon Journal](../NaowhForever_DungeonJournal/README.md), on [`Shared/`](../Shared/README.md).

## Layout

```
NaowhForever_Professions/
  NaowhForever_Professions.toc   metadata, and Professions.xml
  Professions.xml      every file, in load order
  Professions.lua      settings (ns.ProfessionSettings), the module table (ns.Professions, P) and
                       the window's shared state (P.State)
  Constants.lua        the numbers several files share: AH timeouts, the craft cap, coins, NPC rows (P.C)
  Data/
    RecipeData.lua     where each recipe, rank and trainer is (ns.RecipeData), by hand from Wowhead Forever;
                       each recipe's yellow and grey skill from Tools/build/skill_thresholds.py
    VendorReagents.lua the reagents trade-goods vendors sell (P.VendorReagents)
    CooldownRecipes.lua the classic recipes on a cooldown (P.CooldownRecipes)
    ConsumableItems.lua the consumables the Shopping List offers, the stats each is for, each class's stats
                       (P.ConsumableItems)
  Text.lua             money and colour codes as text (P.Text)
  LinkView.lua         another player's profession opened from a trade link, and when it ends (P.Links)
  Recipes.lua          the open profession, reagents, what a recipe makes, bag counts (P.Recipes, ns.ProfWindowAPI)
  Vendors.lua          vendor reagents and prices learned at merchants, buying there (P.Vendors)
  Prices.lua           buy prices, a craft's value, profit and return on investment (P.Prices)
  Favorites.lua        favourite recipes (P.Favorites, ns.ProfFavorites)
  RecipeFinder.lua     the unlearned recipes, what they need and where they come from (ns.RecipeFinder)
  RankAlert.lua        a profession ready for its next rank, in the window and once in chat (ns.ProfessionRank)
  Auctions.lua         your active auction quantities, kept per character (P.Auctions)
  Filters.lua          the Filter menu's rules (P.Filters)
  Entries.lua          what the recipe list holds, by category and group (P.Entries)
  Orders.lua           craft orders: value, tip, messages, sending (P.Orders)
  AuctionHouse.lua     the auction house open, searching it, Shift-click (P.AH)
  BagRoom.lua          how many crafts the bags have room for (ns.CraftBagRoom)
  ShoppingPlan.lua     the shopping list's store (crafts and other items) and make-or-buy plan (P.Shopping)
  Consumables.lua      the consumables that suit you, by class, mana and level, the best marked (P.Consumables)
  CraftQueue.lua       queued crafts, prerequisites, missing materials and click-driven execution (P.CraftQueue)
  Patterns.lua         favourites at a trainer, and their patterns to buy (P.Patterns, ns.TrainerServiceInfo)
  Disenchant.lua       the bag items Disenchant can take, the ones you keep, the next one (P.Disenchant)
  View/
    Style.lua          the module's own look, over Shared/Style.lua (P.Style)
    Widgets.lua        flat checkbox, skill bar, star, count box, Search AH button (P.Widgets)
    Popup.lua          the small window beside the trainer or the auction house (P.Popup)
  UI/
    SkillThresholds.lua the optional difficulty line beneath a selected recipe (P.SkillThresholds)
    RecipeList.lua     the recipe list and its scrollbar (P.List)
    Reagents.lua       a recipe's reagent rows (P.Reagents)
    ProfitLines.lua    lined-up amounts and the crafting profit (P.Lines)
    Buyer.lua          Buy on AH's box (P.Buyer)
    BuyRow.lua         the Buy and Buy All row under the reagents (P.BuyRow)
    OrderPanel.lua     the order controls and the order column (P.OrderPanel)
    Detail.lua         the middle column for one of your recipes (P.Detail)
    Learn.lua          the middle column for an unlearned recipe (P.Learn)
    Book.lua           the overview's profession cards (P.Book)
    Window.lua         the window: frame, title, skill bar, rank banner, search, Filter, drawing (P.Window)
    Takeover.lua       showing it over Blizzard's window, docking Blizzard's tabs and cards, dragging, events
    ShoppingAdd.lua    Add to List under a recipe, and the button that opens the shopping list
    ShoppingWindow.lua the Shopping List window: crafts, other items, materials (ns.ToggleShoppingList)
    ShoppingConsumables.lua the Consumables picker beside the Shopping List: search and favourites
    ShoppingVendor.lua Shopping List materials sold by the open merchant, with Buy and Buy All
    ShoppingList.lua   the shopping list beside the auction house: check and buy
    CraftQueue.lua     the standalone Crafting Queue window (ns.ToggleCraftQueue)
    TrainFavorites.lua Train Favorites beside the trainer
    FavoritePatterns.lua Search Favorites AH beside the auction house
    CraftTimer.lua     Total Craft Timer
    GatherTracking.lua the Tracking Reminder
    Disenchant.lua     the Disenchant window and its button on the Enchanting window (ns.ToggleDisenchant)
    SettingsPage.lua   its settings page (Professions/Settings), declared as cards
```

Each layer uses only the ones above it, or reads a later one's table at call time.

## Why

- Skill-up Thresholds is off by default. It creates its line only when an enabled recipe pane first
  needs it. Selection and skill updates use the existing redraw path; this feature adds no events,
  hooks, timers, route planning or polling.
- Each recipe's `yellow` and `grey` in `RecipeData.lua` are written by `Tools/build/skill_thresholds.py`
  from the game's own `SkillLineAbility` table (`TrivialSkillLineRankLow` and `TrivialSkillLineRankHigh`),
  through `Tools/sources/wago.py` with the build's hotfixes. They sit on the recipe entries that already
  exist rather than in a table of their own, which cost about 165 KB at login and 415 KB more once used;
  on the entries they add about 55 KB. Rerun the tool when `wago.BUILD` changes or recipes are added: it
  rewrites only those two fields. Only crafting skill lines and recipe categories are read;
  contradictory ranges and conflicting duplicate spell rows are left out.
- Orange starts at the skill the recipe is learned at (`skill`), not the table's `MinSkillLineRank`,
  which is 1 for nearly every recipe. A recipe learned past its yellow is yellow from the start, so
  yellow and green are at least the learn skill. Green is the rounded-down midpoint of yellow and grey.
  A positive live `maxTrivialLevel` replaces the bundled grey, and green is recalculated with it.
  A grey at or below yellow or the learn skill draws no line. These are difficulty ranges, not
  measured skill-up probabilities. The recipe name's colour still comes from the game's
  `relativeDifficulty`.
- The line is drawn below the icon, with the description and reagents beneath it. Its current-skill
  marker adds the profession's `skillModifier`. Linked professions have no marker or range: their
  recipes belong to someone else, not the current character.
- The on/off switches' defaults (`enabled` and each feature's switch) are read from
  `ns.FEATURES.professions`; their options keep their own defaults in `Professions.lua`.
- Blizzard's window stays open under ours at zero alpha: hiding it would close the trade skill (its
  OnHide calls CloseTradeSkill) and take the recipe data with it. Ours sits one strata higher, so
  nothing of Blizzard's can be clicked, and is never narrower or shorter than it.
- Blizzard's profession tabs switch profession by casting its spell, which only Blizzard's code may
  do, so the real tabs move onto our window's edge and ignore their invisible parent's alpha.
- The overview's spell buttons (Smelting, Find Minerals) cast and the red cross unlearns, so they stay
  Blizzard's. A card draws its buttons as part of itself, so Blizzard's whole card moves into ours with
  its art at zero alpha; the buttons stay children of that card, where their click reads the
  spellbook offset. They are secure: docked out of combat only, and undocked whenever the overview
  is not showing.
- Blizzard only makes a tab for a profession you have learned, so an unlearned one has none. The docked
  tabs get a Naowh-blue outline so they stand out on the dark window. The Unlearn button beside a skill
  bar is drawn from the atlas `Profession-button-red-crossmark` at 20px and full strength; where that
  atlas is missing it falls back to the red cross of `ReadyCheck-NotReady`, or the button shows nothing.
- With the overview docked our window holds secure buttons and is protected, so closing it in combat
  makes it transparent instead of hiding it. Resizing waits for combat to end for the same reason.
- Once dragged, Blizzard's window is moved to where ours was put, out of combat only (it holds secure
  buttons); anchoring it to ours instead would make ours protected. The panel manager places it
  again whenever any panel opens or closes, so its SetPoint is hooked. EllesmereUI's Shifter puts
  ProfessionsFrame back at its own saved spot on every SetPoint, so with the Shifter on that saved
  spot is written too.
- A trade link reads `trade:<crafter GUID>:<spell>:<skill line>`; only a plain click opens it. Opened
  from a closed window, a link does not always read as linked yet, so the click is remembered. A
  link clicked while Blizzard's window is loaded but closed makes Forever cast every one of your
  professions and land on the last, so it is clicked once more after `RETRY_AFTER` (0.5s). The view
  ends when the window closes, but not on the close the click itself causes (`SETTLE`, 1s), or when
  you cast one of your own professions. Mining's window opens with Smelting (2656), not a spell
  named after the profession.
- Forever answers `numAvailable` with 0, so how many you can make is worked out from the reagents.
- The recipe schematic is the current API; the reagent-info calls are kept as a fallback. A recipe's
  reagents and output never change, so each is read once and shared read-only; only a schematic that
  loaded and makes nothing is final.
- An item whose name is not loaded is asked for, and ITEM_DATA_LOAD_RESULT for one asked for redraws
  the window once. Other item loads (the auction house loads hundreds) redraw nothing.
- Shift-click links through ChatFrameUtil: the ChatEdit_ names are deprecated shims Forever does not
  load. The active chat window alone does not say you are typing: with some chat settings there
  always is one, so its focus is checked.
- Difficulty colours are Enum.TradeskillRelativeDifficulty: 0 Optimal, 1 Medium, 2 Easy, 3 Trivial
  (no more skill).
- The skill bar's dark end is 55% of a changed accent; the shipped blue (#004f85) stays otherwise.
- The list is wide enough for a recipe name, its count and a full profit ("-12g 07s 09c"). Counts sit
  in a right-aligned column as wide as the widest on screen, so every icon and name starts in line,
  never left of `ICON_X` (24), which keeps recipes indented under their headers.
- Recipe Availability Marks are opt-in. Their Shopping List and bag icons are built only when the
  switch is on; bag totals are read from bag slots so equipped gear is never counted as bag stock.
  The list redraws on a Shopping List change only while the window is open: `/nf shopping` can
  change the list before the recipe window was ever built.
- Your Auctions is opt-in. It reads the owner list only while the auction house is open, keeps the
  latest active item quantities under the character's name and realm, as the Shopping List does, and
  builds row markers only when needed. It asks for the owner list on opening the auction house and
  after a post, but not after a cancel: the Auctions tab already asks again then, with the player's
  sort, and its OWNED_AUCTIONS_UPDATED is read like any other.
  Not Selling stays unavailable until the auction house has supplied the first complete owner list.
- The rank banner pushes both columns down 46 while it shows. Filter is 76 wide for "Filter (3)".
  The Buy, Add to List and Create rows share one width, so they line up; the reagent rows end 4
  short of Create, hence the Buy row's 4 overhang.
- Bind on Equip also counts items that never bind (bindType 0): on the beta much crafted gear does not
  bind and still sells on the auction house.
- Favourites are kept per character by spell ID, which is also a known recipe's recipeID. A known one
  is told to the game too, so Blizzard's own favourites count; an unlearned one lives in the account
  store under that character's name and realm. Each character starts from the former profile-wide
  list the first time it loads, and that list stays in the profile for the others. Favourites and the
  crafting queue are empty and unsaved while the game still names the player Unknown; once it names
  them, the name and realm key is kept, as the favourite filter asks for it once per recipe.
- Prices: a reagent costs its vendor price once a merchant was seen selling it, else the lowest buyout
  at the last scan; the auction house keeps 5% of a sale. Profit is cached per recipe until the next
  full draw, so scrolling and the filter do not price every recipe again. Reagents unchecked in the
  pane are ones you have, left out of every recipe's cost.
- ROI is profit divided by the materials' cost. It starts off and shows only under the selected
  recipe's profit, losses in red: the list rows have no room for it beside a full profit. Grey below
  10% and green from 30% leave the middle band yellow; both thresholds are player settings.
- Merchants teach the vendor reagents: trade goods sold for gold without a stock limit are kept
  account-wide, with their price when Crafting Profit is on. Merchant events are registered only
  while the module and one of Crafts with Vendor Buys, Crafting Profit or Buy at Vendor are on.
- Buying only runs from a click: each auction house step is a button, and Confirm is the only one
  that spends gold. A search waits 5s for an answer, a purchase 15s (it settles slower); a purchase
  answering after its timeout still went through. A live price 25% over the last scan is warned
  about. Skip and Cancel are off while a purchase pays, or it would be spent but not counted.
- At a merchant only plain gold purchases are bought, never extended costs; items sold several to a
  purchase round up to whole purchases, and limited stock caps the amount.
- Walking up to an anvil changes whether a recipe's requirements are met: SPELL_UPDATE_USABLE is
  listened to only while the window shows, and redraws the pane at most twice a second.
- Craft orders are kept per crafter until sent or a reload, up to 9 crafts. Messages go 0.4s apart so
  chat does not throttle them, split at 255 characters with item links counted in full. The tip is
  at least 1s, rounded to the silver under 1g, to 10s under 10g, else to the gold. The crafter is
  matched in your group by the link's GUID, else by name without your realm; the order goes to party
  (or instance) chat when they are in your party, else by whisper, also in a raid.
- Forever's GetProfessions answers prof1, prof2, First Aid, Fishing, Cooking; the overview runs
  Cooking, Fishing, First Aid, as Blizzard's book does.
- Profession trainers on Forever ask less than Wowhead lists, so what a trainer window asks is kept
  account-wide, matched by name within its profession (the service list has no spell IDs).
- Forever's GetTrainerServiceInfo returns its values in another order than documented (the third is
  the icon's file ID, seen 2026-09-30), so the kind is whichever value is one of its words and the
  icon the first number over 1000. A trainer's services can arrive a moment after it opens with no
  event, so Train Favorites looks again at 0.2, 0.6 and 1.5s. Learning goes from the last index first:
  buying a service can renumber the ones after it.
- A pattern bought waits in the mailbox, where the game cannot be asked, so it stays off the list for
  30 days (how long auction mail keeps) unless it turns up in your bags or bank first. Patterns are
  single listings; their live prices are looked up one at a time, 0.3s apart, so the auction house's
  limit on searches is never hit.
- Manual Favorite Scans starts off. When enabled, Favorite Patterns sends no searches until Scan is
  clicked, Pause stops after the current auction reply, and Resume continues the same queue. Completed
  pages omit patterns with no buyout while the mouse wheel and pager reach every remaining pattern.
  A search with no reply in 3s is put back for Resume, and a scan that ends with any unanswered
  stays on Resume rather than done. Lookup timeouts keep their own counter, so a reset cannot hand a
  new search the number of a pending timeout.
- Starting a commodity purchase is protected (ADDON_ACTION_BLOCKED when tried on its own, seen
  2026-09-30), so the shopping list buys each material after the first on a click of Buy Next. A
  final price 10% over the check is warned about. A search sent while the auction house is busy is
  dropped, so the check waits for it to be ready.
- The shopping list is a window of its own, not a column of the profession window, so it stays open when
  that closes. Other items (`profShopItems`, item ID to amount, per character like the crafts) are always
  bought as they are, never made from parts; what was bought counts against them. Shift-click, a drag
  from the bags, an ID or an exact name adds one; the window is built on first open and listens to bag
  changes only while it shows.
- The Crafting Queue starts off and creates no frames or hooks until first use. Adding a recipe queues its
  cheaper prerequisites before the final craft and puts its missing auction-house materials on the
  Shopping List. Start Queue only selects the next ready entry, and each Craft Next hardware click starts
  one batch because Blizzard does not allow automated profession opening or unattended crafting. The
  window stays open when the profession window closes.
- The queue's Shopping List demand is derived: every finished craft and bag change during a run re-syncs
  it, so a crafted queue leaves nothing behind. A row's +/- on the Shopping List changes only your own
  count on top of the queue's, and X takes the row off, the queued craft included. The next entry is
  selected only when its own profession is open; otherwise the open profession keeps its selection and
  the queue waits on Open First. The `ns.Apply` hook acts only when the queue turns on or off.
- The Consumables picker offers the Well Fed food, flasks, elixirs and stat scrolls of Naowh's consumables
  list (the one in his profile, from Wowhead Forever), the Buff Reminders' weapon stones and oils, the
  healing and mana potions in `Shared/Game/Consumables.lua` and the Smart Macros' bandages. Plain food and
  drink come from vendors, so they are not on it. The stones, oils and bandages are read from those modules
  when they are loaded. `WEAPON_ITEMS` and `BANDAGES` here are a copy used only while the Buff Reminders or
  the Smart Macros addon is off, so those groups still show; keep them in step with
  `NaowhForever_Combat/AuraBuffs/Data/BuffReminders.lua` and `NaowhForever_Utilities/Macros/Data/Items.lua`. Only the oils'
  stats are kept here (`WEAPON_STATS`); every other weapon item is for attack power.
- What suits your class is `CLASS_STATS`: warriors strength, agility and attack power; rogues agility and
  attack power; hunters those and intellect; mages and warlocks intellect, spirit and spell power; priests
  those and healing; paladins, shamans and druids all of them, since the client does not say which talents
  they took. An item tagged only with stats you do not want is left out, one tagged `mana` shows when you
  use mana (`ns.UsesMana`), and one with no tag (stamina, armor, health, resistances, healing potions,
  bandages) is for everyone. An item with two stats (Elixir of Ferocity) counts in the line of each stat
  you use, so its tier is weighed against your other items of that stat.
- The picker shows what you can use now and the next tier up of each kind and stat, by the level the game
  gives each item. Their data is asked for when it first opens (`Items.OnLoaded`); an item not loaded yet
  waits. The highest you can use of each kind and stat is Best, even its lowest tier; a line with only one
  level in it (a single item, or bandages, which need First Aid instead) has none. Only for my class off
  shows everything; the choice is kept account-wide (`profShopAllConsumables`), like the window's size.
- A pick's amount is its amount on the list, as an other item, so Check Prices and Buy All at the auction
  house buy it. Its box takes as many digits as `C.MAX_ITEMS` has. The picker is built on first open and
  listens to bag changes and level ups only while it shows. The plan tells it of every list change
  (`Shopping.OnChange`); changes and bag updates redraw at most once a frame and only rewrite the rows'
  amounts and counts, while opening, a level up, the toggle and items loading pick the rows again.
- A starred pick is a favourite: it moves out of its kind into Favorites at the top, in kind order.
  Favourites are kept in the profile by item ID (`shopFavorites`), unlike the per-character recipe
  favourites. Only what the picker
  offers can show there, so a favourite the class filter or your level leaves out stays hidden until it is
  offered again.
- The search box above the list keeps the rows whose name holds what is typed, any case. Typing and a star
  only lay out the rows already picked again, with no new pick; reopening the picker clears the search.
- The Shopping List's Consumables button keeps its label only while the title, the subtitle and the whole
  button fit side by side, measured when the window shows and as it is resized, so a longer translation
  drops the label at a width where English keeps it. Without it the button is the square `Parts.BarIcon`
  makes, as wide as it is tall. The empty-list message spans the list's current width, not the window's
  starting one.
- The shopping list makes a material from its parts, up to 4 levels down, only when whole crafts cost
  less than buying what is needed, and never from a recipe with a cooldown (it makes a few a day; a
  shared cooldown can read 0 on the spell). What was bought counts at every level, and a craft taken
  off takes its purchases along. Every craft fires TRADE_SKILL_LIST_UPDATE, so the recipes known are
  recorded again only when they changed, 0.5s after the list settles.
- Vendor Items on Shopping List is opt-in so the list stays as it was for everyone else: off, vendor
  reagents are left off the list as before. On, missing vendor items from recipes and manually added
  items stay in the Shopping List. They go to Buy from Vendor unless the last auction scan and a known
  vendor price show the auction house is strictly cheaper; only auction-routed materials reach Check
  Prices and Buy All at the auction house. An unknown vendor price stays on the vendor side until that
  merchant is seen.
- When an open merchant sells a vendor-routed Shopping List material, a compact window appears beside it.
  It is built only while the setting is on and a matching merchant is open. Buying remains click-driven;
  merchant stack sizes and limited stock are respected, and the close button dismisses it until another
  merchant opens.
- BuyMerchantItem gives no result, and a merchant can refuse a purchase (full bags, sold out), so a vendor
  purchase counts on the Shopping List only once it lands: the bag count at the click is kept, and each
  BAG_UPDATE_DELAYED counts what arrived, up to what was bought. Buy and Buy All wait until it lands or
  the game shows an error; a purchase still on its way when the merchant closes is not counted, and stays
  on the list. With no free bag slot nothing is bought.
- Herbalism and Skinning have no recipes: their ranks are Mining's (same skill and cost) and their
  trainers come from the town map data. A rank needs level 10, 20 and 35 for caps 150, 225 and 300
  unless its data says otherwise.
- The Tracking Reminder is a secure spell button, since casting is Blizzard-only. It cannot show, hide
  or change spell in combat: it hides on PLAYER_REGEN_DISABLED, the last moment InCombatLockdown is
  still false, and catches up when combat ends. The minimap's tracking info is read as a table or as
  values, since which one Forever returns was not pinned down.
- The Total Craft Timer takes the Flight Timer's measures and spot, as nobody crafts in flight. The
  player cast bars (EllesmereUI's and Blizzard's) stay at zero alpha for the batch, since their own
  code shows them on every cast. Show Normal Cast Bar in the Total Craft Timer card keeps them
  alongside the timer instead, restoring their original alpha immediately if enabled during a batch.
  It defaults off and adds no events, frames or hooks. Forever may report a cast time of 0 until it
  is cast, so 3s stands in. Pressing Create mid-craft fails that press while the batch casts on, so
  that failure is ignored. A batch with no craft event 5s past its expected end has stopped. Its
  hooks are installed the first time it is switched on and stay, idle while it is off.
- Bag room is played out craft by craft on what the bags hold: the item onto a stack with room, else
  a free slot that can take it; the reagents out, smallest stack first (seen in game 2026-09-30), each
  emptied stack freeing its slot. A profession bag takes only its kind, the reagent bag only reagents.
- RecipeData's NPC rows are `{ npcID, name, faction ("A", "H", "AH" or "-"), uiMapID, x, y [, cost] }`
  (`P.C.NPC_*`); `t` lists are indices into the profession's trainers. Drops are `{ mob, areaID,
  minLevel, maxLevel, chance }`. Costs are copper. Stormwind and Eastern Plaguelands rows were moved
  to Forever's redrawn maps.
- VendorReagents are flux, thread, vials, salt and spices, water and milk, rods, coal, wood, stocks,
  bleach and dyes. CooldownRecipes are Transmute: Arcanite (2 days), the other transmutes but Elemental
  Fire (1 day, shared) and Mooncloth (4 days).
- Disenchanting casts a spell on an item, which only a click may do, so Disenchant All is a secure
  button armed with Disenchant (13262) and the next item's bag and slot: one item per click. The
  secure template only uses that slot while the spell waits for an item target, so a click that does
  not start the spell never equips the item. The button is armed again after each bag update.
- An item the spell will not take leaves the cursor targeting after the click; PostClick stops that
  and skips the item until a reload. Moving or another cast in progress are expected to fail without
  leaving the cursor targeting, so they skip nothing (not yet seen in game).
- The window holds that secure button and so is protected: it opens out of combat only, and closes on
  PLAYER_REGEN_DISABLED, the last moment it still may.
- Disenchant takes Uncommon to Epic weapons and armor; shirts and tabards never. The skill an item
  needs is left to the game (the refused-item skip), not a table: Forever's may differ from classic's.
- Right-click keeps one copy, by its item GUID (`profDisenchantKeepCopy`), which stays the same when it
  moves between bags; Shift-right-click keeps every copy, by item ID
  (`profDisenchantKeep`). Both are account-wide. A copy's GUID is not removed once it is gone; each is
  one short string. Without C_Item.GetItemGUID, right-click keeps every copy.
- Enchanting's profession ID is 333; the window's Disenchant button shows for your own Enchanting only.

## Checking

- `luacheck NaowhForever_Professions` from the repo root.
- `lua Tools/regression/test-professions-memory.lua` loads every file Professions.xml lists against
  stubs and times and weighs what runs while the window is open.
- The window's slices: `test-profession-combat-close.lua`, `test-profession-window-drag.lua`
  (Takeover.lua), `test-profession-link-view.lua` (LinkView.lua), `test-profession-shift-click.lua`
  (AuctionHouse.lua), `test-profession-merchant-events.lua` (Vendors.lua),
  `test-shopping-list-plan.lua` (ShoppingPlan.lua), `test-profession-craft-queue.lua` (CraftQueue.lua),
  `test-shopping-consumables.lua` (Consumables.lua),
  and the looks in `test-icon-look.lua` and
  `test-qol-bars-look.lua`.
- Vendor Shopping List routing and purchases: `test-profession-shopping-vendor.lua`.
