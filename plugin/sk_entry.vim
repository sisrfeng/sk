let s:cpo_save = &cpo
set cpo&vim

let s:is_win = has('win32') || has('win64')

fun! s:defs(commands)
    let prefix = get(g:, 'fzf_command_prefix', '')
    if prefix =~# '^[^A-Z]'
        echoerr 'g:fzf_command_prefix must start with an uppercase letter'
        return
    en
    for command in a:commands
        let name = ':'.prefix.matchstr(command, '\C[A-Z]\S\+')
        if 2 != exists(name)
            exe     substitute(command, '\ze\C[A-Z]', prefix, '')
        en
    endfor
endf

fun! s:p(bang, ...)
    let preview_window = get(
        \ g:,
        \ 'fzf_preview_window',
        \ a:bang && &columns >= 80 || &columns >= 120 ? 'right': '',
       \ )
    if len(preview_window)
        return call(
            \ 'fzf#vim#with_preview',
            \ add(copy(a:000), preview_window),
           \ )
    en
    return {}
endf

call s:defs([
    \  'com!      -bang -nargs=? -complete=dir Files       call fzf#vim#files(<q-args>, s:p(<bang>0), <bang>0)',
    \  'com!      -bang -nargs=? GFiles                    call fzf#vim#gitfiles(<q-args>, <q-args> == "?" ? {} : s:p(<bang>0), <bang>0)',
    \  'com! -bar -bang -nargs=? -complete=buffer Buffers  call fzf#vim#buffers(<q-args>, s:p(<bang>0, { "placeholder": "{1}" }), <bang>0)',
    \  'com!      -bang -nargs=* Lines                     call fzf#vim#lines(<q-args>, <bang>0)',
    \  'com!      -bang -nargs=* BLines                    call fzf#vim#buffer_lines(<q-args>, <bang>0)',
    \  'com! -bar -bang Colors                             call fzf#vim#colors(<bang>0)',
    \  'com!      -bang -nargs=+ -complete=dir Locate      call fzf#vim#locate(<q-args>, s:p(<bang>0), <bang>0)',
    \  'com!      -bang -nargs=* Rg                        call fzf#vim#rg_interactive(<q-args>, s:p(<bang>0), <bang>0)',
    \  'com!      -bang -nargs=* Tags                      call fzf#vim#tags(<q-args>, <bang>0)',
    \  'com!      -bang -nargs=* BTags                     call fzf#vim#buffer_tags(<q-args>, s:p(<bang>0, { "placeholder": "{2}:{3}" }), <bang>0)',
    \  'com! -bar -bang Snippets                           call fzf#vim#snippets(<bang>0)',
    \  'com! -bar -bang Commands                           call fzf#vim#commands(<bang>0)',
    \  'com! -bar -bang Marks                              call fzf#vim#marks(<bang>0)',
    \  'com! -bar -bang Helptags                           call fzf#vim#helptags(<bang>0)',
    \  'com! -bar -bang Windows                            call fzf#vim#windows(<bang>0)',
    \  'com! -bar -bang Commits                            call fzf#vim#commits(<bang>0)',
    \  'com! -bar -bang BCommits                           call fzf#vim#buffer_commits(<bang>0)',
    \  'com! -bar -bang Maps                               call fzf#vim#maps("n", <bang>0)',
    \  'com! -bar -bang Filetypes                          call fzf#vim#filetypes(<bang>0)',
    \  'com!      -bang -nargs=* History                   call s:history(<q-args>, s:p(<bang>0), <bang>0)'])

fun! s:history(arg, extra, bang)
    let bang = a:bang || a:arg[len(a:arg)-1] == '!'
    if a:arg[0] == ':'
        call fzf#vim#command_history(bang)
    elseif a:arg[0] == '/'
        call fzf#vim#search_history(bang)
    el
        call fzf#vim#history(a:extra, bang)
    en
endf

fun! fzf#complete(...)
    return call('fzf#vim#complete', a:000)
endf

if (has('nvim') || has('terminal') && has('patch-8.0.995')) && (get(g:, 'fzf_statusline', 1) || get(g:, 'fzf_nvim_statusline', 1))
    fun! s:fzf_restore_colors()
        if exists('#User#FzfStatusLine')
            doautocmd User FzfStatusLine
        el
            if $TERM !~ "256color"
                hi default fzf1 ctermfg=1 ctermbg=8 guifg=#E12672 guibg=#565656
                hi default fzf2 ctermfg=2 ctermbg=8 guifg=#BCDDBD guibg=#565656
                hi default fzf3 ctermfg=7 ctermbg=8 guifg=#D9D9D9 guibg=#565656
            el
                hi default fzf1 ctermfg=161 ctermbg=238 guifg=#E12672 guibg=#565656
                hi default fzf2 ctermfg=151 ctermbg=238 guifg=#BCDDBD guibg=#565656
                hi default fzf3 ctermfg=252 ctermbg=238 guifg=#D9D9D9 guibg=#565656
            en
            setl     statusline=%#fzf1#\ >\ %#fzf2#sk%#fzf3#im
        en
    endf

    fun! s:fzf_vim_term()
        if get(w:, 'airline_active', 0)
            let w:airline_disabled = 1
            autocmd BufWinLeave <buffer> let w:airline_disabled = 0
        en
        autocmd WinEnter,ColorScheme <buffer> call s:fzf_restore_colors()

        setl     nospell
        call s:fzf_restore_colors()
    endf

    augroup _fzf_statusline
        autocmd!
        autocmd FileType skim call s:fzf_vim_term()
    augroup END
en

if !exists('g:fzf#vim#buffers')
    let g:fzf#vim#buffers = {}
en

augroup fzf_buffers
    autocmd!
    if exists('*reltimefloat')
        autocmd BufWinEnter,WinEnter * let g:fzf#vim#buffers[bufnr('')] = reltimefloat(reltime())
    el
        autocmd BufWinEnter,WinEnter * let g:fzf#vim#buffers[bufnr('')] = localtime()
    en
    autocmd BufDelete * silent! call remove(g:fzf#vim#buffers, expand('<abuf>'))
augroup END

ino      <expr> <plug>(fzf-complete-word)        fzf#vim#complete#word()
if s:is_win
    ino      <expr> <plug>(fzf-complete-path)      fzf#vim#complete#path('dir /s/b')
    ino      <expr> <plug>(fzf-complete-file)      fzf#vim#complete#path('dir /s/b/a:-d')
el
    ino      <expr> <plug>(fzf-complete-path)      fzf#vim#complete#path("find . -path '*/\.*' -prune -o -print \| sed '1d;s:^..::'")
    ino      <expr> <plug>(fzf-complete-file)      fzf#vim#complete#path("find . -path '*/\.*' -prune -o -type f -print -o -type l -print \| sed 's:^..::'")
en
ino      <expr> <plug>(fzf-complete-line)        fzf#vim#complete#line()
ino      <expr> <plug>(fzf-complete-buffer-line) fzf#vim#complete#buffer_line()

nno      <silent> <plug>(fzf-maps-n) :<c-u>call fzf#vim#maps('n', 0)<cr>
ino      <silent> <plug>(fzf-maps-i) <c-o>:call fzf#vim#maps('i', 0)<cr>
xnoremap <silent> <plug>(fzf-maps-x) :<c-u>call fzf#vim#maps('x', 0)<cr>
onoremap <silent> <plug>(fzf-maps-o) <c-c>:<c-u>call fzf#vim#maps('o', 0)<cr>

let &cpo = s:cpo_save
unlet s:cpo_save

