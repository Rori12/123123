-- Axiom Script Brush: блоки, прикреплённые к другим блокам
-- По умолчанию: кнопки разных цветов на листве, повёрнутые к листве.
-- Вставьте файл в Tool Options кисти Script Brush; все настройки
-- (блоки, плотность, стороны) появятся там же. Сохраняйте варианты
-- через Presets в Axiom.

target    = $blockState(Цель,oak_leaves)$
anyLeaves = $boolean(Любая листва,true)$

count = $int(Сколько блоков из списка,6,1,6)$
b1 = $blockState(Блок 1,oak_button)$
b2 = $blockState(Блок 2,spruce_button)$
b3 = $blockState(Блок 3,birch_button)$
b4 = $blockState(Блок 4,jungle_button)$
b5 = $blockState(Блок 5,acacia_button)$
b6 = $blockState(Блок 6,dark_oak_button)$

chance   = $float(Плотность,0.35,0,1)$
seed     = $int(Сид узора,1,1,1000)$
onTop    = $boolean(Ставить сверху,true)$
onBottom = $boolean(Ставить снизу,true)$
onSides  = $boolean(Ставить по бокам,true)$
lookAt   = $boolean(Повернуть лицом к цели,false)$

------------------------------------------------------------------------------

local PLACE = { b1, b2, b3, b4, b5, b6 }

local LEAVES = {}
for _, name in ipairs({ "oak_leaves", "spruce_leaves", "birch_leaves",
    "jungle_leaves", "acacia_leaves", "dark_oak_leaves", "mangrove_leaves",
    "cherry_leaves", "azalea_leaves", "flowering_azalea_leaves",
    "pale_oak_leaves" }) do
  local id = blocks[name]
  if id ~= nil then LEAVES[id] = true end
end

-- direction from a block to its neighbour
local DIRS = {
  { name = "down",  dx = 0,  dy = -1, dz = 0,  opp = "up"    },
  { name = "up",    dx = 0,  dy = 1,  dz = 0,  opp = "down"  },
  { name = "north", dx = 0,  dy = 0,  dz = -1, opp = "south" },
  { name = "south", dx = 0,  dy = 0,  dz = 1,  opp = "north" },
  { name = "west",  dx = -1, dy = 0,  dz = 0,  opp = "east"  },
  { name = "east",  dx = 1,  dy = 0,  dz = 0,  opp = "west"  },
}
local HORIZONTAL = { "north", "south", "west", "east" }

local function isTarget(b)
  return b == target or (anyLeaves and LEAVES[b] == true)
end

local function isAir(b)
  return b == blocks.air or b == blocks.cave_air
end

-- side of the target the new block sits on ("up" = on top of the target)
local function sideAllowed(side)
  if side == "up" then return onTop end
  if side == "down" then return onBottom end
  return onSides
end

-- stable random 0..1 per position: repainting does not reshuffle the pattern
local function rand(px, py, pz, salt)
  local v = math.sin(px * 12.9898 + py * 78.233 + pz * 37.719
                     + salt * 91.345 + seed * 47.853) * 43758.5453
  v = v - math.floor(v)
  v = math.sin(v * 1000 + salt * 3.17 + seed) * 43758.5453
  return v - math.floor(v)
end

local function pick(list, n, r)
  return list[math.min(n, math.floor(r * n) + 1)]
end

local function hasProperty(b, prop)
  local ok, v = pcall(getBlockProperty, b, prop)
  return ok and v ~= nil and v ~= ""
end

local function withProp(b, prop)
  if b == nil then return nil end
  local ok, v = pcall(withBlockProperty, b, prop)
  if ok then return v end
  return nil
end

-- block for air spot (ax,ay,az) attached to a target in direction `support`
local function makeBlock(ax, ay, az, support)
  local b = pick(PLACE, count, rand(ax, ay, az, 3))
  if hasProperty(b, "face") then           -- buttons, levers, grindstone
    if support.name == "down" or support.name == "up" then
      b = withProp(b, support.name == "down" and "face=floor" or "face=ceiling")
      b = withProp(b, "facing=" .. pick(HORIZONTAL, 4, rand(ax, ay, az, 4)))
    else
      b = withProp(b, "face=wall")
      b = withProp(b, "facing=" .. (lookAt and support.name or support.opp))
    end
  elseif hasProperty(b, "facing") then     -- amethyst, end rod, ladder...
    b = withProp(b, "facing=" .. (lookAt and support.name or support.opp))
  end
  return b
end

-- Runs on target blocks. Each air spot is decided only by the spot itself, so
-- a spot touching several targets still gets exactly one block.
local here = getBlock(x, y, z)
if isTarget(here) then
  for _, d in ipairs(DIRS) do
    local ax, ay, az = x + d.dx, y + d.dy, z + d.dz
    if sideAllowed(d.name) and isAir(getBlock(ax, ay, az))
        and rand(ax, ay, az, 1) < chance then
      local found = {}
      for _, s in ipairs(DIRS) do
        if sideAllowed(s.opp)
            and isTarget(getBlock(ax + s.dx, ay + s.dy, az + s.dz)) then
          found[#found + 1] = s
        end
      end
      local support = pick(found, #found, rand(ax, ay, az, 2))
      if support ~= nil and support.opp == d.name then  -- chosen target is this one
        local b = makeBlock(ax, ay, az, support)
        if b ~= nil then setBlock(ax, ay, az, b) end
      end
    end
  end
end
