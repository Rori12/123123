-- ТЕСТ ПО ШАГАМ. Проведите кистью по ДУБОВОЙ листве.
-- Блок листвы по очереди перекрашивается; цвет, который остался,
-- показывает, на каком шаге скрипт упал:
--   листва не изменилась  -> значение из окна "Target 1" не совпало с листвой
--   белая шерсть          -> упал math.sin
--   жёлтая шерсть         -> упал withBlockProperty (face=wall)
--   оранжевая шерсть      -> упал withBlockProperty (facing=north)
--   розовая шерсть        -> упал setBlock с изменённым состоянием блока
--   зелёная шерсть и кнопка сверху -> всё работает
t1 = $blockState(Target 1,oak_leaves)$

if getBlock(x, y, z) == t1 then
  setBlock(x, y, z, blocks.white_wool)
  v = math.sin(1.5) * 100
  setBlock(x, y, z, blocks.yellow_wool)
  w = withBlockProperty(blocks.oak_button, 'face=wall')
  setBlock(x, y, z, blocks.orange_wool)
  w = withBlockProperty(w, 'facing=north')
  setBlock(x, y, z, blocks.pink_wool)
  setBlock(x, y + 1, z, w)
  setBlock(x, y, z, blocks.lime_wool)
end
