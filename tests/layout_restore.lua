vim.opt.rtp:prepend(vim.fn.getcwd())
local reader = require('moyu')
local code = {}
for index = 1, 100 do code[index] = 'local value = ' .. index end
vim.api.nvim_buf_set_lines(0, 0, -1, false, code)
local function marks()
  return vim.api.nvim_buf_get_extmarks(0, vim.api.nvim_create_namespace('moyu.stealth'), 0, -1, { details = true })
end
reader.toggle()
assert(#marks() == 4, 'saved spread layout should survive a restart')
reader.close()
reader.setup({ stealth = { layout = 'block' } })
reader.toggle()
assert(#marks() == 1 and #marks()[1][4].virt_lines == 4, 'explicit configuration should override saved layout')
reader.close()
assert(not pcall(reader.setup, { stealth = { layout = 'unknown' } }), 'unknown layouts must be rejected')
print('PASS: 重启恢复布局、显式配置优先与无效布局校验')
vim.cmd('qa!')
