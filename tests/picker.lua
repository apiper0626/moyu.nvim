vim.opt.rtp:prepend(vim.fn.getcwd())
vim.cmd('runtime plugin/moyu.lua')
local reader = require('moyu')
local picker = require('moyu.picker')
local dir = vim.fn.stdpath('data') .. '/picker books'
vim.fn.mkdir(dir .. '/nested', 'p')
local first, second = dir .. '/伯爵.txt', dir .. '/nested/另一部 $书.txt'
vim.fn.writefile({ '第一本' }, first)
vim.fn.writefile({ '第二本' }, second)
reader.setup({ book_dir = dir })
local select = picker.select
local found, handler
picker.select = function(items, _, callback) found, handler = items, callback end
vim.cmd('Moyu')
assert(#found == 2 and handler == reader.stealth)
vim.cmd('MoyuStealth')
assert(#found == 2 and handler == reader.stealth)
picker.select = select

local original = vim.api.nvim_get_current_win()
local chosen
picker.select({ first, second }, function(path) return path end, function(path) chosen = path end)
local terminal = vim.api.nvim_get_current_buf()
local job = vim.b[terminal].terminal_job_id
assert(job and vim.api.nvim_get_current_win() ~= original)
assert(vim.wait(3000, function()
  return table.concat(vim.api.nvim_buf_get_lines(terminal, 0, -1, false), '\n'):find('伯爵', 1, true) ~= nil
end), 'fzf did not start')
vim.api.nvim_chan_send(job, '另一部')
vim.wait(200)
vim.api.nvim_chan_send(job, '\r')
assert(vim.wait(3000, function() return chosen ~= nil end), 'fzf selection failed')
assert(chosen == second, 'selected path must survive whitespace and shell characters')
assert(vim.api.nvim_get_current_win() == original)
assert(not vim.api.nvim_buf_is_valid(terminal))

chosen = nil
picker.select({ first, second }, function(path) return path end, function(path) chosen = path end)
terminal = vim.api.nvim_get_current_buf()
job = vim.b[terminal].terminal_job_id
vim.wait(200)
vim.api.nvim_chan_send(job, '\27')
assert(vim.wait(3000, function() return not vim.api.nvim_buf_is_valid(terminal) end))
assert(chosen == nil and vim.api.nvim_get_current_win() == original)

-- Exercise the actual reader callback, rather than only recording a selection.
vim.cmd('MoyuStealth')
terminal = vim.api.nvim_get_current_buf()
job = vim.b[terminal].terminal_job_id
assert(job)
vim.wait(200)
vim.api.nvim_chan_send(job, '\r')
assert(vim.wait(3000, function() return require('moyu.stealth').active() end), 'fzf must enter code reading')
assert(vim.api.nvim_get_current_win() == original)
reader.close()

-- A missing binary falls back to the configured Neovim selector.
local executable, ui_select = vim.fn.executable, vim.ui.select
vim.fn.executable = function() return 0 end
vim.ui.select = function(items, _, callback) callback(items[2]) end
picker.select({ first, second }, function(path) return path end, function(path) chosen = path end)
assert(chosen == second)
vim.fn.executable, vim.ui.select = executable, ui_select
print('PASS: 命令搜索、递归书架、真实 fzf 中文搜索、特殊路径、取消与降级')
vim.cmd('qa!')
