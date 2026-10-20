-- SleepingBag.lua: the Cozy Sleeping Bag's hidden quest chain, each step a thing in the world to click.
local ns = _G.NaowhForever

local POCKET_LITTER = { object = "Pocket Litter", map = 1442, x = 40.8, y = 52.6, place = "an abandoned camp",
    done = 79192, tip = "Take the path northeast of Sun Rock Retreat; it lies on top of a box." }
local MOUND_OF_DIRT = { object = "Mound of Dirt", map = 1442, x = 39.6, y = 49.9, place = "a ledge north of the camp",
    done = 79980, tip = "Climb the hill straight north of the camp and jump across to it from the edge." }
local CARVED_FIGURINE = { object = "Carved Figurine", map = 1432, x = 49.5, y = 12.8, place = "the Stonewrought Dam",
    done = 79974, tip = "Jump onto the carved heads facing the Wetlands." }
local MESSENGER_BAG = { object = "Messenger Bag", map = 1417, x = 22.5, y = 24.2, place = "inside Thoradin's Wall",
    done = 79975, tip = "Climb into the wall from the cart on the Hillsbrad side (Hillsbrad Foothills 87.3, 49.6); the bag "
        .. "hangs outside, to the right." }
local SATCHEL = { object = "Hastily Rolled-Up Satchel", map = 1417, x = 22.5, y = 24.2, place = "under the Messenger Bag",
    done = 79976, tip = "Right below the Messenger Bag. It holds the Cozy Sleeping Bag." }

ns.SleepingBag = {
    level = 14,
    item = ns.Shared.Items.SLEEPING_BAG,
    steps = {
        A = {
            { object = "Burned-Out Remains", map = 1436, x = 37.5, y = 50.7, place = "Alexston Farmstead",
              tip = "The wreckage of a cart in the rubble.", started = 79008 },
            { object = "Burned-Out Remains", map = 1413, x = 46.4, y = 73.9,
              place = "the burnt tower south of Camp Taurajo", tip = "Follow the road south of Camp Taurajo.",
              done = 79008 },
            POCKET_LITTER, MOUND_OF_DIRT, CARVED_FIGURINE, MESSENGER_BAG, SATCHEL,
        },
        H = {
            { object = "Burned-Out Remains", map = 1413, x = 46.4, y = 73.9,
              place = "the burnt tower south of Camp Taurajo", tip = "Follow the road south of Camp Taurajo.",
              started = 79007 },
            { object = "Burned-Out Remains", map = 1436, x = 37.5, y = 50.7, place = "Alexston Farmstead",
              tip = "The wreckage of a cart in the rubble.", done = 79007 },
            POCKET_LITTER, MOUND_OF_DIRT, CARVED_FIGURINE, MESSENGER_BAG, SATCHEL,
        },
    },
    optional = { object = "Firepit", map = 1442, x = 40.6, y = 52.4, place = "the abandoned camp", done = 80001,
        quest = "Rekindle",
        tip = "Light it with the Simple Wood and Flint and Tinder from the Pocket Litter. Not needed for the bag." },
}
