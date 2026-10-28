vim.opt.rtp:prepend(vim.fn.getcwd())
local plugins = vim.env.MOYU_TEST_PLUGINS or vim.fn.expand('~/.local/share/nvim/lazy')
vim.opt.rtp:append(plugins .. '/lualine.nvim')
vim.opt.rtp:append(plugins .. '/nvim-web-devicons')
local config_path = vim.env.MOYU_TEST_LUALINE_CONFIG
local opts = config_path and dofile(config_path)[1].opts or {
  options = { theme = 'auto', globalstatus = true, icons_enabled = false },
  sections = { lualine_a = { 'mode' }, lualine_c = { 'filename' }, lualine_z = { 'location' } },
}
local lualine = require('lualine')
lualine.setup(opts)
lualine.refresh({ place = { 'statusline' }, force = true })
local reader = require('moyu')
local path = vim.fn.stdpath('data') .. '/lualine-book.txt'
vim.fn.mkdir(vim.fn.stdpath('data'), 'p')
vim.fn.writefile({ '第一段', '第二段', '第三段', '第四段' }, path)
reader.stealth(path)
for _ = 1, 3 do
  lualine.refresh({ place = { 'statusline' }, force = true })
  local status = vim.api.nvim_eval_statusline(vim.wo.statusline, {}).str
  assert(status:find('鱼', 1, true), 'lualine refresh removed mode indicator')
end
reader.close()
lualine.refresh({ place = { 'statusline' }, force = true })
assert(not vim.api.nvim_eval_statusline(vim.wo.statusline, {}).str:find('鱼', 1, true))
print('PASS: 当前 lualine 配置下状态标记在刷新后保留，退出后清除')
vim.cmd('qa!')
