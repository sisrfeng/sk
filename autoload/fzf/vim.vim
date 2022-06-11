" Copyright (c) 2017 Junegunn Choi
    " MIT License
    "
    " Permission is hereby granted, free of charge, to any person obtaining
    " a copy of this software and associated documentation files (the
    " "Software"), to deal in the Software without restriction, including
    " without limitation the rights to use, copy, modify, merge, publish,
    " distribute, sublicense, and/or sell copies of the Software, and to
    " permit persons to whom the Software is furnished to do so, subject to
    " the following conditions:
    "
    " The above copyright notice and this permission notice shall be
    " included in all copies or substantial portions of the Software.
    "
    " THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
    " EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    " MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
    " NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
    " LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
    " OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
    " WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

let s:cpo_save = &cpo
set cpo&vim

" Common
    let s:min_version = '0.9.3'
    let s:is_win = has('win32') || has('win64')
    let s:layout_keys = ['window', 'up', 'down', 'left', 'right']
    let s:bin_dir = expand('<sfile>:p:h:h:h').'/bin/'
    let s:bin = {
    \ 'preview': s:bin_dir.'preview.sh',
    \ 'tags':    s:bin_dir.'tags.pl' }
    let s:TYPE = {'dict': type({}), 'funcref': type(function('call')), 'string': type(''), 'list': type([])}
    if s:is_win
        if has('nvim')
            let s:bin.preview = split(system('for %A in ("'.s:bin.preview.'") do @echo %~sA'), "\n")[0]
        el
            let s:bin.preview = fnamemodify(s:bin.preview, ':8')
        en
    en

    let s:wide = 120
    let s:warned = 0
    let s:checked = 0

    fun! s:version_requirement(val, min)
        let val = split(a:val, '\.')
        let min = split(a:min, '\.')
        for idx in range(0, len(min) - 1)
            let v = get(val, idx, 0)
            if     v < min[idx] | return 0
            elseif v > min[idx] | return 1
            en
        endfor
        return 1
    endf

    fun! s:check_requirements()
        if s:checked
            return
        en

        if !exists('*skim#run')
            throw "skim#run function not found. You also need Vim plugin from the main fzf repository (i.e. junegunn/fzf *and* junegunn/fzf.vim)"
        en
        if !exists('*skim#exec')
            throw "skim#exec function not found. You need to upgrade Vim plugin from the main fzf repository ('junegunn/fzf')"
        en
        let exec = skim#exec()
        let fzf_version = matchstr(
            \ systemlist(exec .. ' --version')[0],
            \ '[0-9.]*',
           \ )

        if s:version_requirement(fzf_version, s:min_version)
            let s:checked = 1
            return
        end
        throw printf('You need to upgrade fzf. Found: %s (%s). Required: %s or above.', fzf_version, exec, s:min_version)
    endf

    fun! s:extend_opts(dict, eopts, prepend)
        if empty(a:eopts)
            return
        en
        if has_key(a:dict, 'options')
            if type(a:dict.options) == s:TYPE.list && type(a:eopts) == s:TYPE.list
                if a:prepend
                    let a:dict.options = extend(copy(a:eopts), a:dict.options)
                el
                    call extend(a:dict.options, a:eopts)
                en
            el
                let all_opts = a:prepend ? [a:eopts, a:dict.options] : [a:dict.options, a:eopts]
                let a:dict.options = join(map(all_opts, 'type(v:val) == s:TYPE.list ? join(map(copy(v:val), "skim#shellescape(v:val)")) : v:val'))
            en
        el
            let a:dict.options = a:eopts
        en
    endf

    fun! s:merge_opts(dict, eopts)
        return s:extend_opts(a:dict, a:eopts, 0)
    endf

    fun! s:prepend_opts(dict, eopts)
        return s:extend_opts(a:dict, a:eopts, 1)
    endf

    " [
    "  \ [spec to wrap],
    "  \ [preview window expression],
    "  \ [toggle-preview keys...],
    " \ ]
    fun! fzf#vim#with_preview(...)
        " Default spec
        let spec   =  {}
        let window =  ''

        let args = copy(a:000)

        " Spec to wrap
        if len(args) && type(args[0]) == s:TYPE.dict
            let spec = copy(args[0])
            call remove(args, 0)
        en

        if !executable('bash')
            if !s:warned
                call s:warn('Preview window not supported (bash not found in PATH)')
                let s:warned = 1
            en
            return spec
        en

        " Placeholder expression (TODO/TBD: undocumented)
        let placeholder = get(
                        \ spec,
                        \ 'placeholder',
                        \ '{}',
                       \ )

        " Preview window  id??
        if len(args) && type(args[0]) == s:TYPE.string
            if args[0] !~#   '^\(up\|down\|left\|right\)'
                throw 'invalid preview window: '.args[0]
            en
            let window = args[0]
            call remove(args, 0)
        en

        let preview = []
        if len(window)
            let preview += ['--preview-window', window]
        en
        if s:is_win
            let is_wsl_bash = exepath('bash') =~? 'Windows[/\\]system32[/\\]bash.exe$'
            let preview_cmd = 'bash '.(is_wsl_bash
            \ ? substitute(substitute(s:bin.preview, '^\([A-Z]\):', '/mnt/\L\1', ''), '\', '/', 'g')
            \ : escape(s:bin.preview, '\'))
        el
            let preview_cmd = skim#shellescape(s:bin.preview)
        en
        let preview += ['--preview', preview_cmd.' '.placeholder]

        if len(args)
            call extend(preview, ['--bind', join(map(args, 'v:val.":toggle-preview"'), ',')])
        en
        call s:merge_opts(spec, preview)
        return spec
    endf

    fun! s:remove_layout(opts)
        for key in s:layout_keys
            if has_key(a:opts, key)
                call remove(a:opts, key)
            en
        endfor
        return a:opts
    endf

    fun! s:reverse_list(opts)
        let tokens = map(split($FZF_DEFAULT_OPTS, '[^a-z-]'), 'substitute(v:val, "^--", "", "")')
        if index(tokens, 'reverse') < 0
            return extend(['--layout=reverse-list'], a:opts)
        en
        return a:opts
    endf

    fun! s:wrap(name, opts, bang)
        " skim#wrap does not append --expect if sink or sink* is found
        let opts = copy(a:opts)
        let options = ''
        if has_key(opts, 'options')
            let options = type(opts.options) == s:TYPE.list ? join(opts.options) : opts.options
        en
        if options !~ '--expect' && has_key(opts, 'sink*')
            let Sink = remove(opts, 'sink*')
            let wrapped = skim#wrap(a:name, opts, a:bang)
            let wrapped['sink*'] = Sink
        el
            let wrapped = skim#wrap(a:name, opts, a:bang)
        en
        return wrapped
    endf

    fun! s:strip(str)
        return substitute(a:str, '^\s*\|\s*$', '', 'g')
    endf

    fun! s:chomp(str)
        return substitute(a:str, '\n*$', '', 'g')
    endf

    fun! s:escape(path)
        let path = fnameescape(a:path)
        return s:is_win ? escape(path, '$') : path
    endf

    if v:version >= 704
        fun! s:function(name)
            return function(a:name)
        endf
    el
        fun! s:function(name)
            " By Ingo Karkat
            return function(substitute(a:name, '^s:', matchstr(expand('<sfile>'), '<SNR>\d\+_\zefunction$'), ''))
        endf
    en

    fun! s:get_color(attr, ...)
        let gui = has('termguicolors') && &termguicolors
        let fam = gui ? 'gui' : 'cterm'
        let pat = gui ? '^#[a-f0-9]\+' : '^[0-9]\+$'
        for group in a:000
            let code = synIDattr(synIDtrans(hlID(group)), a:attr, fam)
            if code =~? pat
                return code
            en
        endfor
        return ''
    endf


    " Table 34-1. Numbers representing colors in Escape Sequences
    "
        " Color	Foreground	Background
        " black	30	40
        " red	31	41
        " green	32	42
        " yellow	33	43
        " blue	34	44
        " magenta	35	45
        " cyan	36	46
        " white	37	47

    " let s:ansi = {'black': 30, 'red': 31, 'green': 32, 'yellow': 33, 'blue': 34, 'magenta': 35, 'cyan': 36}
    let s:ansi = {'black': 37, 'red': 31, 'green': 32, 'yellow': 33, 'blue': 34, 'magenta': 35, 'cyan': 36}

    fun! s:csi(color, fg)
        let prefix = a:fg ? '38;' : '48;'
        if a:color[0] == '#'
            return prefix.'2;'.join(map([a:color[1:2], a:color[3:4], a:color[5:6]], 'str2nr(v:val, 16)'), ';')
        en
        return prefix.'5;'.a:color
    endf

    fun! s:ansi(str, group, default, ...)
        let fg = s:get_color('fg', a:group)
        let bg = s:get_color('bg', a:group)
        let color = (empty(fg) ? s:ansi[a:default] : s:csi(fg, 1)) .
                    \ (empty(bg) ? '' : ';'.s:csi(bg, 0))
        return printf("\x1b[%s%sm%s\x1b[m", color, a:0 ? ';1' : '', a:str)
    endf

    for s:color_name in keys(s:ansi)
        exe     "function! s:".s:color_name."(str, ...)\n"
                    \ "  return s:ansi(a:str, get(a:, 1, ''), '".s:color_name."')\n"
                    \ "endfunction"
    endfor

    fun! s:buflisted()
        return filter(range(1, bufnr('$')), 'buflisted(v:val) && getbufvar(v:val, "&filetype") != "qf"')
    endf

    fun! s:fzf(name, opts, extra)
        call s:check_requirements()

        let [extra, bang] = [{}, 0]
        if len(a:extra) <= 1
            let first = get(a:extra, 0, 0)
            if type(first) == s:TYPE.dict
                let extra = first
            el
                let bang = first
            en
        elseif len(a:extra) == 2
            let [extra, bang] = a:extra
        el
            throw 'invalid number of arguments'
        en

        let eopts  = has_key(extra, 'options') ? remove(extra, 'options') : ''
        let merged_opts = extend(copy(a:opts), extra)
        call s:merge_opts(merged_opts, eopts)
        return skim#run( s:wrap(
                                \ a:name,
                                \ merged_opts,
                                \ bang,
                               \ )
                       \)
    endf

    let s:default_action = {
        \ 'ctrl-t': 'tab split',
        \ 'ctrl-x': 'split',
        \ 'ctrl-v': 'vsplit' }

    fun! s:action_for(key, ...)
        let default = a:0 ? a:1 : ''
        let Cmd = get(get(g:, 'skim_action', s:default_action), a:key, default)
        return type(Cmd) == s:TYPE.string ? Cmd : default
    endf

    fun! s:open(cmd, target)
        if stridx('edit', a:cmd) == 0 && fnamemodify(a:target, ':p') ==# expand('%:p')
            return
        en
        exe     a:cmd s:escape(a:target)
    endf

    fun! s:align_lists(lists)
        let maxes = {}
        for list in a:lists
            let i = 0
            while i < len(list)
                let maxes[i] = max([get(maxes, i, 0), len(list[i])])
                let i += 1
            endwhile
        endfor
        for list in a:lists
            call map(list, "printf('%-'.maxes[v:key].'s', v:val)")
        endfor
        return a:lists
    endf

    fun! s:warn(message)
        echohl WarningMsg
        echom a:message
        echohl None
        return 0
    endf

    fun! s:fill_quickfix(list, ...)
        if len(a:list) > 1
            call setqflist(a:list)
            copen
            wincmd p
            if a:0
                exe     a:1
            en
        en
    endf

    fun! fzf#vim#_uniq(list)
        let visited = {}
        let ret = []
        for l in a:list
            if !empty(l) && !has_key(visited, l)
                call add(ret, l)
                let visited[l] = 1
            en
        endfor
        return ret
    endf

" Files
    fun! s:shortpath()
        let short = fnamemodify(getcwd(), ':~:.')
        " ~代替/home/XXX
        if !has('win32unix')
            let short = pathshorten(short)
        en
        let slash = (s:is_win && !&shellslash) ? '\' : '/'
        return empty(short) ? '~'.slash : short . (short =~ escape(slash, '\').'$' ? '' : slash)
    endf

    fun! fzf#vim#files(dir, ...)
        let args = {}
        if !empty(a:dir)
            if !isdirectory(expand(a:dir))
                return s:warn('Invalid directory')
            en
            let slash = (s:is_win && !&shellslash) ? '\\' : '/'
            let dir = substitute(a:dir, '[/\\]*$', slash, '')
            let args.dir = dir
        el
            let dir = s:shortpath()
        en

        let args.options = ['-m', '--prompt', strwidth(dir) < &columns / 2 - 20 ? dir : '> ']
        call s:merge_opts(args, get(g:, 'fzf_files_options', []))
        return s:fzf('files', args, a:000)
    endf


" Lines
    fun! s:line_handler(lines)
        if len(a:lines) < 2
            return
        en
        normal! m'
        let cmd = s:action_for(a:lines[0])
        if !empty(cmd) && stridx('edit', cmd) < 0
            exe     'silent' cmd
        en

        let keys = split(a:lines[1], '\t')
        exe     'buffer' keys[0]
        exe     keys[2]
        normal! ^zvzz
    endf

    fun! fzf#vim#_lines(all)
        let cur = []
        let rest = []
        let buf = bufnr('')
        let longest_name = 0
        let display_bufnames = &columns > s:wide
        if display_bufnames
            let bufnames = {}
            for b in s:buflisted()
                let bufnames[b] = pathshorten(fnamemodify(bufname(b), ":~:."))
                let longest_name = max([longest_name, len(bufnames[b])])
            endfor
        en
        let len_bufnames = min([15, longest_name])
        for b in s:buflisted()
            let lines = getbufline(b, 1, "$")
            if empty(lines)
                let path = fnamemodify(bufname(b), ':p')
                let lines = filereadable(path) ? readfile(path) : []
            en
            if display_bufnames
                let bufname = bufnames[b]
                if len(bufname) > len_bufnames + 1
                    let bufname = '…' . bufname[-len_bufnames+1:]
                en
                let bufname = printf(s:green("%".len_bufnames."s", "Directory"), bufname)
            el
                let bufname = ''
            en
            let linefmt = s:blue("%2d\t", "TabLine")."%s".s:yellow("\t%4d ", "LineNr")."\t%s"
            call extend(b == buf ? cur : rest,
            \ filter(
            \   map(lines,
            \       '(!a:all && empty(v:val)) ? "" : printf(linefmt, b, bufname, v:key + 1, v:val)'),
            \   'a:all || !empty(v:val)'))
        endfor
        return [display_bufnames, extend(cur, rest)]
    endf

    fun! fzf#vim#lines(...)
        let [display_bufnames, lines] = fzf#vim#_lines(1)
        let nth = display_bufnames ? 3 : 2
        let [query, args] = (a:0 && type(a:1) == type('')) ?
                        \ [a:1, a:000[1:]]
                        \ : ['', a:000]
        return
            \ s:fzf('lines',
                    \ {
                        \ 'source':  lines,
                        \ 'sink*':   s:function('s:line_handler'),
                        \ 'options': s:reverse_list([
                                                    \ '--no-multi',
                                                    \ '--tiebreak=index',
                                                    \ '--prompt',
                                                        \ 'Lines> ',
                                                    \ '--ansi',
                                                    \ '--extended',
                                                    \ '--nth='.nth.'..',
                                                    \ '--tabstop=1',
                                                    \ '--query',
                                                    \ query,
                                                   \ ])
                    \},
                \ args
                \ )
    endf

" BLines
    fun! s:buffer_line_handler(lines)
        if len(a:lines) < 2
            return
        en
        let qfl = []
        for line in a:lines[1:]
            let chunks = split(line, "\t", 1)
            let ln = chunks[0]
            let ltxt = join(chunks[1:], "\t")
            call add(qfl, {'filename': expand('%'), 'lnum': str2nr(ln), 'text': ltxt})
        endfor
        call s:fill_quickfix(qfl, 'cfirst')
        normal! m'
        let cmd = s:action_for(a:lines[0])
        if !empty(cmd)
            exe     'silent' cmd
        en

        exe     split(a:lines[1], '\t')[0]
        normal! ^zvzz
    endf

    fun! s:buffer_lines(query)
        let linefmt = s:yellow(" %4d ", "LineNr")."\t%s"
        let fmtexpr = 'printf(linefmt, v:key + 1, v:val)'
        let lines = getline(1, '$')
        if empty(a:query)
            return map(lines, fmtexpr)
        end
        return filter(map(lines, 'v:val =~ a:query ? '.fmtexpr.' : ""'), 'len(v:val)')
    endf

    fun! fzf#vim#buffer_lines(...)
        let [query, args] = (a:0 && type(a:1) == type('')) ?
                    \ [a:1, a:000[1:]] : ['', a:000]
        return s:fzf('blines', {
        \ 'source':  s:buffer_lines(query),
        \ 'sink*':   s:function('s:buffer_line_handler'),
        \ 'options': s:reverse_list(['--no-multi', '--tiebreak=index', '--multi', '--prompt', 'BLines> ', '--ansi', '--extended', '--nth=2..', '--tabstop=1'])
        \}, args)
    endf



" Colors
    fun! fzf#vim#colors(...)
        let colors = split(globpath(&rtp, "colors/*.vim"), "\n")
        if has('packages')
            let colors += split(globpath(&packpath, "pack/*/opt/*/colors/*.vim"), "\n")
        en
        return s:fzf('colors', {
        \ 'source':  fzf#vim#_uniq(map(colors, "substitute(fnamemodify(v:val, ':t'), '\\..\\{-}$', '', '')")),
        \ 'sink':    'colo',
        \ 'options': '-m --prompt="Colors> "'
        \}, a:000)
    endf

" Locate
    fun! fzf#vim#locate(query, ...)
        return s:fzf('locate', {
        \ 'source':  'locate '.a:query,
        \ 'options': '-m --prompt "Locate> "'
        \}, a:000)
    endf

" History[:/]
    fun! fzf#vim#_recent_files()
        return fzf#vim#_uniq(map(
            \ filter([expand('%')], 'len(v:val)')
            \   + filter(map(fzf#vim#_buflisted_sorted(), 'bufname(v:val)'), 'len(v:val)')
            \   + filter(copy(v:oldfiles), "filereadable(fnamemodify(v:val, ':p'))"),
            \ 'fnamemodify(v:val, ":~:.")'))
    endf

    fun! s:history_source(type)
        let max  = histnr(a:type)
        let fmt  = ' %'.len(string(max)).'d '
        let list = filter(map(range(1, max), 'histget(a:type, - v:val)'), '!empty(v:val)')
        return extend([' :: Press '.s:magenta('CTRL-E', 'Special').' to edit'],
            \ map(list, 's:yellow(printf(fmt, len(list) - v:key), "Number")." ".v:val'))
    endf

    nno      <plug>(-fzf-vim-do) :execute g:__fzf_command<cr>
    nno      <plug>(-fzf-/) /
    nno      <plug>(-fzf-:) :

    fun! s:history_sink(type, lines)
        if len(a:lines) < 2
            return
        en

        let prefix = "\<plug>(-fzf-".a:type.')'
        let key  = a:lines[0]
        let item = matchstr(a:lines[1], ' *[0-9]\+ *\zs.*')
        if key == 'ctrl-e'
            call histadd(a:type, item)
            redraw
            call feedkeys(a:type."\<up>", 'n')
        el
            if a:type == ':'
                call histadd(a:type, item)
            en
            let g:__fzf_command = "normal ".prefix.item."\<cr>"
            call feedkeys("\<plug>(-fzf-vim-do)")
        en
    endf

    fun! s:cmd_history_sink(lines)
        call s:history_sink(':', a:lines)
    endf

    fun! fzf#vim#command_history(...)
        return s:fzf('history-command', {
        \ 'source':  s:history_source(':'),
        \ 'sink*':   s:function('s:cmd_history_sink'),
        \ 'options': '-m --ansi --prompt="Hist:> " --header-lines=1 --expect=ctrl-e --tiebreak=index'}, a:000)
    endf

    fun! s:search_history_sink(lines)
        call s:history_sink('/', a:lines)
    endf

    fun! fzf#vim#search_history(...)
        return s:fzf('history-search', {
        \ 'source':  s:history_source('/'),
        \ 'sink*':   s:function('s:search_history_sink'),
        \ 'options': '-m --ansi --prompt="Hist/> " --header-lines=1 --expect=ctrl-e --tiebreak=index'}, a:000)
    endf

    fun! fzf#vim#history(...)
        return s:fzf('history-files', {
        \ 'source':  fzf#vim#_recent_files(),
        \ 'options': ['-m', '--header-lines', !empty(expand('%')), '--prompt', 'Hist> ']
        \}, a:000)
    endf

" GFiles[?]

    fun! s:get_git_root()
        let g_root = split(system('git rev-parse --show-toplevel'), '\n')[0]
        return v:shell_error ? '' : g_root
    endf

    fun! fzf#vim#gitfiles(args, ...)
        let g_root = s:get_git_root()

        if empty(g_root)
            " call s:warn('Not in git repo')
            return fzf#vim#files(getcwd())
        en

        if g_root =~ '/final/' ||
           \ g_root =~ '/dotF' ||
           \ g_root =~ 'tbsi_final'
            let g_root = getcwd()
            " 别跳走到root
        en


        if a:args != '?'
            " s:fzf的第一个参数是随意的name?
            " return s:fzf('gfiles', {
            return s:fzf('smart_files', {
                          \ 'source'  : 'git ls-files '.a:args.(s:is_win ? '' : ' | uniq'),
                          \ 'dir'     : g_root,
                          \ 'options' : '-m --prompt "'..g_root..' > "'
                      \},
                  \ a:000
                \ )
        en

        " -----另一个分支:
        " if a:args == '?'

        " Here be dragons!
        " We're trying to access the common sink function that
        " skim#wrap injects to
        " the options dictionary.
        let wrapped = skim#wrap({
            \ 'source':  'git -c color.status=always status --short --untracked-files=all',
            \ 'dir':     g_root,
            \ 'options': [
                \ '--ansi',
                \ '--multi',
                \ '--nth',
                \ '2..,..',
                \ '--tiebreak=index',
                \ '--prompt',
                \ 'GitFiles?> ',
                \ '--preview',
                \ 'sh -c "(git diff --color=always -- {-1} | sed 1,4d; cat {-1}) | head -1000"',
               \ ]
        \})
        call s:remove_layout(wrapped)
        let wrapped.common_sink = remove(wrapped, 'sink*')

        fun! wrapped.newsink(lines)
            let lines = extend(
                         \ a:lines[0:0],
                         \ map(
                             \ a:lines[1:],
                             \ 'substitute(v:val[3:], ".* -> ", "", "")',
                            \ ),
                        \ )
            return self.common_sink(lines)
        endf

        let wrapped['sink*'] = remove(wrapped, 'newsink')
        echom "准备return s:fzf('gfiles-diff', wrapped, a:000)"
        return s:fzf('files_git_diff', wrapped, a:000)
    endf

" Buffers
    fun! s:find_open_window(b)
        let [tcur, tcnt] = [tabpagenr() - 1, tabpagenr('$')]
        for toff in range(0, tabpagenr('$') - 1)
            let t = (tcur + toff) % tcnt + 1
            let buffers = tabpagebuflist(t)
            for w in range(1, len(buffers))
                let b = buffers[w - 1]
                if b == a:b
                    return [t, w]
                en
            endfor
        endfor
        return [0, 0]
    endf

    fun! s:jump(t, w)
        exe     a:t.'tabnext'
        exe     a:w.'wincmd w'
    endf

    fun! s:bufopen(lines)
        if len(a:lines) < 2
            return
        en
        let b = matchstr(a:lines[1], '\[\zs[0-9]*\ze\]')
        if empty(a:lines[0]) && get(g:, 'fzf_buffers_jump')
            let [t, w] = s:find_open_window(b)
            if t
                call s:jump(t, w)
                return
            en
        en
        let cmd = s:action_for(a:lines[0])
        if !empty(cmd)
            exe     'silent' cmd
        en
        exe     'buffer' b
    endf

    fun! fzf#vim#_format_buffer(b)
        let name = bufname(a:b)
        let line = exists('*getbufinfo') ? getbufinfo(a:b)[0]['lnum'] : 0
        let name = empty(name) ? '[No Name]' : fnamemodify(name, ":p:~:.")
        let flag = a:b == bufnr('')  ? s:blue('%', 'Conditional') :
                        \ (a:b == bufnr('#') ? s:magenta('#', 'Special') : ' ')
        let modified = getbufvar(a:b, '&modified') ? s:red(' [+]', 'Exception') : ''
        let readonly = getbufvar(a:b, '&modifiable') ? '' : s:green(' [RO]', 'Constant')
        let extra = join(filter([modified, readonly], '!empty(v:val)'), '')
        let target = line == 0 ? name : name.':'.line
        return s:strip(printf("%s\t%d\t[%s] %s\t%s\t%s", target, line, s:yellow(a:b, 'Number'), flag, name, extra))
    endf

    fun! s:sort_buffers(...)
        let [b1, b2] = map(copy(a:000), 'get(g:fzf#vim#buffers, v:val, v:val)')
        " Using minus between a float and a number in a sort function causes an error
        return b1 < b2 ? 1 : -1
    endf

    fun! fzf#vim#_buflisted_sorted()
        return sort(s:buflisted(), 's:sort_buffers')
    endf

    fun! fzf#vim#buffers(...)
        let [query, args] = (a:0 && type(a:1) == type('')) ?
                    \ [a:1, a:000[1:]] : ['', a:000]
        return s:fzf('buffers', {
        \ 'source':  map(fzf#vim#_buflisted_sorted(), 'fzf#vim#_format_buffer(v:val)'),
        \ 'sink*':   s:function('s:bufopen'),
        \ 'options': ['--no-multi', '-x', '--tiebreak=index', '--header-lines=1', '--ansi', '-d', '\t', '--with-nth', '3..', '-n', '2,1..2', '--prompt', 'Buf> ', '--query', query, '--preview-window', '+{2}-/2']
        \}, args)
    endf

" Ag / Rg
    fun! s:ag_to_qf(line, has_column)
        let parts = matchlist(a:line, '\(.\{-}\)\s*:\s*\(\d\+\)\%(\s*:\s*\(\d\+\)\)\?\%(\s*:\(.*\)\)\?')
        let dict = {'filename': &acd ? fnamemodify(parts[1], ':p') : parts[1], 'lnum': parts[2], 'text': parts[4]}
        if a:has_column
            let dict.col = parts[3]
        en
        return dict
    endf

    fun! s:ag_handler(lines, has_column)
        if len(a:lines) < 2
            return
        en

        let cmd = s:action_for(a:lines[0], 'e')
        let list = map(filter(a:lines[1:], 'len(v:val)'), 's:ag_to_qf(v:val, a:has_column)')
        if empty(list)
            return
        en

        let first = list[0]
        try
            call s:open(cmd, first.filename)
            exe     first.lnum
            if a:has_column
                exe     'normal!' first.col.'|'
            en
            normal! zz
        catch
        endtry

        call s:fill_quickfix(list)
    endf

    " interactive:
        fun! fzf#vim#grep_interactive(command, column_01, ...)
            let words = []
            " command可以长这样:
            " 'rg  --line-number --color=always '..get(g:, 'rg_opts', '')..' "{}" ' .. dir
            for word in split(a:command)
                     " 空格划分
                if word !~# '^[a-z]'
                    " 遇到--line-number等option, 结束for
                    break
                en
                call add(words, word)
            endfor

            let words   = empty(words) ?  ['grep'] :  words
                                       " 默认用grep, 而非rg等
            " echom "words 是: "   words
                " ['rg']
            let name    = join(words, '-')
            let Capname = join(
                \ map(
                    \ words,
                    \ 'toupper(v:val[0]).v:val[1:]',
                   \ ),
                \ '',
               \ )
            " echom "Capname 是: "   Capname

            " 别人调用这函数时, opts在这里能改的只有3处, (但可以传a:000 覆盖这里的?)
            let opts = {
                \ 'source':  'none',
                \ 'column':  a:column_01,
                "\ shell执行的是它?    sh -c 'rg --line-number ...'
                \ 'options': ['-i', '-c', a:command,
                "\ 表示path的var, can not update on the fly
                "\ \             '--ansi', '--cmd-prompt', g:git_top_for_fzf..' '.Capname..'> ',
                "\ \             '--ansi', '--cmd-prompt', $PWD..' '..Capname.'> ',
                \             '--ansi', '--cmd-prompt', Capname.'> ',
                \             '--multi', '--bind', 'alt-a:select-all,alt-d:deselect-all',
                \             '--skip-to-pattern', '[^/]*:',
                \             '--delimiter', ':', '--preview-window', '+{2}-/2',
                "\ \             '--color', 'hl:4,hl+:12']  如何传参改颜色?
                \             '--color']
            \}

            fun! opts.sink(lines)
                return s:ag_handler(a:lines, self.column)
            endf

            let opts['sink*'] = remove(opts, 'sink')
            " echom "opts是: "   opts

            " echom "a:000 是: "   a:000

            return s:fzf(name, opts, a:000)
        endf

            fun! fzf#vim#ag_interactive(dir, ...)
                let dir = empty(a:dir) ? '.' : a:dir
                let command = 'ag --nogroup --column --color '.get(g:, 'ag_opts', '').' "{}" ' . dir
                return call(
                    \ 'fzf#vim#grep_interactive',
                    \ extend([command, 1], a:000, ),
                   \ )
            endf

            fun! fzf#vim#rg_interactive(dir, ...)
                let dir = empty(a:dir)
                      \ ? '.'
                      \ : a:dir

                let command = 'rg --column --line-number --color=always '..get(g:, 'rg_opts', '') .. ' "{}" ' .. dir
                return call(
                    \ 'fzf#vim#grep_interactive',
                    \ extend([command, 1], a:000),
                   \ )
            endf



    " ag() (非interactive):
        " query, [[ag options], options]
        fun! fzf#vim#ag(query, ...)
            if type(a:query) != s:TYPE.string
                return s:warn('Invalid query argument')
            en
            let query = empty(a:query) ? '^(?=.)' : a:query
            let args = copy(a:000)
            let ag_opts = len(args) > 1 && type(args[0]) == s:TYPE.string ? remove(args, 0) : ''
            let command = ag_opts . ' -- ' . skim#shellescape(query)
            return call('fzf#vim#ag_raw', insert(args, command, 0))
        endf

            " ag command suffix, [options]
            fun! fzf#vim#ag_raw(command_suffix, ...)
                if !executable('ag')
                    return s:warn('ag is not found')
                en
                return call('fzf#vim#grep', extend(['ag --nogroup --column --color '.a:command_suffix, 1], a:000))
            endf

                " 参数: command (string), has_column (0/1), [options (dict)], [fullscreen (0/1)]
                fun! fzf#vim#grep(grep_command, has_column, ...)
                    let words = []
                    for word in split(a:grep_command)
                        if word !~# '^[a-z]'
                            break
                        en
                        call add(words, word)
                    endfor
                    let words   = empty(words) ? ['grep'] : words
                    let name    = join(words, '-')
                    let Capname = join(map(words, 'toupper(v:val[0]).v:val[1:]'), '')
                    let opts = {
                    \ 'column':  a:has_column,
                    \ 'options': ['--ansi', '--prompt', Capname.'> ',
                    \             '--multi', '--bind', 'alt-a:select-all,alt-d:deselect-all',
                    \             '--delimiter', ':', '--preview-window', '+{2}-/2',
                    \             '--color']
                    "\ \             '--color', 'hl:4,hl+:12']
                    \}
                    fun! opts.sink(lines)
                        return s:ag_handler(a:lines, self.column)
                    endf
                    let opts['sink*'] = remove(opts, 'sink')
                    try
                        let prev_default_command = $FZF_DEFAULT_COMMAND
                        let $FZF_DEFAULT_COMMAND = a:grep_command
                        return s:fzf(name, opts, a:000)
                    finally
                        let $FZF_DEFAULT_COMMAND = prev_default_command
                    endtry
                endf


" BTags
    fun! s:btags_source(tag_cmds)
        if !filereadable(expand('%'))
            throw 'Save the file first'
        en

        for cmd in a:tag_cmds
            let lines = split(system(cmd), "\n")
            if !v:shell_error && len(lines)
                break
            en
        endfor
        if v:shell_error
            throw get(lines, 0, 'Failed to extract tags')
        elseif empty(lines)
            throw 'No tags found'
        en
        return map(s:align_lists(map(lines, 'split(v:val, "\t")')), 'join(v:val, "\t")')
    endf

    fun! s:btags_sink(lines)
        if len(a:lines) < 2
            return
        en
        normal! m'
        let cmd = s:action_for(a:lines[0])
        if !empty(cmd)
            exe     'silent' cmd '%'
        en
        let qfl = []
        for line in a:lines[1:]
            exe     split(line, "\t")[2]
            call add(qfl, {'filename': expand('%'), 'lnum': line('.'), 'text': getline('.')})
        endfor
        call s:fill_quickfix(qfl, 'cfirst')
        normal! zvzz
    endf

    " query, [[tag commands], options]
    fun! fzf#vim#buffer_tags(query, ...)
        let args = copy(a:000)
        let escaped = skim#shellescape(expand('%'))
        let null = s:is_win ? 'nul' : '/dev/null'
        let sort = has('unix') && !has('win32unix') && executable('sort') ? '| sort -s -k 5' : ''
        let tag_cmds = (len(args) > 1 && type(args[0]) != type({})) ? remove(args, 0) : [
            \ printf('ctags -f - --sort=yes --excmd=number --language-force=%s %s 2> %s %s', &filetype, escaped, null, sort),
            \ printf('ctags -f - --sort=yes --excmd=number %s 2> %s %s', escaped, null, sort)]
        if type(tag_cmds) != type([])
            let tag_cmds = [tag_cmds]
        en
        try
            return s:fzf('btags', {
            \ 'source':  s:btags_source(tag_cmds),
            \ 'sink*':   s:function('s:btags_sink'),
            \ 'options': s:reverse_list(['-m', '-d', '\t', '--with-nth', '1,4..', '-n', '1', '--prompt', 'BTags> ', '--query', a:query, '--preview-window', '+{3}-/2'])}, args)
        catch
            return s:warn(v:exception)
        endtry
    endf

" Tags
    fun! s:tags_sink(lines)
        if len(a:lines) < 2
            return
        en
        normal! m'
        let qfl = []
        let cmd = s:action_for(a:lines[0], 'e')
        try
            let [magic, &magic, wrapscan, &wrapscan, acd, &acd] = [&magic, 0, &wrapscan, 1, &acd, 0]
            for line in a:lines[1:]
                try
                    let parts   = split(line, '\t\zs')
                    let excmd   = matchstr(join(parts[2:-2], '')[:-2], '^.\{-}\ze;\?"\t')
                    let base    = fnamemodify(parts[-1], ':h')
                    let relpath = parts[1][:-2]
                    let abspath = relpath =~ (s:is_win ? '^[A-Z]:\' : '^/') ? relpath : join([base, relpath], '/')
                    call s:open(cmd, expand(abspath, 1))
                    silent execute excmd
                    call add(qfl, {'filename': expand('%'), 'lnum': line('.'), 'text': getline('.')})
                catch /^Vim:Interrupt$/
                    break
                catch
                    call s:warn(v:exception)
                endtry
            endfor
        finally
            let [&magic, &wrapscan, &acd] = [magic, wrapscan, acd]
        endtry
        call s:fill_quickfix(qfl, 'clast')
        normal! zvzz
    endf

    fun! fzf#vim#tags(query, ...)
        if !executable('perl')
            return s:warn('Tags command requires perl')
        en
        if empty(tagfiles())
            call inputsave()
            echohl WarningMsg
            let gen = input('tags not found. Generate? (y/N) ')
            echohl None
            call inputrestore()
            redraw
            if gen =~? '^y'
                call s:warn('Preparing tags')
                call system(get(g:, 'fzf_tags_command', 'ctags -R'.(s:is_win ? ' --output-format=e-ctags' : '')))
                if empty(tagfiles())
                    return s:warn('Failed to create tags')
                en
            el
                return s:warn('No tags found')
            en
        en

        let tagfiles = tagfiles()
        let v2_limit = 1024 * 1024 * 200
        for tagfile in tagfiles
            let v2_limit -= getfsize(tagfile)
            if v2_limit < 0
                break
            en
        endfor
        let opts = v2_limit < 0 ? ['--algo=v1'] : []

        return s:fzf('tags', {
        \ 'source':  'perl '.skim#shellescape(s:bin.tags).' '.join(map(tagfiles, 'skim#shellescape(fnamemodify(v:val, ":p"))')),
        \ 'sink*':   s:function('s:tags_sink'),
        \ 'options': extend(opts, ['--nth', '1..2', '-m', '--tiebreak=begin', '--prompt', 'Tags> ', '--query', a:query])}, a:000)
    endf



" Snippets (UltiSnips)
    fun! s:inject_snippet(line)
        let snip = split(a:line, "\t")[0]
        exe     'normal! a'.s:strip(snip)."\<c-r>=UltiSnips#ExpandSnippet()\<cr>"
    endf

    fun! fzf#vim#snippets(...)
        if !exists(':UltiSnipsEdit')
            return s:warn('UltiSnips not found')
        en
        let list = UltiSnips#SnippetsInCurrentScope()
        if empty(list)
            return s:warn('No snippets available here')
        en
        let aligned = sort(s:align_lists(items(list)))
        let colored = map(aligned, 's:yellow(v:val[0])."\t".v:val[1]')
        return s:fzf('snippets', {
        \ 'source':  colored,
        \ 'options': '--ansi --tiebreak=index -m -n 1 -d "\t"',
        \ 'sink':    s:function('s:inject_snippet')}, a:000)
    endf

" Commands
    let s:nbs = nr2char(0x2007)

    fun! s:format_cmd(line)
        return substitute(a:line, '\C \([A-Z]\S*\) ',
                    \ '\=s:nbs.s:yellow(submatch(1), "Function").s:nbs', '')
    endf

    fun! s:command_sink(lines)
        if len(a:lines) < 2
            return
        en
        let cmd = matchstr(a:lines[1], s:nbs.'\zs\S*\ze'.s:nbs)
        if empty(a:lines[0])
            call feedkeys(':'.cmd.(a:lines[1][0] == '!' ? '' : ' '), 'n')
        el
            exe     cmd
        en
    endf

    let s:fmt_excmd = '   '.s:blue('%-38s', 'Statement').'%s'

    fun! s:format_excmd(ex)
        let match = matchlist(a:ex, '^|:\(\S\+\)|\s*\S*\(.*\)')
        return printf(s:fmt_excmd, s:nbs.match[1].s:nbs, s:strip(match[2]))
    endf

    fun! s:excmds()
        let help = globpath($VIMRUNTIME, 'doc/index.txt')
        if empty(help)
            return []
        en

        let commands = []
        let command = ''
        for line in readfile(help)
            if line =~ '^|:[^|]'
                if !empty(command)
                    call add(commands, s:format_excmd(command))
                en
                let command = line
            elseif line =~ '^\s\+\S' && !empty(command)
                let command .= substitute(line, '^\s*', ' ', '')
            elseif !empty(commands) && line =~ '^\s*$'
                break
            en
        endfor
        if !empty(command)
            call add(commands, s:format_excmd(command))
        en
        return commands
    endf

    fun! fzf#vim#commands(...)
        redir => cout
        silent command
        redir END
        let list = split(cout, "\n")
        return s:fzf(
                    \ 'commands',
                    \{
                        \ 'source':  extend(extend(list[0:0], map(list[1:], 's:format_cmd(v:val)')), s:excmds()),
                        \ 'sink*':   s:function('s:command_sink'),
                        \ 'options': '--ansi --expect '.get(g:, 'fzf_commands_expect', 'ctrl-x').
                        \            ' --tiebreak=index --header-lines 1 --extended --prompt "Commands> " -n2,3,2..3 -d'.s:nbs
                    \},
                    \ a:000
                    \)
    endf

" Marks
    fun! s:format_mark(line)
        return substitute(a:line, '\S', '\=s:yellow(submatch(0), "Number")', '')
    endf

    fun! s:mark_sink(lines)
        if len(a:lines) < 2
            return
        en
        let cmd = s:action_for(a:lines[0])
        if !empty(cmd)
            exe     'silent' cmd
        en
        exe     'normal! `'.matchstr(a:lines[1], '\S').'zz'
    endf

    fun! fzf#vim#marks(...)
        redir => cout
        silent marks
        redir END
        let list = split(cout, "\n")
        return s:fzf('marks', {
        \ 'source':  extend(list[0:0], map(list[1:], 's:format_mark(v:val)')),
        \ 'sink*':   s:function('s:mark_sink'),
        \ 'options': '-m --extended --ansi --tiebreak=index --header-lines 1 --tiebreak=begin --prompt "Marks> "'}, a:000)
    endf

" Help tags
    fun! s:helptag_sink(line)
        let [tag, file, path] = split(a:line, "\t")[0:2]
        let rtp = fnamemodify(path, ':p:h:h')
        if stridx(&rtp, rtp) < 0
            exe     'set rtp+='.s:escape(rtp)
        en
        exe     'help' tag
    endf

    fun! fzf#vim#helptags(...)
        if !executable('grep') || !executable('perl')
            return s:warn('Helptags command requires grep and perl')
        en
        let sorted = sort(split(globpath(&runtimepath, 'doc/tags', 1), '\n'))
        let tags = exists('*uniq') ? uniq(sorted) : fzf#vim#_uniq(sorted)

        if exists('s:helptags_script')
            silent! call delete(s:helptags_script)
        en
        let s:helptags_script = tempname()
        call writefile(['/('.(s:is_win ? '^[A-Z]:[\/\\].*?[^:]' : '.*?').'):(.*?)\t(.*?)\t/; printf(qq('.s:green('%-40s', 'Label').'\t%s\t%s\n), $2, $3, $1)'], s:helptags_script)
        return s:fzf('helptags', {
        \ 'source':  'grep -H ".*" '.join(map(tags, 'skim#shellescape(v:val)')).
            \ ' | perl -n '.skim#shellescape(s:helptags_script).' | sort',
        \ 'sink':    s:function('s:helptag_sink'),
        \ 'options': ['--ansi', '-m', '--tiebreak=begin', '--with-nth', '..-2']}, a:000)
    endf

" File types
    fun! fzf#vim#filetypes(...)
        return s:fzf('filetypes', {
        \ 'source':  fzf#vim#_uniq(sort(map(split(globpath(&rtp, 'syntax/*.vim'), '\n'),
        \            'fnamemodify(v:val, ":t:r")'))),
        \ 'sink':    'setf',
        \ 'options': '-m --prompt="File types> "'
        \}, a:000)
    endf

