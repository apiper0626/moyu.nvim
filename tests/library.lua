vim.opt.rtp:prepend(vim.fn.getcwd())
vim.cmd('runtime plugin/moyu.lua')
-- Simulate an independent home without reading or creating the real user's library.
local expand = vim.fn.expand
local library = vim.fn.stdpath('data') .. '/independent-library'
vim.fn.expand = function(value)
  if value == '~/Books/moyu' then return library end
  return expand(value)
end
vim.fn.mkdir(library, 'p')
vim.fn.writefile({ '自己的书' }, library .. '/my-book.txt')
local reader = require('moyu')
local picker = require('moyu.picker')
local selected
picker.select = function(items, _, callback) selected = items; callback(items[1]) end
reader.books()
assert(#selected == 1 and selected[1] == library .. '/my-book.txt')
assert(reader.is_active())
reader.close()
local custom = library .. '/custom'
vim.fn.mkdir(custom, 'p')
vim.fn.writefile({ '自定义目录' }, custom .. '/custom.md')
reader.setup({ book_dir = custom })
reader.books()
assert(vim.tbl_contains(selected, custom .. '/custom.md'))
assert(vim.tbl_contains(selected, library .. '/my-book.txt'), 'history should remain available outside configured library')
reader.close()
vim.fn.expand = expand
print('PASS: 默认独立书库、自定义目录与历史保留，不扫描插件示例目录')
vim.cmd('qa!')
