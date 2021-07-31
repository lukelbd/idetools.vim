"------------------------------------------------------------------------------"
" Author: Luke Davis (lukelbd@gmail.com)
" Date:   2018-09-09
" A collection of IDE-like tools for vim. See README.md for details.
"------------------------------------------------------------------------------"
" * Each element of the b:ctags list (and similar lists) is as follows:
"     Index 0: Tag name.
"     Index 1: Tag line number.
"     Index 2: Tag type.
" * Made my own implementation instead of using easytags or gutentags, because
"   (1) find that :tag and :pop are not that useful outside of help menus --
"   generally only want to edit one file at a time, and the <C-]> is about as
"   reliable as gd or gD, and (2) now I can filter the most important tags
"   and make them searchable, without losing the completion popup you'd get
"   from :tagjump /<Tab>.
" * General searching/replacing utilities, useful for refactoring. A convervative
"   approach is taken for the most part -- global searches are not automatic. But
"   could expand functionality by adding s*, s# maps to go along with c*, c# maps,
"   which replace every choice without user confirmation. Or C*, C# would work.
" * Re-define a few of the shift-number row keys to make them a bit more useful:
"     '*' is the current word, global
"     '&' is the current WORD, global
"     '#' is the current word, local
"     '@' is the current WORD, local
"   This made sense for my workflow because I never really want the backward
"   search from '#', access my macros with the comma key instead of @, and the
"   & key goes pretty much untouched.
" * For c* and c# map origin, see:
"   https://www.reddit.com/r/vim/comments/8k4p6v/what_are_your_best_mappings/
"   https://www.reddit.com/r/vim/comments/2p6jqr/quick_replace_useful_refactoring_and_editing_tool/
" * For repeat.vim usage see:
"   http://vimcasts.org/episodes/creating-repeatable-mappings-with-repeat-vim/
call system('type ctags &>/dev/null')
if v:shell_error " exit code
  echohl WarningMsg
  echom 'Error: vim-tagtools requires the command-line tool ctags, not found.'
  echohl None
  finish
endif
set cpoptions+=d
augroup tagtools
  au!
  au InsertLeave * call tagtools#change_repeat() " magical c* searching function
  au BufRead,BufWritePost * call tagtools#ctags_update()
augroup END

" Files that we wish to ignore
if !exists('g:tagtools_filetypes_skip')
  let g:tagtools_filetypes_skip = ['diff', 'help', 'man', 'qf']
endif

" List of per-file/per-filetype tag categories that we define as 'scope-delimiters',
" i.e. tags approximately denoting boundaries for variable scope of code block underneath cursor
if !exists('g:tagtools_filetypes_top_tags')
  let g:tagtools_filetypes_top_tags = {}
endif

" List of files for which we only want not just the 'top level' tags (i.e. tags
" that do not belong to another block, e.g. a program or subroutine)
if !exists('g:tagtools_filetypes_all_tags')
  let g:tagtools_filetypes_all_tags = []
endif

" Default mappings
if !exists('g:tagtools_ctags_jump_map')
  let g:tagtools_ctags_jump_map = '<Leader><Leader>'
endif
if !exists('g:tagtools_ctags_backward_map')
  let g:tagtools_ctags_backward_map = '[t'
endif
if !exists('g:tagtools_ctags_forward_map')
  let g:tagtools_ctags_forward_map = ']t'
endif
if !exists('g:tagtools_ctags_backward_top_map')
  let g:tagtools_ctags_backward_top_map = '[T'
endif
if !exists('g:tagtools_ctags_forward_top_map')
  let g:tagtools_ctags_forward_top_map = ']T'
endif
exe 'nmap ' . g:tagtools_ctags_jump_map . ' <Plug>CtagsJump'
exe 'map <silent> ' . g:tagtools_ctags_forward_map . ' <Plug>CtagsForwardAll'
exe 'map <silent> ' . g:tagtools_ctags_backward_map . ' <Plug>CtagsBackwardAll'
exe 'map <silent> ' . g:tagtools_ctags_forward_top_map . ' <Plug>CtagsForwardTop'
exe 'map <silent> ' . g:tagtools_ctags_backward_top_map . ' <Plug>CtagsBackwardTop'

"-----------------------------------------------------------------------------"
" Ctags commands and maps
"-----------------------------------------------------------------------------"
" Commands
command! Ctags call tagtools#ctags_show()
command! CtagsUpdate call tagtools#ctags_update()

" Mappings
" Note: Must use :n instead of <expr> ngg so we can use <C-u> to discard count!
noremap <expr> <silent> <Plug>CtagsForwardAll tagtools#ctag_jump(1, v:count, 0)
noremap <expr> <silent> <Plug>CtagsBackwardAll tagtools#ctag_jump(0, v:count, 0)
noremap <expr> <silent> <Plug>CtagsForwardTop tagtools#ctag_jump(1, v:count, 1)
noremap <expr> <silent> <Plug>CtagsBackwardTop tagtools#ctag_jump(0, v:count, 1)

