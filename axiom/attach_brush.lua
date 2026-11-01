-- Axiom Script Brush: "attach" brush
-- Fills air next to chosen blocks with other blocks turned towards them.
-- Default preset: buttons of random wood types stuck to leaves.
--
-- How to use: Axiom -> Tools -> Script Brush, paste this whole file,
-- pick a preset below (PRESET = "...") or edit its settings, then paint.
-- The script runs for every block inside the brush; it only changes air.

-------------------------------------------------------------------- settings
PRESET = "leaf_buttons"

PRESETS = {
  -- Buttons on leaves, random colours (wood types), random sides
  leaf_buttons = {
    targets  = { "#leaves" },           -- "#tag" or block id, e.g. "oak_leaves"
    place    = { "oak_button", "spruce_button", "birch_button",
                 "jungle_button", "acacia_button", "dark_oak_button" },
    mode     = "button",                -- see MODES below
    sides    = { up = true, down = true, north = true, south = true,
                 east = true, west = true },  -- which side of the target may get a block
    chance   = 0.35,                    -- 0..1 how many air spots get filled
    seed     = 1,                       -- change to get another random pattern
  },

  -- Same, but only green-ish/dark buttons
  leaf_buttons_dark = {
    targets  = { "#leaves" },
    place    = { "dark_oak_button", "spruce_button", "mangrove_button" },
    mode     = "button",
    sides    = { up = true, down = true, north = true, south = true,
                 east = true, west = true },
    chance   = 0.35,
    seed     = 1,
  },

  -- Levers on stone walls (only on the sides)
  stone_levers = {
    targets  = { "stone", "cobblestone" },
    place    = { "lever" },
    mode     = "button",
    sides    = { north = true, south = true, east = true, west = true },
    chance   = 0.2,
    seed     = 1,
  },

  -- Amethyst clusters growing out of amethyst blocks
  amethyst = {
    targets  = { "amethyst_block", "budding_amethyst" },
    place    = { "amethyst_cluster", "large_amethyst_bud", "medium_amethyst_bud",
                 "small_amethyst_bud" },
    mode     = "facing_away",
    sides    = { up = true, down = true, north = true, south = true,
                 east = true, west = true },
    chance   = 0.5,
    seed     = 1,
  },

  -- Ladders / wall decorations on planks (wall sides only)
  plank_ladders = {
    targets  = { "#planks" },
    place    = { "ladder" },
    mode     = "facing_away",
    sides    = { north = true, south = true, east = true, west = true },
    chance   = 1.0,
    seed     = 1,
  },
}

-- MODES
--   "button"      buttons, levers, grindstones: face=floor/ceiling/wall + facing
--   "facing_away" blocks with a "facing" property that points away from the
--                 support: amethyst, end rods, lightning rods, ladders, wall signs...
--   "facing_to"   blocks with "facing" that should look AT the target
--   "none"        just place the block, no rotation

-------------------------------------------------------------------- logic
local cfg = PRESETS[PRESET]

-- direction from the air block to the neighbour, and its opposite
local DIRS = {
  { name = "down",  dx = 0,  dy = -1, dz = 0,  opposite = "up"    },
  { name = "up",    dx = 0,  dy = 1,  dz = 0,  opposite = "down"  },
  { name = "north", dx = 0,  dy = 0,  dz = -1, opposite = "south" },
  { name = "south", dx = 0,  dy = 0,  dz = 1,  opposite = "north" },
  { name = "west",  dx = -1, dy = 0,  dz = 0,  opposite = "east"  },
  { name = "east",  dx = 1,  dy = 0,  dz = 0,  opposite = "west"  },
}
local HORIZONTAL = { "north", "south", "west", "east" }

-- Stable pseudo-random number 0..1 for a position (same result on every pass,
-- so re-painting the same spot does not flicker).
local function rand(px, py, pz, salt)
  local v = math.sin(px * 12.9898 + py * 78.233 + pz * 37.719
                     + salt * 91.345 + cfg.seed * 47.853) * 43758.5453
  v = v - math.floor(v)
  v = math.sin(v * 1000 + salt * 3.17 + cfg.seed) * 43758.5453
  return v - math.floor(v)
end

local function pick(list, r)
  return list[math.floor(r * #list) + 1] or list[#list]
end

local function isTarget(block)
  for _, t in ipairs(cfg.targets) do
    if string.sub(t, 1, 1) == "#" then
      if isBlockTagged(block, string.sub(t, 2)) then return true end
    elseif block == blocks[t] then
      return true
    end
  end
  return false
end

local function run()
  if cfg == nil then return nil end

  local here = getBlock(x, y, z)
  if here ~= blocks.air and here ~= blocks.cave_air then return nil end

  -- "sides" are named from the target's point of view: a button on the TOP of
  -- a leaf has the leaf below it, so the leaf's "up" side is used.
  local found = {}
  for _, d in ipairs(DIRS) do
    if cfg.sides[d.opposite] and isTarget(getBlock(x + d.dx, y + d.dy, z + d.dz)) then
      found[#found + 1] = d
    end
  end
  if #found == 0 then return nil end
  if rand(x, y, z, 1) >= cfg.chance then return nil end

  local support = pick(found, rand(x, y, z, 2))  -- neighbour we attach to
  local block = blocks[pick(cfg.place, rand(x, y, z, 3))]
  if block == nil then return nil end

  if cfg.mode == "button" then
    if support.name == "down" then
      block = withBlockProperty(block, "face=floor")
      block = withBlockProperty(block, "facing=" .. pick(HORIZONTAL, rand(x, y, z, 4)))
    elseif support.name == "up" then
      block = withBlockProperty(block, "face=ceiling")
      block = withBlockProperty(block, "facing=" .. pick(HORIZONTAL, rand(x, y, z, 4)))
    else
      block = withBlockProperty(block, "face=wall")
      block = withBlockProperty(block, "facing=" .. support.opposite)
    end
  elseif cfg.mode == "facing_away" then
    block = withBlockProperty(block, "facing=" .. support.opposite)
  elseif cfg.mode == "facing_to" then
    block = withBlockProperty(block, "facing=" .. support.name)
  end
  return block
end

return run()
