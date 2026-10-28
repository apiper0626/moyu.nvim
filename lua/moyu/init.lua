local M = {}
local config = { width = 0.65, height = 0.7, border = 'rounded', title = ' 阅读 ', book_dir = '~/Books/moyu' }
local state = { books = {} }
local win, buf, current
local state_file
local stealth = require('moyu.stealth')
local stealth_options = { lines = 8, keys_per_step = 3 }
local formats = require('moyu.formats')
local request, pending = 0, nil
local progress_info = require('moyu.progress')
local current_lines

local function valid_win() return win and vim.api.nvim_win_is_valid(win) end
local function notify(message) vim.notify(message, vim.log.levels.WARN, { title = 'moyu.nvim' }) end

local function load()
  if state_file then return end
  state_file = vim.fn.stdpath('data') .. '/moyu/progress.json'
  if vim.fn.filereadable(state_file) == 1 then
    local ok, value = pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(state_file), '\n')) end)
    if ok and type(value) == 'table' and type(value.books) == 'table' then state = value end
  end
end

local function save()
  load()
  if current and valid_win() then
    local book = type(state.books[current]) == 'table' and state.books[current] or {}
    local line = vim.api.nvim_win_get_cursor(win)[1]
    if book.line ~= line then book.stealth = nil end
    book.line, book.updated = line, os.time()
    if current_lines then book.percent = progress_info.percent(current_lines, book.stealth or { line = line, char = 0 }) end
    state.books[current] = book
    state.last = current
  end
  local ok, err = pcall(function()
    vim.fn.mkdir(vim.fn.fnamemodify(state_file, ':h'), 'p')
    vim.fn.writefile({ vim.json.encode(state) }, state_file .. '.tmp')
    assert(vim.fn.rename(state_file .. '.tmp', state_file) == 0, '无法保存阅读进度')
  end)
  if not ok then notify(tostring(err)) end
end

local function geometry()
  local columns, rows = vim.o.columns, math.max(1, vim.o.lines - vim.o.cmdheight - 2)
  local width = math.max(1, math.min(columns - 2, math.floor(columns * config.width)))
  local height = math.max(1, math.min(rows - 2, math.floor(rows * config.height)))
  return { relative = 'editor', width = width, height = height,
    col = math.max(0, math.floor((columns - width) / 2) - 1),
    row = math.max(0, math.floor((rows - height) / 2) - 1),
    style = 'minimal', border = config.border, title = config.title, title_pos = 'center' }
end

function M.setup(opts)
  opts = vim.deepcopy(opts or {})
  stealth_options = vim.tbl_extend('force', stealth_options, opts.stealth or {})
  opts.stealth = nil
  config = vim.tbl_extend('force', config, opts or {})
  for _, key in ipairs({ 'width', 'height' }) do
    assert(type(config[key]) == 'number' and config[key] > 0 and config[key] <= 1, key .. ' 必须在 0 到 1 之间')
  end
  for _, key in ipairs({ 'lines', 'keys_per_step' }) do
    local value = stealth_options[key]
    assert(type(value) == 'number' and value >= 1 and value % 1 == 0, 'stealth.' .. key .. ' 必须是正整数')
  end
end

function M.close()
  request = request + 1
  if pending then pcall(vim.fn.jobstop, pending); pending = nil end
  stealth.close()
  if not valid_win() then return end
  save()
  local old = win
  win = nil
  vim.api.nvim_win_close(old, true)
end

local function read_book(path, callback)
  M.close()
  local token = request
  local origin, buffer = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
  local job = formats.read(path, function(lines, err)
    if token ~= request then return end
    pending = nil
    if err then notify(err); return end
    if not vim.api.nvim_win_is_valid(origin) or vim.api.nvim_get_current_win() ~= origin
      or vim.api.nvim_win_get_buf(origin) ~= buffer then return end
    callback(lines)
  end)
  if job then pending = job end
end

function M.stealth(path)
  load()
  path = path or current or state.last
  if not path then M.books(M.stealth); return end
  path = vim.fn.fnamemodify(path, ':p')
  read_book(path, function(lines)
    local progress = state.books[path]
    progress = type(progress) == 'table' and progress or {}
    local pos = type(progress.stealth) == 'table' and progress.stealth or { line = progress.line or 1, char = 0 }
    local opened = stealth.open(lines, pos, stealth_options, function(value)
      local book = type(state.books[path]) == 'table' and state.books[path] or {}
      book.stealth, book.line, book.updated = value, value.line, os.time()
      book.percent = progress_info.percent(lines, value)
      state.books[path], state.last = book, path
      save()
    end, { history = M.history })
    if opened then current, current_lines = path, lines end
  end)
