https://github.com/junegunn/fzf/blob/master/README-VIM.md#fzfrun
fzf# 替换成了skim#
FZF 替换成了SK

这是不用skim.vim插件, 只有skim目录下的这个文件的使用说明?
    /data2/wf2/leo_tools/skim/plugin/skim.vim


- If you're looking for more such commands,
        check out [skim.vim] project.


SK Vim integration
===================

Installation
------------

Once you have fzf installed, you can enable it inside Vim simply by adding the
directory to `&runtimepath` in your Vim configuration file. The path may
differ depending on the package manager.

```vim
" If installed using Homebrew
set rtp+=/usr/local/opt/fzf

" If installed using git
set rtp+=~/.fzf
```

If you use [vim-plug](https://github.com/junegunn/vim-plug), the same can be  written as:
```vim
" If installed using Homebrew
Plug '/usr/local/opt/fzf'

" If installed using git
Plug '~/.fzf'
```

But if you want the latest Vim plugin file from GitHub rather than the one
included in the package, write:

```vim
Plug 'junegunn/fzf'
```

The Vim plugin
will pick up fzf binary available on the system.
If fzf is not  found on `$PATH`,
it will ask you if it should download the latest binary for  you.

To make sure that you have the latest version of the binary, set up
post-update hook like so:

```vim
Plug 'junegunn/fzf', { 'do': { -> skim#install() } }
```

Summary
-------

The Vim plugin of fzf provides
    two core functions,
    and `:SK` command which
        is the basic file selector command built on top of them.

1. **`skim#run([spec dict])`**
    - Starts fzf inside Vim with the given spec
    - `:call skim#run({'source': 'ls'})`

2. **`skim#wrap([spec dict]) -> (dict)`**
    - Takes a spec for `skim#run` and returns an extended version of it with
      additional options for addressing global preferences (`g:fzf_xxx`)
        - `:echo skim#wrap({'source': 'ls'})`

    - We usually *wrap* a spec with `skim#wrap` before passing it to `skim#run`
        - `:call skim#run(skim#wrap({'source': 'ls'}))`

3. **`:SK [fzf_options string] [path string]`**
        - Basic fuzzy file selector
        - A reference implementation for those who don't want to write VimScript
          to implement custom commands
        - If you're looking for more such commands,
             check out [fzf.vim](https://github.com/junegunn/fzf.vim) project.


The most important of all is `skim#run`,
but it would be easier to understand the whole if we start off with `:SK` command.

`:SK[!]`
---------

```vim
" Look for files under current directory
    :SK

" Look for files under your home directory
    :SK ~

" With fzf command-line options
    :SK --reverse --info=inline /tmp

" Bang version starts fzf in fullscreen mode
:SK!
```

Similarly to [ctrlp.vim](  https://github.com/kien/ctrlp.vim)  ,
use enter key,
`CTRL-T`,
`CTRL-X` or `CTRL-V` to open selected files in the current window,
in new tabs,
in horizontal splits,
or in vertical splits respectively.

Note that the environment variables
`SK_DEFAULT_COMMAND` and
`SK_DEFAULT_OPTS` also apply here.

### Configuration

- `g:skim_action`
    - Customizable extra key bindings for opening selected files in different ways

- `g:skim_layout`
    - Determines the size and position of skim window

- `g:skim_colors`
    - Customizes skim colors to match the current color scheme

- `g:skim_history_dir`
    - Enables history feature

#### Examples

```vim
" This is the default extra key bindings
let g:skim_action = {
  \ 'ctrl-t': 'tab split',
  \ 'ctrl-x': 'split',
  \ 'ctrl-v': 'vsplit' }

" An action can be a reference to a function that processes selected lines

function! s:build_quickfix_list(lines)
    call setqflist(map(copy(a:lines), '{ "filename": v:val }'))
    copen
    cc
endfunction

let g:skim_action = {
    \ 'ctrl-q': function('s:build_quickfix_list'),
    \ 'ctrl-t': 'tab split',
    \ 'ctrl-x': 'split',
    \ 'ctrl-v': 'vsplit' }

" Default skim layout
    " - Popup window (center of the screen)
    let g:skim_layout = { 'window': { 'width': 0.9, 'height': 0.6 } }

    " - Popup window (center of the current window)
    let g:skim_layout = { 'window': { 'width': 0.9, 'height': 0.6, 'relative': v:true } }

    " - Popup window (anchored to the bottom of the current window)
    let g:skim_layout = { 'window': { 'width': 0.9, 'height': 0.6, 'relative': v:true, 'yoffset': 1.0 } }

    " - down / up / left / right
    let g:skim_layout = { 'down': '40%' }

    " - Window using a Vim command
        let g:skim_layout = { 'window': 'enew' }
        let g:skim_layout = { 'window': '-tabnew' }
        let g:skim_layout = { 'window': '10new' }

" Customize skim colors to match your color scheme
" - skim#wrap translates this to a set of `--color` options
let g:skim_colors =
\ { 'fg':      ['fg', 'Normal'],
  \ 'bg':      ['bg', 'Normal'],
  \ 'hl':      ['fg', 'Comment'],
  \ 'fg+':     ['fg', 'CursorLine', 'CursorColumn', 'Normal'],
  \ 'bg+':     ['bg', 'CursorLine', 'CursorColumn'],
  \ 'hl+':     ['fg', 'Statement'],
  \ 'info':    ['fg', 'PreProc'],
  \ 'border':  ['fg', 'Ignore'],
  \ 'prompt':  ['fg', 'Conditional'],
  \ 'pointer': ['fg', 'Exception'],
  \ 'marker':  ['fg', 'Keyword'],
  \ 'spinner': ['fg', 'Label'],
  \ 'header':  ['fg', 'Comment'] }

" Enable per-command history
" - History files will be stored in the specified directory
" - When set, CTRL-N and CTRL-P will be bound to 'next-history' and
"   'previous-history' instead of 'down' and 'up'.
let g:skim_history_dir = '~/.local/share/skim-history'
```

##### Explanation of `g:skim_colors`

`g:skim_colors` is a dictionary mapping skim elements to a color specification
list:

    element: [ component, group1 [, group2, ...] ]

- `element` is an skim element to apply a color to:

  | Element                     | Description                                           |
  | ---                         | ---                                                   |
  | `fg`  / `bg`  / `hl`        | Item (foreground / background / highlight)            |
  | `fg+` / `bg+` / `hl+`       | Current item (foreground / background / highlight)    |
  | `preview-fg` / `preview-bg` | Preview window text and background                    |
  | `hl`  / `hl+`               | Highlighted substrings (normal / current)             |
  | `gutter`                    | Background of the gutter on the left                  |
  | `pointer`                   | Pointer to the current line (`>`)                     |
  | `marker`                    | Multi-select marker (`>`)                             |
  | `border`                    | Border around the window (`--border` and `--preview`) |
  | `header`                    | Header (`--header` or `--header-lines`)               |
  | `info`                      | Info line (match counters)                            |
  | `spinner`                   | Streaming input indicator                             |
  | `query`                     | Query string                                          |
  | `disabled`                  | Query string when search is disabled                  |
  | `prompt`                    | Prompt before query (`> `)                            |
  | `pointer`                   | Pointer to the current line (`>`)                     |

- `component` specifies the component (`fg` / `bg`) from which to extract the
  color when considering each of the following highlight groups

- `group1 [, group2, ...]` is a list of highlight groups that are searched (in
  order) for a matching color definition

For example, consider the following specification:

```vim
  'prompt':  ['fg', 'Conditional', 'Comment'],
```

This means we color the **prompt**
- using the `fg` attribute of the `Conditional` if it exists,
- otherwise use the `fg` attribute of the `Comment` highlight group if it exists,
- otherwise fall back to the default color settings for the **prompt**.

You can examine the color option generated according the setting by printing
the result of `skim#wrap()` function like so:

```vim
:echo skim#wrap()
```

`skim#run`
---------

`skim#run()` function is the core of Vim integration.
It takes a single
dictionary argument, *a spec*, and starts skim process accordingly.
At the very  least,
    specify `sink` option to
    tell what it should do with the selected  entry.

```
    call skim#run({'sink': 'e'})
```

We haven't specified the `source`,
so this is equivalent to starting skim on  command line
without standard input pipe;
skim will use find command (or  `$SK_DEFAULT_COMMAND` if defined)
to list the files under the current  directory.
When you select one,
it will open it with the sink, `:e` command.
If you want to open it in a new tab,
you can pass `:tabedit` command instead  as the sink.

```vim
call skim#run({'sink': 'tabedit'})
    ```

Instead of using the default find command, you can use any shell command as
the source. The following example will list the files managed by git. It's
equivalent to running `git ls-files | skim` on shell.

```vim
call skim#run({'source': 'git ls-files', 'sink': 'e'})
```

skim options can be specified as `options` entry in spec dictionary.

```vim
call skim#run({'sink': 'tabedit', 'options': '--multi --reverse'})
```

You can also pass a layout option if you don't want skim window to take up the
entire screen.

```vim
" up / down / left / right / window are allowed
call skim#run({'source': 'git ls-files', 'sink': 'e', 'left': '40%'})
call skim#run({'source': 'git ls-files', 'sink': 'e', 'window': '30vnew'})
```

`source` doesn't have to be an external shell command, you can pass a Vim
array as the source. In the next example, we pass the names of color
schemes as the source to implement a color scheme selector.

```vim
call skim#run({'source': map(split(globpath(&rtp, 'colors/*.vim')),
            \               'fnamemodify(v:val, ":t:r")'),
            \ 'sink': 'colo', 'left': '25%'})
```

The following table summarizes the available options.

source和sink  有点像 微积分里的源点 和 汇点

Option name                  | Type          | Description                                                           
------------------------     | ------------- | ----------------------------------------------------------------      
`source`                       | - string      |  external command generating something   (e.g. `find .`)             
(Input to skim )             | - list        |  Vim list                                               


How to handle selected item 
`sink`                         | - string      | Vim command    (e.g. `e`, `tabedit`).            
                             | - funcref     | funcref                                                                       
`sinkS`                        | funcref       |  takes the list of output lines at once         


`options`                      | string/list   | Options to skim                                                        
`dir`                          | string        | Working directory                                                     

layout
`up`/`down`/`left`/`right`           | number/string |  Window position and size (e.g. `20`, `50%`)                  
`window`                       | - string      |  Command to open skim window (e.g. `vertical aboveleft 30new`) 
                             | - dict        |  Popup window settings (e.g. `{'width': 0.9, 'height': 0.6}`) 
`tmux`                         | string        |  skim-tmux options (e.g. `-p90%,60%`)                          



`options` entry can be either
        a string or a list.
    For simple cases, string  should suffice,
        but prefer to use list type to avoid escaping issues.

```vim
call skim#run({'options': '--reverse --prompt "C:\\Program Files\\"'})
call skim#run({'options': ['--reverse', '--prompt', 'C:\Program Files\']})
```

When `window` entry is a dictionary,
    skim will start in a popup window.
    The  following options are allowed:

- Required:
    - `width` [float range [0 ~ 1]] or [integer range [8 ~ ]]
    - `height` [float range [0 ~ 1]] or [integer range [4 ~ ]]
- Optional:
    - `yoffset` [float default 0.5 range [0 ~ 1]]
    - `xoffset` [float default 0.5 range [0 ~ 1]]
    - `relative` [boolean default v:false]
    - `border` [string default `rounded`]: Border style
        - `rounded` / `sharp` / `horizontal` / `vertical` / `top` / `bottom` / `left` / `right` / `no[ne]`


`skim#wrap`
----------

We have seen that several aspects of `:SK` command can be configured with
a set of global option variables; different ways to open files
(`g:skim_action`), window position and size (`g:skim_layout`), color palette
(`g:skim_colors`), etc.

So how can we make our custom `skim#run` calls also respect those variables?
Simply by *"wrapping"* the spec dictionary with `skim#wrap` before passing it
to `skim#run`.

- **`skim#wrap([name string], [spec dict], [fullscreen bool]) -> (dict)`**
    - All arguments are optional. Usually we only need to pass a spec dictionary.
    - `name` is for managing history files. It is ignored if
      `g:skim_history_dir` is not defined.
    - `fullscreen` can be either `0` or `1` (default: 0).

`skim#wrap` takes a spec and returns an extended version of it (also
a dictionary) with additional options for addressing global preferences. You
can examine the return value of it like so:

```vim
echo skim#wrap({'source': 'ls'})
```

After we *"wrap"* our spec, we pass it to `skim#run`.

```vim
call skim#run(skim#wrap({'source': 'ls'}))
```

Now it supports `CTRL-T`, `CTRL-V`, and `CTRL-X` key bindings (configurable
via `g:skim_action`) and it opens skim window according to `g:skim_layout`
setting.

To make it easier to use, let's define `LS` command.

```vim
command! LS call skim#run(skim#wrap({'source': 'ls'}))
```

Type `:LS` and see how it works.

We would like to make `:LS!` (bang version) open skim in fullscreen, just like
`:SK!`. Add `-bang` to command definition, and use `<bang>` value to set
the last `fullscreen` argument of `skim#wrap` (see `:help <bang>`).

```vim
" On :LS!, <bang> evaluates to '!', and '!0' becomes 1
command! -bang LS call skim#run(skim#wrap({'source': 'ls'}, <bang>0))
```

Our `:LS` command will be much more useful if we can pass a directory argument
to it, so that something like `:LS /tmp` is possible.

```vim
command! -bang -complete=dir -nargs=? LS
    \ call skim#run(skim#wrap({'source': 'ls', 'dir': <q-args>}, <bang>0))
```

Lastly, if you have enabled `g:skim_history_dir`, you might want to assign
a unique name to our command and pass it as the first argument to `skim#wrap`.

```vim
" The query history for this command will be stored as 'ls' inside g:skim_history_dir.
" The name is ignored if g:skim_history_dir is not defined.
command! -bang -complete=dir -nargs=? LS
    \ call skim#run(skim#wrap('ls', {'source': 'ls', 'dir': <q-args>}, <bang>0))
```

### Global options supported by `skim#wrap`

- `g:skim_layout`
- `g:skim_action`
    - **Works only when no custom `sink` (or `sinkS`) is provided**
        - Having custom sink usually means that each entry is not an ordinary
          file path (e.g. name of color scheme), so we can't blindly apply the
          same strategy (i.e. `tabedit some-color-scheme` doesn't make sense)
- `g:skim_colors`
- `g:skim_history_dir`

Tips
----

### skim inside terminal buffer

On the latest versions of Vim and Neovim, skim will start in a terminal buffer.
If you find the default ANSI colors to be different, consider configuring the
colors using `g:terminal_ansi_colors` in regular Vim or `g:terminal_color_x`
in Neovim.

```vim
" Terminal colors for seoul256 color scheme
if has('nvim')
  let g:terminal_color_0 = '#4e4e4e'
  let g:terminal_color_1 = '#d68787'
  let g:terminal_color_2 = '#5f865f'
  let g:terminal_color_3 = '#d8af5f'
  let g:terminal_color_4 = '#85add4'
  let g:terminal_color_5 = '#d7afaf'
  let g:terminal_color_6 = '#87afaf'
  let g:terminal_color_7 = '#d0d0d0'
  let g:terminal_color_8 = '#626262'
  let g:terminal_color_9 = '#d75f87'
  let g:terminal_color_10 = '#87af87'
  let g:terminal_color_11 = '#ffd787'
  let g:terminal_color_12 = '#add4fb'
  let g:terminal_color_13 = '#ffafaf'
  let g:terminal_color_14 = '#87d7d7'
  let g:terminal_color_15 = '#e4e4e4'
else
  let g:terminal_ansi_colors = [
    \ '#4e4e4e', '#d68787', '#5f865f', '#d8af5f',
    \ '#85add4', '#d7afaf', '#87afaf', '#d0d0d0',
    \ '#626262', '#d75f87', '#87af87', '#ffd787',
    \ '#add4fb', '#ffafaf', '#87d7d7', '#e4e4e4'
  \ ]
endif
```

### Starting skim in a popup window

```vim
" Required:
" - width [float range [0 ~ 1]] or [integer range [8 ~ ]]
" - height [float range [0 ~ 1]] or [integer range [4 ~ ]]
"
" Optional:
" - xoffset [float default 0.5 range [0 ~ 1]]
" - yoffset [float default 0.5 range [0 ~ 1]]
" - relative [boolean default v:false]
" - border [string default 'rounded']: Border style
"   - 'rounded' / 'sharp' / 'horizontal' / 'vertical' / 'top' / 'bottom' / 'left' / 'right'
let g:skim_layout = { 'window': { 'width': 0.9, 'height': 0.6 } }
```

Alternatively, you can make skim open in a tmux popup window (requires tmux 3.2
or above) by putting skim-tmux options in `tmux` key.

```vim
" See `man skim-tmux` for available options
if exists('$TMUX')
  let g:skim_layout = { 'tmux': '-p90%,60%' }
else
  let g:skim_layout = { 'window': { 'width': 0.9, 'height': 0.6 } }
endif
```

### Hide statusline

When skim starts in a terminal buffer, the file type of the buffer is set to
`skim`. So you can set up `FileType skim` autocmd to customize the settings of
the window.

For example, if you open skim on the bottom on the screen (e.g. `{'down':
'40%'}`), you might want to temporarily disable the statusline for a cleaner
look.

```vim
let g:skim_layout = { 'down': '30%' }
autocmd! FileType skim
autocmd  FileType skim set laststatus=0 noshowmode noruler
  \| autocmd BufLeave <buffer> set laststatus=2 showmode ruler
```

[License](LICENSE)
------------------

The MIT License (MIT)

Copyright (c) 2013-2021 Junegunn Choi
