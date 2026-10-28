local M = {}
local extensions = {
  txt = true, text = true, md = true, markdown = true,
  epub = true, pdf = true, html = true, htm = true, xhtml = true,
  docx = true, fb2 = true, mobi = true, azw = true, azw3 = true,
  rtf = true, odt = true,
}
local plain = { txt = true, text = true, md = true, markdown = true }
local cache = {}
local helper = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':h:h:h') .. '/scripts/extract_book.py'

local function valid_utf8(text)
  local index = 1
  while index <= #text do
    local first = text:byte(index)
    local count = first < 128 and 1 or (first >= 194 and first <= 223 and 2)
      or (first >= 224 and first <= 239 and 3) or (first >= 240 and first <= 244 and 4)
    if not count or index + count - 1 > #text then return false end
    for offset = 1, count - 1 do
      local byte = text:byte(index + offset)
      if byte < 128 or byte > 191 then return false end
    end
    local second = text:byte(index + 1)
    if (first == 224 and second < 160) or (first == 237 and second >= 160)
      or (first == 240 and second < 144) or (first == 244 and second >= 144) then return false end
    index = index + count
  end
  return true
end

function M.supported(path)
  return extensions[vim.fn.fnamemodify(path, ':e'):lower()] == true
end

-- Plain UTF-8 files remain synchronous; conversion runs as an asynchronous job.
function M.read(path, callback)
  if not M.supported(path) then callback(nil, '暂不支持的书籍格式：' .. path); return end
  local stat = (vim.uv or vim.loop).fs_stat(path)
  if not stat or stat.type ~= 'file' then callback(nil, '无法读取书籍：' .. path); return end
  local signature = table.concat({ stat.size, stat.mtime.sec, stat.mtime.nsec }, ':')
  local saved = cache[path]
  if saved and saved.signature == signature then callback(vim.deepcopy(saved.lines)); return end
  local function finish(lines, err)
    if lines then
      if #lines == 0 then lines = { '' } end
      lines[1] = lines[1]:gsub('^\239\187\191', '')
      cache[path] = { signature = signature, lines = vim.deepcopy(lines) }
    end
    callback(lines, err)
  end
  if plain[vim.fn.fnamemodify(path, ':e'):lower()] then
    local ok, lines = pcall(vim.fn.readfile, path)
    if not ok then callback(nil, '读取失败：' .. tostring(lines)); return end
    local text = table.concat(lines, '\n')
    if valid_utf8(text) then finish(lines); return end
  end
  if vim.fn.executable('python3') ~= 1 then
    callback(nil, '该格式或编码需要 python3，请先安装 Python 3'); return
  end
  local stdout, stderr = {}, {}
  local job = vim.fn.jobstart({ 'python3', helper, path }, {
    stdout_buffered = true, stderr_buffered = true,
    on_stdout = function(_, data) stdout = data end,
    on_stderr = function(_, data) stderr = data end,
    on_exit = function(_, code)
      if code ~= 0 then
        callback(nil, '书籍提取失败：' .. table.concat(stderr, '\n'))
      else
        local text = table.concat(stdout, '\n')
        finish(vim.split(text, '\n', { plain = true }))
      end
    end,
  })
  if job <= 0 then callback(nil, '无法启动书籍转换程序'); return end
  vim.notify('正在提取正文：' .. vim.fn.fnamemodify(path, ':t'), vim.log.levels.INFO, { title = 'moyu.nvim' })
  return job
end

return M
