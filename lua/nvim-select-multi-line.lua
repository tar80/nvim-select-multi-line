--------------------------------------------------------------------------------
-- Filename: nvim-select-multi-line
-- Author: tar80
-- License: MIT License
--------------------------------------------------------------------------------

if vim.g.loaded_sml then
  return
end

vim.g.loaded_sml = true

local NAME_SPACE = "sml"

---@class sml
---@field start function activate sml
---@field stop function  deactivate sml
local sml = {}

---@class Selection
---@field private namespace integer namespace id
---@field private _init function
---@field private _ins function
---@field private _del function
---@field private _descending function
local Selection = {}

setmetatable(Selection, {
  __index = {
    namespace = vim.api.nvim_create_namespace(NAME_SPACE),

    _init = function(self)
      for i = 1, #self do
        self[i] = nil
      end

      self.last_line = 0
      vim.api.nvim_buf_clear_namespace(0, self.namespace, 0, -1)
    end,

    ---@param line number cursor line number
    _ins = function(self, line)
      local contents = vim.fn.getline(line)
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

---@class sml
---@field last_line number last line of file
---@field pre_direction number up/down cursor key information that was pressed immediately beforep
---@field keep_selection boolean continue selection on cursor movement
---@field _notify function
---@field _select function
---@field _yank function
---@field _delete function
---@field _selection_keys function
---@field _release_keys function
---@field _keys function
---@field _toggle_linewise function
local sml_mt = {
  last_line = 0,
  pre_direction = 0,
  keep_selection = false,
}

---@param message string hint message
function sml_mt:_notify(message)
  local header = ""

  if not package.loaded["notify"] then
    header = "[" .. NAME_SPACE .. "] "
  end

  vim.notify(header .. message, 2, { title = "nvim-select-multi-line" })
end

---@param n number specify line number
function sml_mt._select(n)
  local linenum = n or vim.fn.line(".")

  for index, value in ipairs(Selection) do
    if value.line_num == linenum then
      Selection:_del(index, value)
      return
    end
  end

  Selection:_ins(linenum)
end

function sml_mt:_yank()
  local tbl = {}

  for _, v in ipairs(Selection) do
    table.insert(tbl, v.contents)
  end

  vim.api.nvim_command('let @"="' .. table.concat(tbl, "\n"):gsub('"', '\\"') .. '"')
end

function sml_mt:_delete()
  local tbl = Selection:_descending()

  for _, n in ipairs(tbl) do
    vim.api.nvim_command(n .. "delete _")
  end

  self:stop()
end

function sml_mt:_selection_keys()
  self.keep_selection = true
  vim.api.nvim_create_user_command("SmlVisualMove", function(opts)
    local cursor_line = vim.fn.line(".")
    local count = opts.count == 0 and 1 or (opts.count + 1) - cursor_line
    local movespec = cursor_line + opts.args * count

    -- limit top and bottom of the number of lines
    if movespec < 1 then
      movespec = 1
    elseif movespec > self.last_line then
      movespec = self.last_line
    end

    vim.fn.cursor(movespec, vim.fn.col("."))

    -- adjusting when the cursor wraps up and down
    if self.pre_direction == 0 or self.pre_direction == opts.args then
      self.pre_direction = opts.args
      cursor_line = cursor_line + opts.args
    else
      movespec = movespec + opts.args * -1
    end

    for i = cursor_line, movespec, opts.args do
      self._select(i)
    end
  end, { count = true, nargs = 1 })

  vim.keymap.set("n", "j", ":SmlVisualMove +1<CR>", { silent = true })
  vim.keymap.set("n", "k", ":SmlVisualMove -1<CR>", { silent = true })
end

function sml_mt:_release_keys()
  self.keep_selection = false
  vim.api.nvim_del_user_command("SmlVisualMove")
  vim.keymap.del("n", "j")
  vim.keymap.del("n", "k")
end

function sml_mt:_keys()
  if vim.g.enable_sml then
    self.keep_selection = false
    vim.keymap.set("n", "v", function()
      self._select()
    end)
    vim.keymap.set("n", "V", function()
      self:_toggle_linewise()
    end)
    vim.keymap.set("n", "y", function()
      self:_yank()
      self:stop("Yank selection")
    end)
    vim.keymap.set("n", "d", function()
      self:_yank()
      self:_delete()
    end)
    vim.keymap.set("n", "<C-c>", function()
      self:stop()
    end)
    vim.keymap.set("n", "<Esc>", function()
      self:stop()
    end)
  else
    vim.keymap.del("n", "v")
    vim.keymap.del("n", "V")
    vim.keymap.del("n", "y")
    vim.keymap.del("n", "d")
    vim.keymap.del("n", "<C-c>")
    vim.keymap.del("n", "<Esc>")

    if sml_mt.keep_selection then
      sml_mt:_release_keys()
    end
  end
end

function sml_mt:_toggle_linewise()
  local msg

  if self.keep_selection then
    self:_release_keys()
    msg = "Release visual-selection"
  else
    self:_selection_keys()
    self.pre_direction = 0
    self._select()
    msg = "Keep visual-selection"
  end

  self:_notify(msg)
end

function sml.start()
  if vim.g.enable_sml then
    return sml:stop("Stop")
  end

  vim.g.enable_sml = true
  sml.keep_selection = false
  sml.last_line = vim.fn.line("$")
  sml:_keys()
  sml:_notify("Start")
end

---@param msg string hint message
function sml:stop(msg)
  vim.g.enable_sml = nil
  self:_keys()
  Selection:_init()

  if self.keep_selection then
    self:_release_keys()
  end

  if msg then
    self:_notify(msg)
  else
    vim.cmd([[echo]])
  end
end

setmetatable(sml, { __index = sml_mt })

return sml
