--------------------------------------------------------------------------------
-- Filename: nvim-select-multi-line
-- Author: tar80
-- License: MIT License
--------------------------------------------------------------------------------

local NAMESPACE = "sml"

---@class sml
---@field start function activate sml
---@field stop function  deactivate sml
local sml = {}

---@class _inner
---@field last_line number last line of file
---@field pre_direction number up/down cursor key information that was pressed immediately beforep
---@field keep_selection boolean continue selection on cursor movement
---@field clipboard boolean when yank, also yanked to the clipboard
local _inner = {
  last_line = 0,
  pre_direction = 0,
  keep_selection = false,
  clipboard = false,
}

---@class selection
---@field private namespace integer namespace id
---@field private _init function
---@field private _ins function
---@field private _del function
---@field private _descending function
local selection = {}

setmetatable(selection, {
  __index = {
    namespace = vim.api.nvim_create_namespace(NAMESPACE),

    _init = function(self)
      for i = 1, #self do
        self[i] = nil
      end

      _inner.last_line = 0
      vim.api.nvim_buf_clear_namespace(0, self.namespace, 0, -1)
    end,

    ---@param line number cursor line number
    _ins = function(self, line)
      local contents = vim.api.nvim_get_current_line()
      local linelen = line == "" and 0 or vim.api.nvim_strwidth(contents)
      local extid = vim.api.nvim_buf_set_extmark(0, self.namespace, line - 1, 0, {
        end_line = line - 1,
        end_col = linelen,
        hl_group = "Visual",
      })
      table.insert(self, { ext_id = extid, line_num = line, contents = contents })
    end,

    ---@param index number element number of table(Selection)
    ---@param value table table(Selection)
    _del = function(self, index, value)
      vim.api.nvim_buf_del_extmark(0, self.namespace, value.ext_id)
      self[index] = {}
    end,

    ---@return table list of descending order
    _descending = function(self)
      local l = {}
      local n = 0

      for _, v in ipairs(self) do
        if not vim.tbl_isempty(v) then
          n = n + 1
          l[n] = v.line_num
        end
      end

      table.sort(l, function(a, b)
        return tonumber(a) > tonumber(b)
      end)

      return l
    end,
  },
})

---@param message string hint message
---@param errorlevel? number
local function notify(message, errorlevel)
  local header = ""
  local level = errorlevel or 2

  if not package.loaded["notify"] then
    header = "[" .. NAMESPACE .. "] "
  end

  vim.notify(header .. message, level, { title = "nvim-select-multi-line" })
end

---@package
---@param n? number specify line number
local function select_line(n)
  local linenum = n or vim.fn.line(".")

  for index, value in ipairs(selection) do
    if value.line_num == linenum then
      selection:_del(index, value)
      return
    end
  end

  selection:_ins(linenum)
end

---@package
---@param clipboard? boolean
local function yank_selection(clipboard)
  local tbl = {}

  for _, v in ipairs(selection) do
    table.insert(tbl, v.contents)
  end

  vim.api.nvim_command('let @"="' .. table.concat(tbl, "\n"):gsub('"', '\\"') .. '\n"')

  if clipboard then
    vim.api.nvim_command('let @* = @"')
  end
end

---@package
local function delete_selection()
  local tbl = selection:_descending()

  for _, n in ipairs(tbl) do
    vim.api.nvim_command(n .. "delete _")
  end

  sml:stop()
end

---@package
---@param mode string specify map mode
---@param key string specify map key
local function del_map(mode, key)
  if vim.fn.maparg(key, mode) == "" then
    return
  end

  vim.keymap.del(mode, key)
end

---@package
local function selection_keys()
  _inner.keep_selection = true
  vim.api.nvim_create_user_command("SmlVisualMove", function(opts)
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local count = opts.count == 0 and 1 or (opts.count + 1) - row
    local movespec = row + opts.args * count

    -- limit top and bottom of the number of lines
    if movespec < 1 then
      movespec = 1
    elseif movespec > _inner.last_line then
      movespec = _inner.last_line
    end

    vim.api.nvim_win_set_cursor(0, { movespec, col })

    -- adjusting when the cursor wraps up and down
    if _inner.pre_direction == 0 or _inner.pre_direction == opts.args then
      _inner.pre_direction = opts.args
      row = row + opts.args
    else
      movespec = movespec + opts.args * -1
    end

    for i = row, movespec, opts.args do
      select_line(i)
    end
  end, { count = true, nargs = 1 })

  vim.keymap.set("n", "j", ":SmlVisualMove +1<CR>", { silent = true })
  vim.keymap.set("n", "k", ":SmlVisualMove -1<CR>", { silent = true })
end

---@package
local function release_keys()
  _inner.keep_selection = false
  vim.api.nvim_del_user_command("SmlVisualMove")
  del_map("n", "j")
  del_map("n", "k")
end

---@package
local function toggle_linewise()
  local msg

  if _inner.keep_selection then
    release_keys()
    msg = "Release visual-selection"
  else
    selection_keys()
    _inner.pre_direction = 0
    select_line()
    msg = "Keep visual-selection"
  end

  notify(msg)
end

---@package
local function additional_keys()
  if vim.g.enable_sml then
    _inner.keep_selection = false
    vim.keymap.set("n", "v", function()
      select_line()
    end)
    vim.keymap.set("n", "V", function()
      toggle_linewise()
    end)
    vim.keymap.set("n", "y", function()
      yank_selection(_inner.clipboard)
      sml:stop("Yank selection")
    end)
    vim.keymap.set("n", "d", function()
      yank_selection()
      delete_selection()
    end)
    vim.keymap.set("n", "<C-c>", function()
      sml:stop()
    end)
    vim.keymap.set("n", "<Esc>", function()
      sml:stop()
    end)
  else
    del_map("n", "v")
    del_map("n", "V")
    del_map("n", "y")
    del_map("n", "d")
    del_map("n", "<C-c>")
    del_map("n", "<Esc>")

    if _inner.keep_selection then
      release_keys()
    end
  end
end

function sml.start()
  if vim.g.enable_sml then
    return sml:stop("Stop")
  end

  vim.g.enable_sml = true
  _inner.last_line = vim.fn.line("$")
  additional_keys()
  notify("Start")
end

---@param msg string hint message
function sml:stop(msg)
  vim.g.enable_sml = nil
  additional_keys()
  selection:_init()

  if msg then
    notify(msg)
  else
    vim.api.nvim_command("echo")
  end
end

---@param bool boolean
function sml.clipboard(bool)
  _inner.clipboard = bool
end

setmetatable(sml, {
  ---@param name string new field name
  __newindex = function(_, name)
    notify("'" .. name .. "' is protected", 3)
  end,
})

return sml
