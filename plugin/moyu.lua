if vim.g.loaded_moyu then return end
vim.g.loaded_moyu = true

vim.api.nvim_create_user_command('Moyu', function(opts)
  local reader = require('moyu')
  if opts.args == '' then reader.books() else reader.stealth(opts.args) end
end, { nargs = '?', complete = 'file', desc = '搜索书籍并进入 Moyu Mode' })
vim.api.nvim_create_user_command('MoyuToggle', function() require('moyu').toggle() end, {})
vim.api.nvim_create_user_command('MoyuClose', function() require('moyu').close() end, {})
vim.api.nvim_create_user_command('MoyuBooks', function() require('moyu').books() end, {})
vim.api.nvim_create_user_command('MoyuStealth', function(opts)
  local reader = require('moyu')
  if opts.args == '' then reader.books(reader.stealth) else reader.stealth(opts.args) end
end, { nargs = '?', complete = 'file', desc = '在代码区按键阅读' })
vim.api.nvim_create_user_command('MoyuStealthToggle', function() require('moyu').stealth_toggle() end, {})
vim.api.nvim_create_user_command('MoyuFloat', function(opts)
  local reader = require('moyu')
  if opts.args == '' then reader.books(reader.open) else reader.open(opts.args) end
end, { nargs = '?', complete = 'file', desc = '浮窗阅读' })
vim.api.nvim_create_user_command('MoyuFloatToggle', function() require('moyu').float_toggle() end, {})
vim.api.nvim_create_user_command('MoyuHistory', function() require('moyu').history() end, {})