end

function M.stealth_toggle()
  if stealth.active() then stealth.close() else M.stealth() end
end

function M.open(path)
  load()
  path = path or current or state.last
  if not path then M.books(M.open); return end
  path = vim.fn.fnamemodify(path, ':p')
  read_book(path, function(lines)
    current, current_lines = path, lines
    buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = 'wipe'
    vim.bo[buf].swapfile = false
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    win = vim.api.nvim_open_win(buf, true, geometry())
    vim.wo[win].wrap = true
    vim.wo[win].linebreak = true
    vim.wo[win].number = false
    vim.wo[win].relativenumber = false
    vim.wo[win].cursorline = false
    vim.wo[win].scrolloff = 2
    local progress = state.books[path]
    local line = type(progress) == 'table' and tonumber(progress.line) or 1
    line = math.max(1, math.min(#lines > 0 and #lines or 1, line or 1))
    vim.api.nvim_win_set_cursor(win, { line, 0 })
    for _, key in ipairs({ 'q', '<Esc>', '<leader>q' }) do
      vim.keymap.set('n', key, M.close, { buffer = buf, silent = true, desc = '保存进度并隐藏阅读窗口' })
    end
    for key, action in pairs({ j = 'gj', k = 'gk', ['<Down>'] = 'gj', ['<Up>'] = 'gk', ['<Space>'] = '<C-f>', ['<BS>'] = '<C-b>' }) do
      vim.keymap.set('n', key, action, { buffer = buf, silent = true })
    end
    vim.keymap.set('n', 'B', function() M.books(M.open) end, { buffer = buf, desc = '书架' })
    vim.api.nvim_create_autocmd({ 'CursorMoved', 'BufLeave' }, { buffer = buf, callback = save })
    vim.api.nvim_create_autocmd('WinClosed', { pattern = tostring(win), once = true, callback = function() win = nil end })
    save()
  end)
end

function M.toggle()
  M.stealth_toggle()
end

function M.is_active() return stealth.active() end

function M.status() return stealth.active() and '鱼' or '' end

function M.float_toggle()
  if stealth.active() then stealth.close(); return end
  if valid_win() then M.close() else M.open() end
end

function M.history()
  M.close()
  load()
  local paths = {}
  for path, item in pairs(state.books) do
    if type(item) == 'table' then paths[#paths + 1] = path end
  end
  table.sort(paths, function(a, b)
    local left, right = tonumber(state.books[a].updated) or 0, tonumber(state.books[b].updated) or 0
    return left == right and a < b or left > right
  end)
  if #paths == 0 then notify('暂无阅读历史'); return end
  require('moyu.picker').select(paths, function(path)
    local book = state.books[path]
    local date = os.date('%Y-%m-%d %H:%M', tonumber(book.updated) or 0)
    return vim.fn.fnamemodify(path, ':t') .. ' · ' .. tostring(book.percent or '?') .. '% · 第 '
      .. tostring(book.line or 1) .. ' 行 · ' .. date
      .. (vim.fn.filereadable(path) == 1 and '' or ' [文件不存在]') .. '  ' .. path
  end, M.stealth)
end

function M.books(on_select)
  M.close()
  load()
  local paths, seen = {}, {}
  local function add(path)
    path = vim.fn.fnamemodify(path, ':p')
    if not seen[path] and formats.supported(path) and vim.fn.filereadable(path) == 1 then
      paths[#paths + 1] = path; seen[path] = true
    end
  end
  for path in pairs(state.books) do add(path) end
  if config.book_dir then
    for _, path in ipairs(vim.fn.globpath(vim.fn.expand(config.book_dir), '**/*', false, true)) do add(path) end
  end
  table.sort(paths)
  if #paths == 0 then
    notify('书架为空，请将书籍放入 ' .. vim.fn.expand(config.book_dir)
      .. '，或设置 book_dir / 使用 :Moyu /路径/书籍 打开文件')
    return
  end
  require('moyu.picker').select(paths, function(path)
    local item = state.books[path]
    return vim.fn.fnamemodify(path, ':t') .. (item and (' · 第 ' .. tostring(item.line) .. ' 行') or '') .. '  ' .. path
  end, on_select or M.stealth)
end

local group = vim.api.nvim_create_augroup('Moyu', { clear = true })
vim.api.nvim_create_autocmd('VimLeavePre', { group = group, callback = function() if current then save() end end })
vim.api.nvim_create_autocmd('VimResized', { group = group, callback = function()
  if valid_win() then vim.api.nvim_win_set_config(win, geometry()) end
end })
return M
