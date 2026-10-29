-- Exercise the same lazy.nvim loader used by the user's configuration.
local lazy_path = vim.env.LAZY_NVIM_PATH or vim.fn.expand('~/.local/share/nvim/lazy/lazy.nvim')
vim.opt.rtp:prepend(lazy_path)
vim.o.loadplugins = true
vim.g.mapleader = ' '
local spec = dofile('integration/moyu.lua')
assert(spec[1][1] == 'apiper0626/moyu.nvim' and spec[1].dir == nil)
spec[1].dir = vim.fn.getcwd()
spec[1].opts.book_dir = vim.fn.getcwd() .. '/books'
require('lazy').setup({
  spec = spec,
  root = vim.fn.stdpath('data') .. '/lazy',
  lockfile = vim.fn.stdpath('data') .. '/lazy-lock.json',
  install = { missing = false },
  checker = { enabled = false },
  change_detection = { enabled = false },
})
assert(vim.fn.exists(':Moyu') == 2, 'lazy command was not registered')
assert(vim.fn.exists(':MoyuStealth') == 2)
assert(vim.fn.maparg(' my', 'n') ~= '', 'leader my lazy-loading shortcut missing')
local chosen = false
package.loaded['moyu.picker'] = { select = function(paths, _, callback)
  for _, path in ipairs(paths) do
    if path:find('基督山伯爵', 1, true) then chosen = true; callback(path); return end
  end
end }
assert(not vim.g.loaded_moyu, 'plugin should still be lazy before the shortcut')
assert(vim.fn.maparg('<F3>', 'n') == '', 'lazy loading must not install a global layout shortcut')
vim.api.nvim_feedkeys(' my', 'xt', false)
assert(chosen, 'lazy-loaded command did not find the bundled book')
assert(vim.g.loaded_moyu == true, 'plugin entrypoint was not loaded')
assert(require('moyu').is_active(), 'leader my must lazy-load and enter Moyu Mode')
assert(vim.fn.maparg('<F3>', 'n', false, true).buffer == 1, 'layout shortcut must be buffer-local in Moyu Mode')
vim.api.nvim_feedkeys(' my', 'xt', false)
assert(not require('moyu').is_active())
assert(vim.fn.maparg('<F3>', 'n') == '', 'leaving Moyu Mode must remove its layout shortcut')
print('PASS: leader my 通过 lazy.nvim 首次加载、选书阅读与再次退出')
vim.cmd('qa!')
