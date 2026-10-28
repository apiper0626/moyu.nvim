vim.opt.rtp:prepend(vim.fn.getcwd())
local reader = require('moyu')
reader.toggle()
local ns = vim.api.nvim_get_namespaces()['moyu.stealth']
local function rows() return #vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })[1][4].virt_lines end
assert(rows() == 3, 'changed line count should survive a restart')
reader.close()
reader.setup({ stealth = { lines = 5 } })
reader.toggle()
assert(rows() == 5, 'explicit configuration should override saved preference')
reader.close()
print('PASS: 重启恢复行数与显式配置优先')
vim.cmd('qa!')
