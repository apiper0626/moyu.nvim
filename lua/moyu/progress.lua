local M = {}
local offsets_cache = setmetatable({}, { __mode = 'k' })

function M.offsets(lines)
  if offsets_cache[lines] then return unpack(offsets_cache[lines]) end
  local starts, total = {}, 0
  for index, text in ipairs(lines) do
    starts[index] = total
    total = total + vim.fn.strchars(text) + 1
  end
  local value = { starts, math.max(1, total - 1) }
  offsets_cache[lines] = value
  return unpack(value)
end

function M.percent(lines, pos)
  local starts, total = M.offsets(lines)
  return math.min(100, math.floor(((starts[pos.line] or 0) + (pos.char or 0)) / total * 100))
end

return M
