vim.opt.rtp:prepend(vim.fn.getcwd())
local state_path = vim.fn.stdpath('data') .. '/moyu/progress.json'
local function saved() return vim.json.decode(table.concat(vim.fn.readfile(state_path), '\n')) end
local before = saved()
local path, expected = before.last, before.books[before.last].stealth
assert(expected.char > 0)
local picker = require('moyu.picker')
picker.select = function(items, _, callback)
  for _, item in ipairs(items) do if item == path then callback(item); return end end
  error('history was not persisted')
end
local reader = require('moyu')
reader.history()
assert(reader.is_active())
assert(vim.deep_equal(saved().books[path].stealth, expected))
reader.close()
print('PASS: 重启后从历史恢复到上次阅读的行和字符位置')
vim.cmd('qa!')
