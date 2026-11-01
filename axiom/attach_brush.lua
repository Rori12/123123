-- Axiom Script Brush: blocks attached to other blocks.
-- Default: buttons of different woods on leaves, turned towards the leaves.
-- Paste into Tool Options of the Script Brush. All settings appear there.
-- Uses only functions from the official Axiom docs.

target1 = $blockState(Target 1,oak_leaves)$
target2 = $blockState(Target 2,birch_leaves)$
target3 = $blockState(Target 3,spruce_leaves)$

count = $int(Blocks to use,6,1,6)$
b1 = $blockState(Block 1,oak_button)$
b2 = $blockState(Block 2,spruce_button)$
b3 = $blockState(Block 3,birch_button)$
b4 = $blockState(Block 4,jungle_button)$
b5 = $blockState(Block 5,acacia_button)$
b6 = $blockState(Block 6,dark_oak_button)$

mode     = $int(Mode 1 button 2 facing 3 none,1,1,3)$
chance   = $float(Density,0.35,0,1)$
seed     = $int(Pattern seed,1,1,1000)$
onTop    = $boolean(Place on top,true)$
onBottom = $boolean(Place below,true)$
onSides  = $boolean(Place on sides,true)$
lookAt   = $boolean(Face the target,false)$
vertical = $boolean(Facing may be up or down,true)$

------------------------------------------------------------------------------

function rand(px, py, pz, salt)
  local v = math.sin(px * 12.9898 + py * 78.233 + pz * 37.719
                     + salt * 91.345 + seed * 47.853) * 43758.5453
  v = v - math.floor(v)
  v = math.sin(v * 1000 + salt * 3.17 + seed) * 43758.5453
  return v - math.floor(v)
end

function isTarget(b)
  return b == target1 or b == target2 or b == target3
end

function isAir(b)
  return b == blocks.air or b == blocks.cave_air
end

-- directions: 1 down, 2 up, 3 north, 4 south, 5 west, 6 east
DX  = { 0, 0, 0, 0, -1, 1 }
DY  = { -1, 1, 0, 0, 0, 0 }
DZ  = { 0, 0, -1, 1, 0, 0 }
OPP = { 2, 1, 4, 3, 6, 5 }
NAME = { "down", "up", "north", "south", "west", "east" }
HOR = { "north", "south", "west", "east" }

-- d = direction from the target to the new block (2 = new block on top)
function sideAllowed(d)
  if d == 2 then return onTop end
  if d == 1 then return onBottom end
  return onSides
end

function chooseBlock(r)
  local n = math.floor(r * count) + 1
  if n > count then n = count end
  if n == 1 then return b1 end
  if n == 2 then return b2 end
  if n == 3 then return b3 end
  if n == 4 then return b4 end
  if n == 5 then return b5 end
  return b6
end

-- block for the air spot (ax,ay,az); `s` = direction from the spot to its target
function makeBlock(ax, ay, az, s)
  local b = chooseBlock(rand(ax, ay, az, 3))
  local away = NAME[OPP[s]]
  local face = away
  if lookAt then face = NAME[s] end
  if mode == 1 then
    if s == 1 then            -- target below: button on the floor
      b = withBlockProperty(b, 'face=floor')
      b = withBlockProperty(b, 'facing=' .. HOR[math.floor(rand(ax, ay, az, 4) * 4) % 4 + 1])
    elseif s == 2 then        -- target above: button on the ceiling
      b = withBlockProperty(b, 'face=ceiling')
      b = withBlockProperty(b, 'facing=' .. HOR[math.floor(rand(ax, ay, az, 4) * 4) % 4 + 1])
    else
      b = withBlockProperty(b, 'face=wall')
      b = withBlockProperty(b, 'facing=' .. face)
    end
  elseif mode == 2 then
    if (s == 1 or s == 2) and not vertical then return nil end  -- ladders etc.
    b = withBlockProperty(b, 'facing=' .. face)
  end
  return b
end

-- Runs on every target block and fills the air around it. Each air spot is
-- decided by the spot itself, so it gets at most one block.
if isTarget(getBlock(x, y, z)) then
  for d = 1, 6 do
    local ax = x + DX[d]
    local ay = y + DY[d]
    local az = z + DZ[d]
    if sideAllowed(d) and isAir(getBlock(ax, ay, az)) and rand(ax, ay, az, 1) < chance then
      -- all targets touching this air spot -> one of them is picked at random
      local n = 0
      local chosen = 0
      for s = 1, 6 do
        if sideAllowed(OPP[s]) and isTarget(getBlock(ax + DX[s], ay + DY[s], az + DZ[s])) then
          n = n + 1
        end
      end
      local k = math.floor(rand(ax, ay, az, 2) * n) + 1
      local i = 0
      for s = 1, 6 do
        if sideAllowed(OPP[s]) and isTarget(getBlock(ax + DX[s], ay + DY[s], az + DZ[s])) then
          i = i + 1
          if i == k then chosen = s end
        end
      end
      if chosen == OPP[d] then      -- the picked target is the current one
        local nb = makeBlock(ax, ay, az, chosen)
        if nb ~= nil then setBlock(ax, ay, az, nb) end
      end
    end
  end
end