" Windows
    fun! s:format_win(tab, win, buf)
        let modified = getbufvar(a:buf, '&modified')
        let name = bufname(a:buf)
        let name = empty(name) ? '[No Name]' : name
        let active = tabpagewinnr(a:tab) == a:win
        return (active? s:blue('> ', 'Operator') : '  ') . name . (modified? s:red(' [+]', 'Exception') : '')
    endf

    fun! s:windows_sink(line)
        let list = matchlist(a:line, '^ *\([0-9]\+\) *\([0-9]\+\)')
        call s:jump(list[1], list[2])
    endf

    fun! fzf#vim#windows(...)
        let lines = []
        for t in range(1, tabpagenr('$'))
            let buffers = tabpagebuflist(t)
            for w in range(1, len(buffers))
                call add(lines,
                    \ printf('%s %s  %s',
                            \ s:yellow(printf('%3d', t), 'Number'),
                            \ s:cyan(printf('%3d', w), 'String'),
                            \ s:format_win(t, w, buffers[w-1])))
            endfor
        endfor
        return s:fzf('windows', {
        \ 'source':  extend(['Tab Win    Name'], lines),
        \ 'sink':    s:function('s:windows_sink'),
        \ 'options': '-m --ansi --tiebreak=begin --header-lines=1'}, a:000)
    endf

