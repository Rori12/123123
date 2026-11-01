-- ДИАГНОСТИКА за один мазок. Что вы увидите, то и значит:
--   зелёное стекло в воздухе  -> кисть обходит воздух, return работает
--   красная шерсть вместо листвы дуба -> блок листвы распознан
--   синяя шерсть НАД листвой  -> setBlock со смещением работает
--   ничего не изменилось      -> скрипт не запускается (ошибка в тексте) или
--                                кисть не применяется (маска, режим, лишний текст)
local b = getBlock(x, y, z)
if b == blocks.air then
  return blocks.lime_stained_glass
end
if b == blocks.oak_leaves then
  setBlock(x, y + 1, z, blocks.blue_wool)
  return blocks.red_wool
end
