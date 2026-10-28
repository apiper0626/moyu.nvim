vim.opt.rtp:prepend(vim.fn.getcwd())
local reader = require('moyu')
local stealth = require('moyu.stealth')
local directory = vim.fn.stdpath('data')
vim.fn.mkdir(directory, 'p')
local path = directory .. '/viewport.txt'
local lines = {}
for index = 1, 100 do lines[index] = '第 ' .. index .. ' 段' end
vim.fn.writefile(lines, path)
vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
local ns = vim.api.nvim_create_namespace('moyu.stealth')
local function rows()
  return vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })[1][4].virt_lines
end
local function saved_line()
  local state = vim.json.decode(table.concat(vim.fn.readfile(directory .. '/moyu/progress.json'), '\n'))
  return state.books[path].line
end
reader.stealth(path)
assert(#rows() == 8, 'default should display 8 lines')
stealth.next()
assert(saved_line() == 9, 'next segment must start after all visible rows')
reader.close()
vim.cmd('split')
vim.api.nvim_win_set_height(0, 5)
reader.stealth(path)
local visible = #rows()
assert(visible >= 1 and visible <= 4, 'small window should reduce visible rows')
local before = saved_line()
stealth.next()
assert(saved_line() == before + visible, 'reduced segment must not skip text')
vim.api.nvim_win_set_height(0, 3)
vim.api.nvim_exec_autocmds('VimResized', {})
assert(#rows() <= 2, 'resize must recompute available reading space')
reader.close()
print('PASS: 默认 8 行、小窗口自适应、缩放重排与连续翻段')
vim.cmd('qa!')
