"""Build PvP Auras' spell lists from the game's own spell tables (Tools/sources/wago.py).

Forever's classic spells carry none of the aura flags Blizzard's filters use (CROWD_CONTROL,
BIG_DEFENSIVE, ...), so PvP Auras picks debuffs on an enemy by spell ID, the one way the
AuraContainer lets an addon choose them. Two lists, one switch per entry in the PvP module's
settings:

- crowd control: each class ability (and racials and engineering items) that takes control
  away, every rank and the NPC and item versions of the same spell; then every other spell
  that applies a crowd control aura (creatures, PvE), as one more switch.
- debuffs: common PvP debuffs that are not crowd control (Mortal Strike, Wound Poison, ...).

An entry is found by its spell name, or by spell ID where Forever's name is too plain to match
on ("Silenced"); names are matched here only, the addon reads IDs. Every entry must find at
least one spell, or the build stops: a renamed spell is caught here, not in game.

Writes NaowhForever_Combat/PvP/Data/Spells.lua.

Usage: python Tools/build/pvp_auras.py
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402
import wago  # noqa: E402

ROOT = paths.ROOT
OUT = ROOT / "NaowhForever_Combat" / "PvP" / "Data" / "Spells.lua"

# SpellEffect.EffectAura values that take control away: possess, confuse, charm, fear, stun,
# root, silence, pacify and silence, disarm.
CROWD_CONTROL_AURAS = {2, 5, 6, 7, 12, 26, 27, 60, 67}

# (key, group, label, names or spell IDs)
CROWD_CONTROL = [
    ("chargeStun", "Warrior", "Charge Stun", ["Charge Stun"]),
    ("interceptStun", "Warrior", "Intercept Stun", ["Intercept Stun"]),
    ("intimidatingShout", "Warrior", "Intimidating Shout", ["Intimidating Shout"]),
    ("concussionBlow", "Warrior", "Concussion Blow", ["Concussion Blow"]),
    ("disarm", "Warrior", "Disarm", ["Disarm"]),
    ("improvedHamstring", "Warrior", "Improved Hamstring", ["Improved Hamstring"]),
    ("shieldBashSilence", "Warrior", "Shield Bash Silence", [18498]),
    ("hammerOfJustice", "Paladin", "Hammer of Justice", ["Hammer of Justice"]),
    ("repentance", "Paladin", "Repentance", ["Repentance"]),
    ("freezingTrap", "Hunter", "Freezing Trap", ["Freezing Trap"]),
    ("scatterShot", "Hunter", "Scatter Shot", ["Scatter Shot"]),
    ("wyvernSting", "Hunter", "Wyvern Sting", ["Wyvern Sting"]),
    ("intimidation", "Hunter", "Intimidation", ["Intimidation"]),
    ("improvedConcussiveShot", "Hunter", "Improved Concussive Shot", ["Improved Concussive Shot"]),
    ("entrapment", "Hunter", "Entrapment", ["Entrapment"]),
    ("counterattack", "Hunter", "Counterattack", ["Counterattack"]),
    ("scareBeast", "Hunter", "Scare Beast", ["Scare Beast"]),
    ("sap", "Rogue", "Sap", ["Sap"]),
    ("gouge", "Rogue", "Gouge", ["Gouge"]),
    ("blind", "Rogue", "Blind", ["Blind"]),
    ("kidneyShot", "Rogue", "Kidney Shot", ["Kidney Shot"]),
    ("cheapShot", "Rogue", "Cheap Shot", ["Cheap Shot"]),
    ("kickSilence", "Rogue", "Kick Silence", ["Silenced - Kick"]),
    ("riposte", "Rogue", "Riposte", ["Riposte"]),
    ("psychicScream", "Priest", "Psychic Scream", ["Psychic Scream"]),
    ("mindControl", "Priest", "Mind Control", ["Mind Control"]),
    ("silence", "Priest", "Silence", ["Silence"]),
    ("blackout", "Priest", "Blackout", ["Blackout"]),
    ("polymorph", "Mage", "Polymorph", ["Polymorph", "Polymorph: Cow"]),
    ("frostNova", "Mage", "Frost Nova", ["Frost Nova"]),
    ("counterspellSilence", "Mage", "Counterspell Silence", ["Counterspell - Silenced"]),
    ("impact", "Mage", "Impact", ["Impact"]),
    ("frostbite", "Mage", "Frostbite", ["Frostbite"]),
    ("fear", "Warlock", "Fear", ["Fear"]),
    ("howlOfTerror", "Warlock", "Howl of Terror", ["Howl of Terror"]),
    ("deathCoil", "Warlock", "Death Coil", ["Death Coil"]),
    ("seduction", "Warlock", "Seduction", ["Seduction"]),
    ("spellLock", "Warlock", "Spell Lock", ["Spell Lock"]),
    ("entanglingRoots", "Druid", "Entangling Roots", ["Entangling Roots"]),
    ("hibernate", "Druid", "Hibernate", ["Hibernate"]),
    ("bash", "Druid", "Bash", ["Bash"]),
    ("pounce", "Druid", "Pounce", ["Pounce"]),
    ("feralCharge", "Druid", "Feral Charge", ["Feral Charge"]),
    ("starfireStun", "Druid", "Starfire Stun", ["Starfire Stun"]),
    ("warStomp", "Racials & Items", "War Stomp", ["War Stomp"]),
    ("tidalCharm", "Racials & Items", "Tidal Charm", ["Tidal Charm"]),
    ("netOMatic", "Racials & Items", "Net-o-Matic", ["Net-o-Matic"]),
    ("recklessCharge", "Racials & Items", "Reckless Charge", ["Reckless Charge"]),
    ("grenades", "Racials & Items", "Grenades & Bombs", ["Iron Grenade", "Thorium Grenade", "Big Iron Bomb",
                                                        "Hi-Explosive Bomb", "Mithril Frag Bomb", "Dark Iron Bomb",
                                                        "The Big One"]),
    ("flashBomb", "Racials & Items", "Flash Bomb", ["Flash Bomb"]),
    ("arcaneBomb", "Racials & Items", "Arcane Bomb", ["Arcane Bomb"]),
    ("mindControlCap", "Racials & Items", "Gnomish Mind Control Cap", ["Gnomish Mind Control Cap"]),
]

DEBUFFS = [
    ("mortalStrike", "Warrior", "Mortal Strike", ["Mortal Strike"]),
    ("hamstring", "Warrior", "Hamstring", ["Hamstring"]),
    ("piercingHowl", "Warrior", "Piercing Howl", ["Piercing Howl"]),
    ("judgementOfJustice", "Paladin", "Judgement of Justice", ["Judgement of Justice"]),
    ("concussiveShot", "Hunter", "Concussive Shot", ["Concussive Shot"]),
    ("wingClip", "Hunter", "Wing Clip", ["Wing Clip"]),
    ("viperSting", "Hunter", "Viper Sting", ["Viper Sting"]),
    ("scorpidSting", "Hunter", "Scorpid Sting", ["Scorpid Sting"]),
    ("huntersMark", "Hunter", "Hunter's Mark", ["Hunter's Mark"]),
    ("woundPoison", "Rogue", "Wound Poison", ["Wound Poison"]),
    ("cripplingPoison", "Rogue", "Crippling Poison", ["Crippling Poison"]),
    ("mindNumbingPoison", "Rogue", "Mind-numbing Poison", ["Mind-numbing Poison"]),
    ("shadowWordPain", "Priest", "Shadow Word: Pain", ["Shadow Word: Pain"]),
    ("mindFlay", "Priest", "Mind Flay", ["Mind Flay"]),
    ("frostShock", "Shaman", "Frost Shock", ["Frost Shock"]),
    ("earthbind", "Shaman", "Earthbind", ["Earthbind"]),
    ("frostbolt", "Mage", "Frostbolt", ["Frostbolt"]),
    ("coneOfCold", "Mage", "Cone of Cold", ["Cone of Cold"]),
    ("curseOfTongues", "Warlock", "Curse of Tongues", ["Curse of Tongues"]),
    ("curseOfExhaustion", "Warlock", "Curse of Exhaustion", ["Curse of Exhaustion"]),
    ("corruption", "Warlock", "Corruption", ["Corruption"]),
    ("faerieFire", "Druid", "Faerie Fire", ["Faerie Fire"]),
]
PER_LINE = 12


def auras_by_spell(effects):
    out = {}
    for row in effects:
        out.setdefault(int(row["SpellID"]), set()).add(int(row["EffectAura"] or 0))
    return out


def resolve(entries, names, auras, wanted):
    """Each entry as (key, group, label, ids): the spells with its names (or its IDs) that
    apply an aura wanted accepts. Stops the build on an entry that finds none."""
    by_name = {}
    for spell, name in names.items():
        by_name.setdefault(name, []).append(spell)
    out, missing = [], []
    for key, group, label, spells in entries:
        candidates = [s for s in spells if isinstance(s, int)]
        for name in (s for s in spells if isinstance(s, str)):
            candidates += by_name.get(name, [])
        ids = sorted({s for s in candidates if wanted(auras.get(s, set()))})
        if not ids:
            missing.append(label)
            continue
        out.append((key, group, label, ids))
    if missing:
        sys.exit("no spell found for: " + ", ".join(missing) + " (renamed in this build?)")
    return out


def lua_ids(ids, indent):
    lines = []
    for i in range(0, len(ids), PER_LINE):
        lines.append(indent + " ".join(f"[{spell}] = true," for spell in ids[i:i + PER_LINE]))
    return lines


def lua_entries(entries, icons):
    lines = []
    for key, group, label, ids in entries:
        icon = next((icons[s] for s in ids if icons.get(s)), 134400)
        lines.append(f'        {{ key = "{key}", group = "{group}", label = "{label}", icon = {icon}, spell = {ids[0]}, '
                     f'ids = {{')
        lines += lua_ids(ids, "            ")
        lines.append("        } },")
    return lines


def write(crowd, other, debuffs, icons, build):
    lines = [
        f"-- {OUT.name}: PvP Auras' spells by ID, generated by Tools/build/pvp_auras.py from build {build}.",
        "local ns = _G.NaowhForever",
        "",
        "ns.PvPSpells = {",
        "    crowdControl = {",
    ]
    lines += lua_entries(crowd, icons)
    lines += ["    },", "    otherCrowdControl = {"]
    lines += lua_ids(other, "        ")
    lines += ["    },", "    debuffs = {"]
    lines += lua_entries(debuffs, icons)
    lines += ["    },", "}"]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_bytes(("\r\n".join(lines) + "\r\n").encode("ascii"))
    listed = {s for _, _, _, ids in crowd for s in ids}
    print(f"wrote {OUT.relative_to(ROOT)}: {len(crowd)} crowd control abilities ({len(listed)} spells), "
          f"{len(other)} other crowd control spells, {len(debuffs)} debuffs")


def main():
    names = {int(r["ID"]): r["Name_lang"] for r in wago.table("SpellName")}
    auras = auras_by_spell(wago.table("SpellEffect"))
    icons = {int(r["SpellID"]): int(r["SpellIconFileDataID"] or 0) for r in wago.table("SpellMisc")}
    crowd = resolve(CROWD_CONTROL, names, auras, lambda a: bool(a & CROWD_CONTROL_AURAS))
    debuffs = resolve(DEBUFFS, names, auras, lambda a: bool(a - {0}))
    listed = {s for _, _, _, ids in crowd for s in ids}
    other = sorted(s for s, a in auras.items() if a & CROWD_CONTROL_AURAS and s not in listed)
    write(crowd, other, debuffs, icons, wago.BUILD)


if __name__ == "__main__":
    main()
