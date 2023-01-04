
# Nvim Select Multi Lines

## Differences from the original

- Written in lua
- Remove `g:sml#echo_yank_str`
- Add `g:enable_sml` (this variable is set to `v:true` only when sml is enabled)
- Selection line can be toggled
- Counter operator available in keep-visual-selection mode
- Yank reflecting the selected order
- It can be copied to the clipboard during yank if necessary
- Exit select mode can also be `<Esc>`
- Support [nvim-notify](https://github.com/rcarriga/nvim-notify)

## Installation

packer  

```
use({ "tar80/nvim-select-multi-line", branch = "tar80" })
```

### Settings

If true, also copy to clipboard when yanking  

`require("nvim-select-multi-line").clipboard(true)`

### Usage

start sml  

`require("nvim-select-multi-line").start()`

stop sml  

`require("nvim-select-multi-line").stop()`