" Commits / BCommits
    fun! s:yank_to_register(data)
        let @" = a:data
        silent! let @* = a:data
        silent! let @+ = a:data
    endf

    fun! s:commits_sink(lines)
        if len(a:lines) < 2
            return
        en

        let pat = '[0-9a-f]\{7,9}'

        if a:lines[0] == 'ctrl-y'
            let hashes = join(filter(map(a:lines[1:], 'matchstr(v:val, pat)'), 'len(v:val)'))
            return s:yank_to_register(hashes)
        end

        let diff = a:lines[0] == 'ctrl-d'
        let cmd = s:action_for(a:lines[0], 'e')
        let buf = bufnr('')
        for idx in range(1, len(a:lines) - 1)
            let sha = matchstr(a:lines[idx], pat)
            if !empty(sha)
                if diff
                    if idx > 1
                        exe     'tab sb' buf
                    en
                    exe     'Gdiff' sha
                el
                    " Since fugitive buffers are unlisted, we can't keep using 'e'
                    let c = (cmd == 'e' && idx > 1) ? 'tab split' : cmd
                    exe     c FugitiveFind(sha)
                en
            en
        endfor
    endf

    fun! s:commits(buffer_local, args)
        let s:git_root = s:get_git_root()
        if empty(s:git_root)
            return s:warn('Not in git repository')
        en

        let source = 'git log '.get(g:, 'fzf_commits_log_options', '--color=always '.skim#shellescape('--format=%C(auto)%h%d %s %C(green)%cr'))
        let current = expand('%')
        let managed = 0
        if !empty(current)
            call system('git show '.skim#shellescape(current).' 2> '.(s:is_win ? 'nul' : '/dev/null'))
            let managed = !v:shell_error
        en

        if a:buffer_local
            if !managed
                return s:warn('The current buffer is not in the working tree')
            en
            let source .= ' --follow '.skim#shellescape(current)
        el
            let source .= ' --graph'
        en

        let command = a:buffer_local ? 'BCommits' : 'Commits'
        let expect_keys = join(keys(get(g:, 'skim_action', s:default_action)), ',')
        let options = {
        \ 'source':  source,
        \ 'sink*':   s:function('s:commits_sink'),
        \ 'options': s:reverse_list(['--ansi', '--multi', '--tiebreak=index',
        \   '--inline-info', '--prompt', command.'> ', '--bind=ctrl-s:toggle-sort',
        \   '--header', ':: Press '.s:magenta('CTRL-S', 'Special').' to toggle sort, '.s:magenta('CTRL-Y', 'Special').' to yank commit hashes',
        \   '--expect=ctrl-y,'.expect_keys])
        \ }

        if a:buffer_local
            let options.options[-2] .= ', '.s:magenta('CTRL-D', 'Special').' to diff'
            let options.options[-1] .= ',ctrl-d'
        en

        if !s:is_win && &columns > s:wide
            call extend(options.options,
            \ ['--preview', 'echo {} | grep -o "[a-f0-9]\{7,\}" | head -1 | xargs git show --format=format: --color=always | head -1000'])
        en

        return s:fzf(a:buffer_local ? 'bcommits' : 'commits', options, a:args)
    endf

    fun! fzf#vim#commits(...)
        return s:commits(0, a:000)
    endf

    fun! fzf#vim#buffer_commits(...)
        return s:commits(1, a:000)
    endf

" fzf#vim#maps(mode, opts[with count and op])
    fun! s:align_pairs(list)
        let maxlen = 0
        let pairs = []
        for elem in a:list
            let match = matchlist(elem, '^\(\S*\)\s*\(.*\)$')
            let [_, k, v] = match[0:2]
            let maxlen = max([maxlen, len(k)])
            call add(pairs, [k, substitute(v, '^\*\?[@ ]\?', '', '')])
        endfor
        let maxlen = min([maxlen, 35])
        return map(pairs, "printf('%-'.maxlen.'s', v:val[0]).' '.v:val[1]")
    endf

    fun! s:highlight_keys(str)
        return substitute(
                    \ substitute(a:str, '<[^ >]\+>', s:yellow('\0', 'Special'), 'g'),
                    \ '<Plug>', s:blue('<Plug>', 'SpecialKey'), 'g')
    endf

    fun! s:key_sink(line)
        let key = matchstr(a:line, '^\S*')
        redraw
        call feedkeys(s:map_gv.s:map_cnt.s:map_reg, 'n')
        call feedkeys(s:map_op.
                    \ substitute(key, '<[^ >]\+>', '\=eval("\"\\".submatch(0)."\"")', 'g'))
    endf

    fun! fzf#vim#maps(mode, ...)
        let s:map_gv  = a:mode == 'x' ? 'gv' : ''
        let s:map_cnt = v:count == 0 ? '' : v:count
        let s:map_reg = empty(v:register) ? '' : ('"'.v:register)
        let s:map_op  = a:mode == 'o' ? v:operator : ''

        redir => cout
        silent execute 'verbose' a:mode.'map'
        redir END
        let list = []
        let curr = ''
        for line in split(cout, "\n")
            if line =~ "^\t"
                let src = "\t".substitute(matchstr(line, '/\zs[^/\\]*\ze$'), ' [^ ]* ', ':', '')
                call add(list, printf('%s %s', curr, s:green(src, 'Comment')))
                let curr = ''
            el
                if !empty(curr)
                    call add(list, curr)
                en
                let curr = line[3:]
            en
        endfor
        if !empty(curr)
            call add(list, curr)
        en
        let aligned = s:align_pairs(list)
        let sorted  = sort(aligned)
        let colored = map(sorted, 's:highlight_keys(v:val)')
        let pcolor  = a:mode == 'x' ? 9 : a:mode == 'o' ? 10 : 12
        return s:fzf('maps', {
        \ 'source':  colored,
        \ 'sink':    s:function('s:key_sink'),
        \ 'options': '--prompt "Maps ('.a:mode.')> " --ansi --no-hscroll --nth 1,.. --color prompt:'.pcolor}, a:000)
    endf

" fzf#vim#complete - completion helper
    ino      <silent> <Plug>(-fzf-complete-trigger)   <c-o>:call <sid>complete_trigger()<cr>

    fun! s:pluck(dict, key, default)
        return has_key(a:dict, a:key) ? remove(a:dict, a:key) : a:default
    endf

    fun! s:complete_trigger()
        let opts = copy(s:opts)
        call s:prepend_opts(
            \ opts,
            \ ['-m', '-q', s:query],
           \ )
        let opts['sink*'] = s:function('s:complete_insert')
        let s:reducer = s:pluck(
            \ opts,
            \ 'reducer',
            \ s:function('s:first_line'),
           \ )
        call skim#run(opts)
    endf

    " The default reducer
    fun! s:first_line(lines)
        return a:lines[0]
    endf

    fun! s:complete_insert(lines)
        if empty(a:lines)
            return
        en

        let chars = strchars(s:query)
        if     chars == 0 | let del = ''
        elseif chars == 1 | let del = '"_x'
        el              | let del = (chars - 1).'"_dvh'
        en

        let data = call(s:reducer, [a:lines])
        let ve = &ve
        set ve=
        exe     'normal!' ((s:eol || empty(chars)) ? '' : 'h').del.(s:eol ? 'a': 'i').data
        let &ve = ve
        if mode() =~ 't'
            call feedkeys('a', 'n')
        el
            exe     "normal! \<esc>la"
        en
    endf

    fun! s:eval(dict, key, arg)
        if has_key(a:dict, a:key) && type(a:dict[a:key]) == s:TYPE.funcref
            let ret = copy(a:dict)
            let ret[a:key] = call(a:dict[a:key], [a:arg])
            return ret
        en
        return a:dict
    endf

    fun! fzf#vim#complete(...)
        if a:0 == 0
            let s:opts = skim#wrap()
        elseif type(a:1) == s:TYPE.dict
            let s:opts = copy(a:1)
        elseif type(a:1) == s:TYPE.string
            let s:opts = extend({'source': a:1}, get(a:000, 1, skim#wrap()))
        el
            echoerr 'Invalid argument: '.string(a:000)
            return ''
        en
        for s in ['sink', 'sink*']
            if has_key(s:opts, s)
                call remove(s:opts, s)
            en
        endfor

        let eol = col('$')
        let ve = &ve
        set ve=all
        let s:eol = col('.') == eol
        let &ve = ve

        let Prefix = s:pluck(s:opts, 'prefix', '\k*$')
        if col('.') == 1
            let s:query = ''
        el
            let full_prefix = getline('.')[0 : col('.')-2]
            if type(Prefix) == s:TYPE.funcref
                let s:query = call(Prefix, [full_prefix])
            el
                let s:query = matchstr(full_prefix, Prefix)
            en
        en
        let s:opts = s:eval(s:opts, 'source', s:query)
        let s:opts = s:eval(s:opts, 'options', s:query)
        let s:opts = s:eval(s:opts, 'extra_options', s:query)
        if has_key(s:opts, 'extra_options')
            call s:merge_opts(s:opts, remove(s:opts, 'extra_options'))
        en
        if has_key(s:opts, 'options')
            if type(s:opts.options) == s:TYPE.list
                call add(s:opts.options, '--no-expect')
            el
                let s:opts.options .= ' --no-expect'
            en
        en

        call feedkeys("\<Plug>(-fzf-complete-trigger)")
        return ''
    endf

let &cpo = s:cpo_save
unlet s:cpo_save
