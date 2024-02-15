"------------------------------------------------------------------------------
" Author: Luke Davis (lukelbd@gmail.com)
" Date:   2018-09-09
" Tools for working with tags in vim. This plugin works as a lightweight companion to
" more comprehensive utilities like gutentags, offering tag jumping across open
" buffers and tag navigation and search-replace utilities within buffers.
"------------------------------------------------------------------------------
" Each element of the b:tags_* variables is as follows:
"   Index 0: Tag name.
"   Index 1: Tag line number.
"   Index 2: Tag type.
"   Index 3: Tag parent (optional).
" Re-define a few of the shift-number row keys to make them a bit more useful:
"   '*' is the current word, global
"   '&' is the current WORD, global
"   '#' is the current word, local
"   '@' is the current WORD, local
"------------------------------------------------------------------------------
call system('type ctags &>/dev/null')
if v:shell_error " exit code
  echohl WarningMsg
  echom 'Error: vim-tags requires the command-line tool ctags, not found.'
  echohl None
  finish
endif

" Initial stuff
set cpoptions+=d
augroup tags
  au!
  au InsertLeave * silent call tags#change_finish()  " finish change operation and set repeat
  au BufReadPost,BufWritePost * silent call tags#update_tags(expand('<afile>'))
augroup END

" Files that we wish to ignore
if !exists('g:tags_skip_filetypes')
  let g:tags_skip_filetypes = ['diff', 'help', 'man', 'qf']
endif

" List of per-file/per-filetype tag kinds to skip. Can also use .ctags config
if !exists('g:tags_skip_kinds')
  let g:tags_skip_kinds = {}
endif

" List of per-file/per-filetype tag kinds used as to for search scope and [T navigation
if !exists('g:tags_major_kinds')
  let g:tags_major_kinds = {}
endif

" List of per-file/per-filetype tag kinds skipped during [t navigation
if !exists('g:tags_minor_kinds')
  let g:tags_minor_kinds = {}
endif

" Default mapping settings
if !exists('g:tags_jump_map')
  let g:tags_jump_map = '<Leader><Leader>'
endif
if !exists('g:tags_drop_map')
  let g:tags_drop_map = '<Leader><Tab>'
endif
if !exists('g:tags_backward_map')
  let g:tags_backward_map = '[t'
endif
if !exists('g:tags_forward_map')
  let g:tags_forward_map = ']t'
endif
if !exists('g:tags_backward_top_map')
  let g:tags_backward_top_map = '[T'
endif
if !exists('g:tags_forward_top_map')
  let g:tags_forward_top_map = ']T'
endif

"-----------------------------------------------------------------------------
" Tag commands and maps
"-----------------------------------------------------------------------------
" Public commands
" Note: The tags#current_tag() is also used in vim-statusline plugin.
command! -nargs=0 CurrentTag echom 'Current tag: ' . tags#current_tag()
command! -bang -nargs=0 SelectTag call tags#select_tag(<bang>0)
command! -bang -nargs=* -complete=filetype ShowKinds
  \ echo call('tags#table_kinds', <bang>0 ? ['all'] : [<f-args>])
command! -bang -nargs=* -complete=file ShowTags
  \ echo call('tags#table_tags', <bang>0 ? ['all'] : [<f-args>])
command! -bang -nargs=* -complete=file UpdateTags
  \ call call('tags#update_tags', <bang>0 ? ['all'] : [<f-args>])

" Tag select maps
" Note: Must use :n instead of <expr> ngg so we can use <C-u> to discard count!
exe 'map ' . g:tags_jump_map . ' <Plug>TagsJump'
exe 'map ' . g:tags_drop_map . ' <Plug>TagsDrop'
exe 'map <silent> ' . g:tags_forward_map . ' <Plug>TagsForwardAll'
exe 'map <silent> ' . g:tags_backward_map . ' <Plug>TagsBackwardAll'
exe 'map <silent> ' . g:tags_forward_top_map . ' <Plug>TagsForwardTop'
exe 'map <silent> ' . g:tags_backward_top_map . ' <Plug>TagsBackwardTop'
noremap <Plug>TagsJump <Cmd>call tags#select_tag(0)<CR>
noremap <Plug>TagsDrop <Cmd>call tags#select_tag(1)<CR>
noremap <expr> <silent> <Plug>TagsForwardAll tags#jump_tag(v:count, 0, 1)
noremap <expr> <silent> <Plug>TagsBackwardAll tags#jump_tag(v:count, 0, 0)
noremap <expr> <silent> <Plug>TagsForwardTop tags#jump_tag(v:count, 1, 1)
noremap <expr> <silent> <Plug>TagsBackwardTop tags#jump_tag(v:count, 1, 0)

