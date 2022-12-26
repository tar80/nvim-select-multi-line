--------------------------------------------------------------------------------
-- Filename: nvim-select-multi-line
-- Author: tar80
-- License: MIT License
--------------------------------------------------------------------------------

if vim.g.loaded_sml then
  return
end

vim.g.loaded_sml = true

local sml = {}
local selected_lines = {}
local activate_sml, keep_selection, pre_direction
local namespace = vim.api.nvim_create_namespace("sml")

local function sml_notify(msg)
  print("[sml] " .. msg)
end

local function sort_keys(t)
  local keys = {}
  local n = 0
  for k,_ in pairs(t) do
    n = n + 1
    keys[n] = k
  end
  table.sort(keys,function(a,b)
    return tonumber(a) > tonumber(b)
  end)
  return keys
end

local function select_line()
  local contents = vim.fn.getline(".")
  local linenum = vim.fn.line(".")

  if selected_lines[linenum] ~= nil then
    vim.api.nvim_buf_del_extmark(0, namespace, selected_lines[linenum].ext_id)
    selected_lines[linenum] = nil
    return
  end

  local linelen = linenum == "" and 0 or vim.fn.strdisplaywidth(contents)
  local extid = vim.api.nvim_buf_set_extmark(0, namespace, linenum - 1, 0, {
    end_line = linenum - 1,
    end_col = linelen,
    hl_group = "Visual",
  })
  selected_lines[linenum] = {ext_id = extid, contents = contents}
end

local function cursor_move(direction)
  if pre_direction ~= nil and pre_direction ~= direction then
    select_line()
    vim.fn.cursor(vim.fn.line(".") + direction, vim.fn.col("."))
    return
  end
    vim.fn.cursor(vim.fn.line(".") + direction, vim.fn.col("."))
    select_line()
end

local function release_selection()
    vim.keymap.del("n", "j")
    vim.keymap.del("n", "k")
    keep_selection = nil
end

local function toggle_visual_mode_linewise()
  if keep_selection then
    release_selection()
    return sml_notify("Release visual-selection")
  end
  vim.keymap.set("n", "j", function()
    cursor_move(1)
  end)
  vim.keymap.set("n", "k", function()
    cursor_move(-1)
  end)
  keep_selection = true
  pre_direction = nil
  select_line()
  return sml_notify("Keep visual-selection")
end

local function yank_region()
  local lines = {}
  for _, v in pairs(selected_lines) do
    table.insert(lines, v.contents)
  end
  vim.api.nvim_command('let @"="' .. table.concat(lines, "\n"):gsub('"', '\\"') .. '"')
  sml.stop("Yanked region")
end

local function delete_region()
  local lines = sort_keys(selected_lines)
  for _, n in ipairs(lines) do
    vim.api.nvim_command(n .. "delete")
  end
  sml.stop()
end

function sml.start()
  if activate_sml then
    return sml.stop("Stop")
  end
  activate_sml = true
  keep_selection = nil
  vim.keymap.set("n", "v", function()
    select_line()
  end)
  vim.keymap.set("n", "V", function()
    toggle_visual_mode_linewise()
  end)
  vim.keymap.set("n", "y", function()
    yank_region()
  end)
  vim.keymap.set("n", "d", function()
    delete_region()
  end)
  vim.keymap.set("n", "<C-c>", function()
    sml.stop()
  end)
  vim.keymap.set("n", "<Esc>", function()
    sml.stop()
  end)
  return sml_notify("Start")
end

function sml.stop(msg)
  activate_sml = nil
  vim.keymap.del("n", "v")
  vim.keymap.del("n", "V")
  vim.keymap.del("n", "y")
  vim.keymap.del("n", "d")
  vim.keymap.del("n", "<C-c>")
  vim.keymap.del("n", "<Esc>")
  if keep_selection then
    release_selection()
  end
  selected_lines = {}
  vim.api.nvim_buf_clear_namespace(0, namespace, 0, -1)
  return msg and sml_notify(msg) or vim.cmd[[echo]]
end

return sml
