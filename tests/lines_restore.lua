vim.opt.rtp:prepend(vim.fn.getcwd())
local reader = require('moyu')
local code = {}
for index = 1, 100 do code[index] = 'local value = ' .. index end
vim.api.nvim_buf_set_lines(0, 0, -1, false, code)
reader.toggle()
local ns = vim.api.nvim_get_namespaces()['moyu.stealth']
local function rows()
  local count = 0
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })) do
    count = count + #mark[4].virt_lines
  end
  return count
end
assert(rows() == 3, 'changed line count should survive a restart')
reader.close()
reader.setup({ stealth = { lines = 5 } })
reader.toggle()
assert(rows() == 5, 'explicit configuration should override saved preference')
reader.close()
print('PASS: 重启恢复行数与显式配置优先')
vim.cmd('qa!')