"------------------------------------------------------------------------------
" Refactoring commands and maps
"------------------------------------------------------------------------------
" Public commands
command! -nargs=1 -range Search
  \ let @/ = <line1> == <line2> ? <q-args> :
  \ printf('\%%>%dl\%%<%dl', <line1> - 1, <line2> + 1) . <q-args>
  \ | call feedkeys(tags#count_match('/'))

" Global and local <cword>, global and local <cWORD>, local forward and backward,
" and current character searches. Also include match counts.
" character search, and forward and backward local scope search.
" Note: current character copied from https://stackoverflow.com/a/23323958/4970632
" Todo: Add scope-local matches? No because use those for other mappings.
noremap * <Cmd>call tags#set_match('*', 1)<CR><Cmd>setlocal hlsearch<CR>
noremap & <Cmd>call tags#set_match('&', 1)<CR><Cmd>setlocal hlsearch<CR>
noremap # <Cmd>call tags#set_match('#', 1)<CR><Cmd>setlocal hlsearch<CR>
noremap @ <Cmd>call tags#set_match('@', 1)<CR><Cmd>setlocal hlsearch<CR>
noremap ! <Cmd>call tags#set_match('!', 1)<CR><Cmd>setlocal hlsearch<CR>
noremap g/ /<C-r>=tags#get_scope()<CR>
noremap g? ?<C-r>=tags#get_scope()<CR>

" Normal mode mappings that replicate :s/regex/sub/ behavior and can be repeated
" with '.'. The substitution is determined from the text inserted by the user and
" the cursor automatically jumps to the next match. The 'a' mappings change all matches.
nmap c* <Plug>c*
nmap c& <Plug>c&
nmap c# <Plug>c#
nmap c@ <Plug>c@
nmap c/ <Plug>c/
nmap c? <Plug>c?
nmap ca* <Cmd>let g:change_all = 1<CR><Plug>c*
nmap ca& <Cmd>let g:change_all = 1<CR><Plug>c&
nmap ca# <Cmd>let g:change_all = 1<CR><Plug>c#
nmap ca@ <Cmd>let g:change_all = 1<CR><Plug>c@
nmap ca/ <Cmd>let g:change_all = 1<CR><Plug>c/
nmap ca? <Cmd>let g:change_all = 1<CR><Plug>c?
nnoremap <Plug>c* <Cmd>call tags#change_next('c*')<CR>
nnoremap <Plug>c& <Cmd>call tags#change_next('c&')<CR>
nnoremap <Plug>c# <Cmd>call tags#change_next('c#')<CR>
nnoremap <Plug>c@ <Cmd>call tags#change_next('c@')<CR>
nnoremap <Plug>c/ <Cmd>call tags#change_next('c/')<CR>
nnoremap <Plug>c? <Cmd>call tags#change_next('c?')<CR>
nnoremap <Plug>change_again <Cmd>call tags#change_again()<CR>

" Normal mode mappings that replicate :d/regex/ behavior and can be repeated with '.'.
" Cursor automatically jumps to the next match. The 'a' mappings delete all matches.
nmap d* <Plug>d*
nmap d& <Plug>d&
nmap d# <Plug>d#
nmap d@ <Plug>d@
nmap d/ <Plug>d/
nmap d? <Plug>d?
nmap da* <Cmd>call tags#delete_all('d*')<CR>
nmap da& <Cmd>call tags#delete_all('d&')<CR>
nmap da# <Cmd>call tags#delete_all('d#')<CR>
nmap da@ <Cmd>call tags#delete_all('d@')<CR>
nmap da/ <Cmd>call tags#delete_all('d/')<CR>
nmap da? <Cmd>call tags#delete_all('d?')<CR>
nnoremap <Plug>d* <Cmd>call tags#delete_next('d*')<CR>
nnoremap <Plug>d& <Cmd>call tags#delete_next('d&')<CR>
nnoremap <Plug>d# <Cmd>call tags#delete_next('d#')<CR>
nnoremap <Plug>d@ <Cmd>call tags#delete_next('d@')<CR>
nnoremap <Plug>d/ <Cmd>call tags#delete_next('d/')<CR>
nnoremap <Plug>d? <Cmd>call tags#delete_next('d?')<CR>
