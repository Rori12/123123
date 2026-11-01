-- ТЕСТ 2: над каждым блоком дубовой листвы в кисти ставит красную шерсть
-- (через setBlock, как основной скрипт). Если ТЕСТ 1 работает, а этот нет,
-- то кисть не обходит листву или не принимает setBlock.
if getBlock(x, y, z) == blocks.oak_leaves then
  setBlock(x, y + 1, z, blocks.red_wool)
end
