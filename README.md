fzf :heart: vim
===============

A set of [fzf][fzf]-based Vim commands and mappings.

Rationale
---------

[fzf][fzf] in itself is not a Vim plugin, and the official repository only
provides the [basic wrapper function][run] for Vim and it's up to the users to
write their own Vim commands with it. However, I've learned that many users of
fzf are not familiar with Vimscript and are looking for the "default"
implementation of the features they can find in the alternative Vim plugins.

This repository is a bundle of fzf-based commands and mappings extracted from
my [.vimrc][vimrc] to address such needs. They are *not* designed to be
flexible or configurable, nor are not guaranteed to be backward-compatible at
the moment, so you might want to treat this repository as a reference.

Installation
------------

Using [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': 'yes \| ./install' }
Plug 'junegunn/fzf.vim'
```

Commands
--------

| Command          | List                                                                      |
| ---              | ---                                                                       |
| `Files [PATH]`   | Files (similar to `:FZF`)                                                 |
| `Buffers`        | Open buffers                                                              |
| `Colors`         | Color schemes                                                             |
| `Ag [PATTERN]`   | [ag][ag] search result (`CTRL-A` to select all, `CTRL-D` to deselect all) |
| `Lines`          | Lines in loaded buffers                                                   |
| `BLines`         | Lines in the current buffer                                               |
| `Marks`          | Marks                                                                     |
| `Tags`           | Tags in the project (`ctags -R`)                                          |
| `BTags`          | Tags in the current buffer                                                |
| `Locate PATTERN` | `locate` command output                                                   |
| `History`        | `v:oldfiles` and open buffers                                             |
| `Snippets`       | Snippets ([UltiSnips][us])                                                |
| `Commands`       | User-defined commands                                                     |

- Most commands support `CTRL-T` / `CTRL-X` / `CTRL-V` key
  bindings to open in a new tab, a new split, or in a new vertical split.
- Bang-versions of the commands (e.g. `Ag!`) will open fzf in fullscreen

### Customization

```vim
" This is the default extra key bindings
let g:fzf_action = {
  \ 'ctrl-t': 'tab split',
  \ 'ctrl-x': 'split',
  \ 'ctrl-v': 'vsplit' }

" Default fzf layout
let g:fzf_layout = { 'down': '40%' }
```

Mappings
--------

| Mapping                        | Description                               |
| ---                            | ---                                       |
| `<plug>(fzf-complete-word)`    | `cat /usr/share/dict/words`               |
| `<plug>(fzf-complete-path)`    | Path completion using `find` (file + dir) |
| `<plug>(fzf-complete-file)`    | File completion using `find`              |
| `<plug>(fzf-complete-file-ag)` | File completion using `ag`                |

### Usage

```vim
imap <c-x><c-k> <plug>(fzf-complete-word)
imap <c-x><c-f> <plug>(fzf-complete-path)
imap <c-x><c-j> <plug>(fzf-complete-file-ag)
```

### Completion helper

`fzf#complete` is a helper function for creating custom fuzzy completion using
fzf. If the first parameter is a command string or a Vim list, it will be used
as the source.

```vim
" Replace the default dictionary completion with fzf-based fuzzy completion
inoremap <expr> <c-x><c-k> fzf#complete('cat /usr/share/dict/words')
```

For advanced uses, you can pass an options dictionary to the function. The set
of options is pretty much identical to that for `fzf#run` only with the
following exceptions:

- `reducer` (funcref)
    - Reducer transforms the output lines of fzf into a single string value
- `prefix` (string; default: `\k*$`)
    - Regular expression pattern to extract the completion prefix
- Both `source` and `options` can be given as funcrefs that take the
  completion prefix as the argument and return the final value
- `sink` or `sink*` are not allowed

#### Reducer example

```vim
function! s:make_sentence(lines)
  return substitute(join(a:lines), '^.', '\=toupper(submatch(0))', '').'.'
endfunction

inoremap <expr> <c-x><c-s> fzf#complete({
  \ 'source':  'cat /usr/share/dict/words',
  \ 'reducer': function('<sid>make_sentence'),
  \ 'options': '--multi --reverse --margin 15%,0',
  \ 'left':    20})
```

License
-------

MIT

[fzf]:   https://github.com/junegunn/fzf
[run]:   https://github.com/junegunn/fzf#usage-as-vim-plugin
[vimrc]: https://github.com/junegunn/dotfiles/blob/master/vimrc
[ag]:    https://github.com/ggreer/the_silver_searcher
[us]:    https://github.com/SirVer/ultisnips