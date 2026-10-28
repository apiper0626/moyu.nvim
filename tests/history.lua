vim.opt.rtp:prepend(vim.fn.getcwd())
vim.cmd('runtime plugin/moyu.lua')
local reader = require('moyu')
local dir = vim.fn.stdpath('data') .. '/history'
vim.fn.mkdir(dir, 'p')
local first, second = dir .. '/第一本.txt', dir .. '/第二本.txt'
vim.fn.writefile({ string.rep('中文长段落', 200), '下一段' }, first)
vim.fn.writefile({ '另一本书' }, second)
reader.setup({ stealth = { lines = 1 } })
local state_path = vim.fn.stdpath('data') .. '/moyu/progress.json'
local function saved() return vim.json.decode(table.concat(vim.fn.readfile(state_path), '\n')) end
local time, now = os.time, 100
os.time = function() return now end
reader.stealth(first)
require('moyu.stealth').next()
local expected = saved().books[first].stealth
assert(expected.line == 1 and expected.char > 0)
reader.close()
now = 200
reader.stealth(second)
local picker = require('moyu.picker')
local select = picker.select
picker.select = function(items, format, callback)
  assert(items[1] == second and items[2] == first, 'history must show recent books first')
  assert(format(first):find('第 1 行', 1, true))
  callback(first)
end
reader.history()
assert(reader.is_active())
assert(vim.deep_equal(saved().books[first].stealth, expected), 'history selection must resume exact character position')
reader.close()
reader.stealth(first)
assert(vim.deep_equal(saved().books[first].stealth, expected))
picker.select = function(items, _, callback)
  for _, path in ipairs(items) do if path == first then callback(path); return end end
  error('book missing from history')
end
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<F2>', true, false, true), 'xt', false)
assert(reader.is_active() and vim.deep_equal(saved().books[first].stealth, expected))
reader.close()
picker.select = select
os.time = time
for _, command in ipairs({ 'MoyuChapters', 'MoyuJump', 'MoyuBookmark', 'MoyuBookmarks' }) do
  assert(vim.fn.exists(':' .. command) == 0)
end
print('PASS: 最近阅读排序、历史选书续读、长段落字符位置及简化入口')
vim.cmd('qa!')
