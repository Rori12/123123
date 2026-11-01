-- ТЕСТ ПО ШАГАМ. Проведите кистью по ДУБОВОЙ листве.
-- Блок листвы по очереди перекрашивается; цвет, который остался,
-- показывает, на каком шаге скрипт упал:
--   листва не изменилась  -> не совпала листва (странно: тест 0 её находил)
--   белая шерсть          -> упал math.sin
--   жёлтая шерсть         -> упал withBlockProperty (face=wall) на кнопке из окна
--   оранжевая шерсть      -> упал withBlockProperty (facing=north)
--   розовая шерсть        -> упал setBlock с изменённым состоянием блока
--   зелёная шерсть и кнопка сверху -> всё работает
btn = $blockState(Block 1,oak_button)$

if getBlock(x, y, z) == blocks.oak_leaves then
  setBlock(x, y, z, blocks.white_wool)
  v = math.sin(1.5) * 100
  setBlock(x, y, z, blocks.yellow_wool)
  w = withBlockProperty(btn, 'face=wall')
  setBlock(x, y, z, blocks.orange_wool)
  w = withBlockProperty(w, 'facing=north')
  setBlock(x, y, z, blocks.pink_wool)
  setBlock(x, y + 1, z, w)
  setBlock(x, y, z, blocks.lime_wool)
end
