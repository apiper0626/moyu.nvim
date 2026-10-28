vim.opt.rtp:prepend(vim.fn.getcwd())
vim.cmd('runtime plugin/moyu.lua')
local reader = require('moyu')
reader.setup({ width = 0.6, height = 0.6 })
local dir = vim.fn.stdpath('data') .. '/fixtures'
reader.setup({ book_dir = dir })
vim.fn.mkdir(dir, 'p')
local first, second = dir .. '/小说.txt', dir .. '/另一本.txt'
local lines = {}
for i = 1, 100 do lines[i] = '第 ' .. i .. ' 行：这是一本用于测试的小说。' end
vim.fn.writefile(lines, first)
vim.fn.writefile({ '另一本书' }, second)
local original = vim.api.nvim_get_current_win()
reader.open(first)
assert(vim.api.nvim_win_get_config(0).relative == 'editor')
assert(vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == lines[1])
assert(not vim.bo.modifiable)
vim.api.nvim_win_set_cursor(0, { 42, 0 })
reader.close()
assert(vim.api.nvim_get_current_win() == original)
reader.float_toggle()
assert(vim.api.nvim_win_get_cursor(0)[1] == 42)
reader.open(second)
assert(vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == '另一本书')
reader.open(first)
assert(vim.api.nvim_win_get_cursor(0)[1] == 42)
reader.close()
local picker = require('moyu.picker')
local select = picker.select
local count = 0
picker.select = function(items) count = #items end
reader.books()
assert(count == 2)
picker.select = select
assert(vim.fn.exists(':Moyu') == 2)
print('PASS: 打开、切书、隐藏、进度、书架与命令')
vim.cmd('qa!')
