local M = {}
local Background = {}
Background.__index = Background

local extensions = {}
for _, extension in ipairs({ 'lua', 'vim', 'py', 'js', 'jsx', 'ts', 'tsx', 'vue', 'svelte',
  'java', 'kt', 'kts', 'go', 'rs', 'c', 'h', 'cc', 'cpp', 'hpp', 'cs', 'rb', 'php',
  'sh', 'zsh', 'bash', 'html', 'css', 'scss', 'sql', 'swift', 'scala', 'ex', 'exs' }) do
  extensions[extension] = true
end
local excluded = { ['.git'] = true, node_modules = true, target = true, dist = true,
  build = true, vendor = true, ['.venv'] = true, __pycache__ = true }

local function code_file(path)
  return extensions[path:match('%.([^./]+)$')] == true
end

local function canonical(path)
  return vim.loop.fs_realpath(path) or vim.fn.fnamemodify(path, ':p')
end

function M.new(window, buffer)
  return setmetatable({ win = window, original = buffer, created = {},
    view = vim.api.nvim_win_call(window, vim.fn.winsaveview) }, Background)
end

-- Build a bounded pool once per session. Unnamed buffers have no project to scan.
function Background:discover()
  local paths, seen = {}, {}
  local function add(path, original)
    if #paths >= 40 or path == '' or (not original and not code_file(path)) then return end
    path = canonical(path)
    if not seen[path] and vim.fn.filereadable(path) == 1 then
      seen[path] = true
      paths[#paths + 1] = path
    end
  end
  local source = vim.api.nvim_buf_get_name(self.original)
  add(source, true)
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buffer].buflisted and vim.bo[buffer].buftype == '' then
      add(vim.api.nvim_buf_get_name(buffer))
    end
  end
  if source ~= '' then
    local root = vim.fn.fnamemodify(source, ':p:h')
    local marker = vim.fs.find({ '.git', 'package.json', 'pyproject.toml', 'go.mod', 'Cargo.toml', 'pom.xml' }, {
      path = root, upward = true, limit = 1,
    })[1]
    if marker then root = vim.fn.fnamemodify(marker, ':h') end
    local queue, index, inspected = { { path = root, depth = 0 } }, 1, 0
    while index <= #queue and #paths < 40 and inspected < 2000 do
      local item = queue[index]
      index = index + 1
      local scan = vim.loop.fs_scandir(item.path)
      while scan and #paths < 40 and inspected < 2000 do
        local name, kind = vim.loop.fs_scandir_next(scan)
        if not name then break end
        inspected = inspected + 1
        local path = item.path .. '/' .. name
        if kind == 'file' then add(path)
        elseif kind == 'directory' and item.depth < 3 and name:sub(1, 1) ~= '.' and not excluded[name] then
          queue[#queue + 1] = { path = path, depth = item.depth + 1 }
        end
      end
    end
  end
  self.paths = paths
end

function Background:next(current)
  if not self.paths then self:discover() end
  local current_path = vim.api.nvim_buf_get_name(current)
  current_path = current_path ~= '' and canonical(current_path) or ''
  local start = 0
  for index, path in ipairs(self.paths) do
    if path == current_path then start = index; break end
  end
  for offset = 1, #self.paths do
    local path = self.paths[(start + offset - 1) % #self.paths + 1]
    if path ~= current_path and vim.fn.filereadable(path) == 1 then
      local existing = vim.fn.bufnr(path)
      local buffer = existing >= 0 and existing or vim.fn.bufadd(path)
      if existing < 0 then self.created[buffer] = true end
      local ok = pcall(vim.fn.bufload, buffer)
      if ok and vim.api.nvim_buf_is_loaded(buffer) and vim.bo[buffer].buftype == '' then
        return buffer
      end
    end
  end
end

function Background:show(buffer)
  -- :hide preserves unsaved buffers even when 'hidden' is off. Numeric buffer
  -- IDs avoid treating file names as commands; keepalt/keepjumps preserve editing.
  local current = vim.api.nvim_win_get_buf(self.win)
  local hidden = vim.bo[current].bufhidden
  vim.bo[current].bufhidden = 'hide'
  local ok = pcall(vim.api.nvim_win_call, self.win, function()
    vim.cmd('keepalt keepjumps hide buffer ' .. buffer)
  end)
  if vim.api.nvim_buf_is_valid(current) then vim.bo[current].bufhidden = hidden end
  return ok
end

function Background:restore()
  if vim.api.nvim_win_is_valid(self.win) and vim.api.nvim_buf_is_valid(self.original) then
    if self:show(self.original) then
      pcall(vim.api.nvim_win_call, self.win, function() vim.fn.winrestview(self.view) end)
    end
  end
  for buffer in pairs(self.created) do
    if vim.api.nvim_buf_is_valid(buffer) and not vim.bo[buffer].modified and #vim.fn.win_findbuf(buffer) == 0 then
      pcall(vim.api.nvim_buf_delete, buffer, {})
    end
  end
end

return M
