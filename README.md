
# Nvim Select Multi Lines

## Differences from the original

- Written in lua
- Remove `g:sml#echo_yank_str`
- Add `b:enable_sml` (This variable is set to `v:true` only when sml is enabled)
- Selection line can be toggled
- Yank reflecting the selected order
- Exit select mode can also be `<Esc>`
- Support [nvim-notify](https://github.com/rcarriga/nvim-notify)

## Usage

start sml

`require("nvim-select-multi-line").start()`

stop sml

`require("nvim-select-multi-line").stop()`

