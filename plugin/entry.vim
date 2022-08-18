let s:cpo_save = &cpo  | set cpo&vim

let s:is_win = has('win32') || has('win64')

"\ preview
fun! s:pv(bang, ...)
    let preview_window = get(
                        \ g:                   ,
                        \ 'fzf_preview_window' ,
                           \ a:bang  && &columns >= 80
                        \ || &columns >= 120
                             \ ? 'right'
                              \: ''           ,
                       \ )
    if len(preview_window)
        return call(
              \ 'sk_funs#with_preview',
              \ add(copy(a:000), preview_window),
            \ )
    el
        return {}
    en
endf

fun! s:history(arg, extra, bang)
    let bang = a:bang
         \ || a:arg[ len(a:arg)-1 ] == '!'
    if a:arg[0] == ':'
        call sk_funs#command_history(bang)

    elseif a:arg[0] == '/'
        call sk_funs#search_history(bang)

    el
        call sk_funs#file_history(a:extra, bang)
    en
endf


com! -bang      -nargs=? -complete=dir Files       call sk_funs#files(<q-args>      , s:pv(<bang>0), <bang>0)
com! -bang      -nargs=? GFiles                    call sk_funs#git_files(<q-args>  , s:pv(<bang>0), <bang>0)
com! -bang      -nargs=? GStatus                   call sk_funs#git_status({}       , <bang>0)

com! -bang -bar -nargs=? -complete=buffer Buffers  call sk_funs#buffers(
                                                                  \ <q-args>,
                                                                  \ s:pv( <bang>0, { "placeholder": "{1}" } ),
                                                                  \ <bang>0,
                                                                \ )

com! -bang      -nargs=* Lines                     call sk_funs#Lines(<q-args>, <bang>0)
com! -bang      -nargs=* BLines                    call sk_funs#Buffer_Lines(<q-args>, <bang>0)

com! -bang      -nargs=+ -complete=dir Locate      call sk_funs#locate(<q-args>, s:pv(<bang>0), <bang>0)
com! -bang      -nargs=* Rg                        call sk_funs#rg_interactive(<q-args>, s:pv(<bang>0), <bang>0)
com! -bang      -nargs=* Tags                      call sk_funs#tags(<q-args>, <bang>0)
com! -bang      -nargs=* BTags                     call sk_funs#buffer_tags(<q-args>, s:pv(<bang>0, { "placeholder": "{2}:{3}" }), <bang>0)

com! -bang      -nargs=* History                   call s:history(<q-args>, s:pv(<bang>0), <bang>0)


com!  -bang -bar   Snippets            call sk_funs#snippets(<bang>0)
com!  -bang -bar   Commands            call sk_funs#commands(<bang>0)
com!  -bang -bar   Marks               call sk_funs#marks(<bang>0)
com!  -bang -bar   Helptags            call sk_funs#helptags(<bang>0)
com!  -bang -bar   Windows             call sk_funs#windows(<bang>0)
com!  -bang -bar   Commits             call sk_funs#commits(<bang>0)
com!  -bang -bar   BCommits            call sk_funs#buffer_commits(<bang>0)
com!  -bang -bar   Filetypes           call sk_funs#filetypes(<bang>0)



if (has('nvim')
\ || has('terminal')
    \ && has('patch-8.0.995'))
    \ && (get(g:, 'fzf_statusline', 1)
\ || get(g:, 'fzf_nvim_statusline', 1))
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
            au BufWinLeave <buffer> let w:airline_disabled = 0
        en
        au WinEnter,ColorScheme <buffer> call s:fzf_restore_colors()

        setl     nospell
        call s:fzf_restore_colors()
    endf

    aug  _fzf_statusline
        au!
        au FileType skim call s:fzf_vim_term()
    aug  END
en

if !exists('g:sk_funs#buffers')
    let g:sk_funs#buffers = {}
en

aug  fzf_buffers
    au!
    if exists('*reltimefloat')
        au BufWinEnter,WinEnter *   let g:sk_funs#buffers[bufnr('')] = reltimefloat(reltime())
    el
        au BufWinEnter,WinEnter *   let g:sk_funs#buffers[bufnr('')] = localtime()
    en
    au BufDelete * silent! call remove(g:sk_funs#buffers, expand('<abuf>'))
aug  END

"\ map
    ino      <expr> <plug>(fzf-complete-word)          sk_funs#complete#word()

    if s:is_win
        ino   <expr> <plug>(fzf-complete-path)      sk_funs#complete#path('dir /s/b')
        ino   <expr> <plug>(fzf-complete-file)      sk_funs#complete#path('dir /s/b/a:-d')
    el
        ino   <expr> <plug>(fzf-complete-path)      sk_funs#complete#path("find . -path '*/\.*' -prune -o -print \| sed '1d;s:^..::'")
        ino   <expr> <plug>(fzf-complete-file)      sk_funs#complete#path("find . -path '*/\.*' -prune -o -type f -print -o -type l -print \| sed 's:^..::'")
    en
    ino   <expr> <plug>(fzf-complete-line)        sk_funs#complete#line()
    ino   <expr> <plug>(fzf-complete-buffer-line) sk_funs#complete#buffer_line()

    nno   <silent> <plug>(fzf-maps-n)      :<c-u>call sk_funs#maps('n', 0)<cr>
    ino   <silent> <plug>(fzf-maps-i)      <c-o>:call sk_funs#maps('i', 0)<cr>
    xno   <silent> <plug>(fzf-maps-x)      :<c-u>call sk_funs#maps('x', 0)<cr>
    ono   <silent> <plug>(fzf-maps-o)      <c-c>:<c-u>call sk_funs#maps('o', 0)<cr>

let &cpo = s:cpo_save  | unlet s:cpo_save

