vim.opt.rtp:prepend(vim.fn.getcwd())
vim.cmd('runtime plugin/moyu.lua')
local reader, formats = require('moyu'), require('moyu.formats')
local dir = vim.fn.stdpath('data') .. '/books'
vim.fn.system({ 'python3', 'tests/make_books.py', dir })
assert(vim.v.shell_error == 0)
reader.setup({ book_dir = dir, stealth = { lines = 1 } })
local function read(name)
  local done, result, failure = false, nil, nil
  formats.read(dir .. '/' .. name, function(lines, err) result, failure, done = lines, err, true end)
  assert(vim.wait(5000, function() return done end), 'conversion timed out: ' .. name)
  return result, failure
end
for _, name in ipairs({ '书 籍$epub.EPUB', '文档.docx', '文档.odt', '网页.html', '小说.fb2', '测试.pdf', '编码.txt', 'UTF16.txt', '笔记.md' }) do
  local lines, err = read(name)
  assert(lines and not err and #lines > 0, name .. ': ' .. tostring(err))
end
assert(read('编码.txt')[1] == '第一段中文')
assert(read('UTF16.txt')[1] == 'UTF16 中文')
vim.fn.writefile({ '更新后的笔记内容' }, dir .. '/笔记.md')
assert(read('笔记.md')[1] == '更新后的笔记内容', 'changed source must invalidate extraction cache')
local _, err = read('损坏.epub')
assert(err and err:find('提取失败', 1, true))
_, err = read('扫描.pdf')
assert(err and err:find('OCR', 1, true))
_, err = read('未知.bin')
assert(err and err:find('暂不支持', 1, true))
local picker, seen = require('moyu.picker'), {}
local select = picker.select
picker.select = function(paths) for _, path in ipairs(paths) do seen[vim.fn.fnamemodify(path, ':t')] = true end end
reader.books()
assert(seen['书 籍$epub.EPUB'] and seen['测试.pdf'] and seen['文档.docx'] and not seen['未知.bin'])
picker.select = select
local original = vim.api.nvim_buf_get_lines(0, 0, -1, false)
-- Clear the module cache to ensure the command also exercises asynchronous loading.
package.loaded['moyu.formats'] = nil
local async_formats = require('moyu.formats')
local completed = false
local job = async_formats.read(dir .. '/书 籍$epub.EPUB', function(lines, failure)
  assert(lines and not failure)
  completed = true
end)
assert(job and not completed, 'EPUB conversion must not block the editor')
assert(vim.wait(5000, function() return completed end))
assert((vim.uv or vim.loop).fs_copyfile(dir .. '/书 籍$epub.EPUB', dir .. '/异步.epub'))
vim.cmd('Moyu ' .. vim.fn.fnameescape(dir .. '/异步.epub'))
assert(vim.wait(5000, reader.is_active))
require('moyu.stealth').next()
reader.close()
reader.toggle()
assert(reader.is_active())
reader.close()
assert(vim.deep_equal(original, vim.api.nvim_buf_get_lines(0, 0, -1, false)))
reader.open(dir .. '/文档.docx')
assert(vim.wait(5000, function() return vim.bo.buftype == 'nofile' end))
assert(vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == '第一段中文')
reader.close()
-- Closing or moving to another window while converting must not reopen reading.
local read_original = formats.read
local complete
formats.read = function(_, callback) complete = callback end
reader.stealth(dir .. '/测试.pdf')
reader.close()
complete({ '迟到的结果' })
assert(not reader.is_active())
reader.stealth(dir .. '/测试.pdf')
vim.cmd('vsplit')
complete({ '迟到的结果' })
assert(not reader.is_active())
vim.cmd('close')
formats.read = read_original
print('PASS: 多格式提取、编码、格式搜索、模式/浮窗阅读、转换失败与取消')
vim.cmd('qa!')
