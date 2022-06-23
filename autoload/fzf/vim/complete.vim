let s:cpo_save = &cpo
set cpo&vim
let s:is_win = has('win32') || has('win64')

fun! s:extend(base, extra)
    let base = copy(a:base)
    if has_key(a:extra, 'options')
        let extra = copy(a:extra)
        let extra.extra_options = remove(extra, 'options')
        return extend(base, extra)
    en
    return extend(base, a:extra)
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

fun! fzf#vim#complete#word(...)
    return fzf#vim#complete(s:extend({
        \ 'source': 'cat /usr/share/dict/words'},
        \ get(a:000, 0, skim#wrap())))
endf

" ----------------------------------------------------------------------------
" <plug>(fzf-complete-path)
" <plug>(fzf-complete-file)
" <plug>(fzf-complete-file-ag)
" ----------------------------------------------------------------------------
fun! s:file_split_prefix(prefix)
    let expanded = expand(a:prefix)
    let slash = (s:is_win && !&shellslash) ? '\\' : '/'
    return isdirectory(expanded) ?
        \ [expanded,
        \  substitute(a:prefix, '[/\\]*$', slash, ''),
        \  ''] :
        \ [fnamemodify(expanded, ':h'),
        \  substitute(fnamemodify(a:prefix, ':h'), '[/\\]*$', slash, ''),
        \  fnamemodify(expanded, ':t')]
endf

fun! s:file_source(prefix)
    let [dir, head, tail] = s:file_split_prefix(a:prefix)
    return printf(
        \ "cd %s && ".s:file_cmd." | sed %s",
        \ skim#shellescape(dir), skim#shellescape('s:^:'.(empty(a:prefix) || a:prefix == tail ? '' : head).':'))
endf

fun! s:file_options(prefix)
    let [_, head, tail] = s:file_split_prefix(a:prefix)
    return ['--prompt', head, '--query', tail]
endf

fun! s:fname_prefix(str)
    let isf = &isfname
    let white = []
    let black = []
    if isf =~ ',,,'
        call add(white, ',')
        let isf = substitute(isf, ',,,', ',', 'g')
    en
    if isf =~ ',^,,'
        call add(black, ',')
        let isf = substitute(isf, ',^,,', ',', 'g')
    en

    for token in split(isf, ',')
        let target = white
        if token[0] == '^'
            let target = black
            let token = token[1:]
        en

        let ends = matchlist(token, '\(.\+\)-\(.\+\)')
        if empty(ends)
            call add(target, token)
        el
            let ends = map(ends[1:2], "len(v:val) == 1 ? char2nr(v:val) : str2nr(v:val)")
            for i in range(ends[0], ends[1])
                call add(target, nr2char(i))
            endfor
        en
    endfor

    let prefix = a:str
    for offset in range(1, len(a:str))
        let char = a:str[len(a:str) - offset]
        if (char =~ '\w' || index(white, char) >= 0) && index(black, char) < 0
            continue
        en
        let prefix = strpart(a:str, len(a:str) - offset + 1)
        break
    endfor

    return prefix
endf

fun! fzf#vim#complete#path(command, ...)
    let s:file_cmd = a:command
    return fzf#vim#complete(s:extend({
    \ 'prefix':  s:function('s:fname_prefix'),
    \ 'source':  s:function('s:file_source'),
    \ 'options': s:function('s:file_options')}, get(a:000, 0, skim#wrap())))
endf

" ----------------------------------------------------------------------------
" <plug>(fzf-complete-line)
" <plug>(fzf-complete-buffer-line)
" ----------------------------------------------------------------------------
fun! s:reduce_line(lines)
    return join(split(a:lines[0], '\t\zs')[3:], '')
endf


fun! fzf#vim#complete#line(...)
    let [display_bufnames, lines] = fzf#vim#_lines(0)
    let nth = display_bufnames ? 4 : 3
    return fzf#vim#complete(s:extend({
    \ 'prefix':  '^.*$',
    \ 'source':  lines,
    \ 'options': '--tiebreak=index --ansi --nth '.nth.'.. --tabstop=1',
    \ 'reducer': s:function('s:reduce_line')}, get(a:000, 0, skim#wrap())))
endf

fun! fzf#vim#complete#buffer_line(...)
    return fzf#vim#complete(s:extend({
    \ 'prefix': '^.*$',
    \ 'source': fzf#vim#_uniq(getline(1, '$'))}, get(a:000, 0, skim#wrap())))
endf

let &cpo = s:cpo_save
unlet s:cpo_save