" Jump map with FZF
nnoremap <silent> <Plug>CtagsJump
  \ :if exists('*fzf#run') \| call fzf#run({
  \ 'source': tagtools#ctags_menu(),
  \ 'sink': function('tagtools#ctags_select'),
  \ 'options': "--no-sort --prompt='Ctag> '",
  \ 'down': '~20%',
  \ }) \| endif<CR>

"------------------------------------------------------------------------------"
" Refactoring tool maps
"------------------------------------------------------------------------------"
" Driver function *must* be in here because cannot issue normal! in
" autoload folder evidently
function! s:replace_occurence() abort
  " Get lines and columns for next occurence without messing up window/register
  let [l0, c0] = getpos('.')[1:2]
  let reg = getreg('"')
  let regmode = getregtype('"')
  let winview = winsaveview()
  normal! ygn
  let [l1, c1] = getpos("'[")[1:2] " first char of yanked text
  let [l2, c2] = getpos("']")[1:2] " last char of yanked text
  call setreg('"', reg, regmode)
  call winrestview(winview)

  " Replace next occurence with previously inserted text
  if l0 >= l1 && l0 <= l2 && c0 >= c1 && c0 <= c2
    exe "silent! normal! cgn\<C-a>\<Esc>"
  endif
  silent! normal! n
  call repeat#set("\<Plug>replace_occurence")
endfunction

" Mapping for vim-repeat command
nnoremap <silent> <Plug>replace_occurence :call <sid>replace_occurence()<CR>

" Global and local <cword> and global and local <cWORD> searches, and current character
nnoremap <silent> <expr> * tagtools#set_search('*')
nnoremap <silent> <expr> & tagtools#set_search('&')
nnoremap <silent> <expr> # tagtools#set_search('#')
nnoremap <silent> <expr> @ tagtools#set_search('@')
nnoremap <silent> <expr> ! tagtools#set_search('!')
" Search within function scope
nnoremap <silent> <expr> g/ '/' . tagtools#get_scope()
nnoremap <silent> <expr> g? '?' . tagtools#get_scope()
" Count number of occurrences for match under cursor
nnoremap <silent> <Leader>* :echom 'Number of "' . expand('<cword>') . '" occurences: ' . system('grep -c "\b"' . shellescape(expand('<cword>')) . '"\b" ' . expand('%'))<CR>
nnoremap <silent> <Leader>& :echom 'Number of "' . expand('<cWORD>') . '" occurences: ' . system('grep -c "[ \n\t]"' . shellescape(expand('<cWORD>')) . '"[ \n\t]" ' . expand('%'))<CR>
nnoremap <silent> <Leader>. :echom 'Number of "' . @/ . '" occurences: ' . system('grep -c ' . shellescape(@/) . ' ' . expand('%'))<CR>

" Maps that replicate :d/regex/ behavior and can be repeated with '.'
nmap d/ <Plug>d/
nmap d* <Plug>d*
nmap d& <Plug>d&
nmap d# <Plug>d#
nmap d@ <Plug>d@
nnoremap <silent> <expr> <Plug>d/ tagtools#delete_next('d/')
nnoremap <silent> <expr> <Plug>d* tagtools#delete_next('d*')
nnoremap <silent> <expr> <Plug>d& tagtools#delete_next('d&')
nnoremap <silent> <expr> <Plug>d# tagtools#delete_next('d#')
nnoremap <silent> <expr> <Plug>d@ tagtools#delete_next('d@')

" Similar to the above, but replicates :s/regex/sub/ behavior -- the substitute
" value is determined by what user enters in insert mode, and the cursor jumps
" to the next map after leaving insert mode
nnoremap <silent> <expr> c/ tagtools#change_next('c/')
nnoremap <silent> <expr> c* tagtools#change_next('c*')
nnoremap <silent> <expr> c& tagtools#change_next('c&')
nnoremap <silent> <expr> c# tagtools#change_next('c#')
nnoremap <silent> <expr> c@ tagtools#change_next('c@')

" Maps as above, but this time delete or replace *all* occurrences
" Added a block to next_occurence function
nmap <silent> da/ :call tagtools#delete_all('d/')<CR>
nmap <silent> da* :call tagtools#delete_all('d*')<CR>
nmap <silent> da& :call tagtools#delete_all('d&')<CR>
nmap <silent> da# :call tagtools#delete_all('d#')<CR>
nmap <silent> da@ :call tagtools#delete_all('d@')<CR>
nmap <silent> ca/ :let g:iterate_occurences = 1<CR>c/
nmap <silent> ca* :let g:iterate_occurences = 1<CR>c*
nmap <silent> ca& :let g:iterate_occurences = 1<CR>c&
nmap <silent> ca# :let g:iterate_occurences = 1<CR>c#
nmap <silent> ca@ :let g:iterate_occurences = 1<CR>c@
