vim.opt.rtp:prepend(vim.fn.getcwd())
vim.cmd('runtime plugin/moyu.lua')
vim.g.mapleader = ' '
local reader = require('moyu')
local dir = vim.fn.stdpath('data') .. '/mode'
vim.fn.mkdir(dir, 'p')
local book = dir .. '/小说.txt'
vim.fn.writefile({ '一', '二', '三', '四', '五', '六' }, book)
reader.setup({ stealth = { lines = 2 } })
vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'local value = 1', 'return value' })
local original = vim.api.nvim_buf_get_lines(0, 0, -1, false)
local events = {}
vim.api.nvim_create_autocmd('User', { pattern = 'MoyuModeChanged', callback = function(event)
  events[#events + 1] = event.data.active
end })
local initial = '%f %l:%c'
vim.wo.statusline = initial
assert(not reader.is_active() and reader.status() == '')
vim.cmd('Moyu ' .. vim.fn.fnameescape(book))
assert(reader.is_active() and reader.status() == '鱼')
assert(vim.api.nvim_eval_statusline(vim.wo.statusline, {}).str:find('鱼', 1, true))
require('moyu.stealth').next()
reader.toggle()
assert(not reader.is_active() and vim.wo.statusline == initial)
reader.toggle()
assert(reader.is_active())
local ns = vim.api.nvim_get_namespaces()['moyu.stealth']
local marks = vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })
assert(marks[1][4].virt_lines[1][1][1]:find('三', 1, true))
reader.close()
assert(vim.deep_equal(events, { true, false, true, false }))
assert(vim.deep_equal(original, vim.api.nvim_buf_get_lines(0, 0, -1, false)))

-- Expression statuslines must still evaluate, and refreshed values must survive exit.
vim.wo.statusline = "%!'editor'"
reader.toggle()
assert(vim.api.nvim_eval_statusline(vim.wo.statusline, {}).str == ' 鱼 editor')
vim.wo.statusline = "%!'updated'"
vim.api.nvim_exec_autocmds('OptionSet', { pattern = 'statusline' })
assert(vim.api.nvim_eval_statusline(vim.wo.statusline, {}).str == ' 鱼 updated')
reader.close()
assert(vim.wo.statusline == "%!'updated'")

vim.keymap.set('n', '<leader>my', '<cmd>MoyuToggle<cr>', { desc = 'Moyu Mode' })
vim.api.nvim_feedkeys(' my', 'xt', false)
assert(reader.is_active(), 'leader my must start reading')
vim.api.nvim_feedkeys(' my', 'xt', false)
assert(not reader.is_active(), 'leader my must exit despite the typing mappings')
assert(vim.fn.maparg(' my', 'n') == '<Cmd>MoyuToggle<CR>' or vim.fn.maparg(' my', 'n') == '<cmd>MoyuToggle<cr>')

vim.cmd('MoyuFloat ' .. vim.fn.fnameescape(book))
assert(not reader.is_active() and vim.bo.buftype == 'nofile')
reader.close()
local picker = require('moyu.picker')
local select = picker.select
picker.select = function(_, _, callback) assert(callback == reader.stealth) end
vim.cmd('Moyu')
vim.cmd('MoyuBooks')
picker.select = select
print('PASS: Moyu Mode 入口、leader my 开关、状态栏、事件、续读、代码保护与浮窗入口')
vim.cmd('qa!')
