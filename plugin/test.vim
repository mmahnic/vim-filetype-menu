
" From vxlib/plugin.vim
let s:sid_script = "map <SID>xx <SID>xx\n" .
         \ "let s:SID = substitute(maparg('<SID>xx'), '<SNR>\\(\\d\\+_\\)xx$', '\\1', '') \n" .
         \ "unmap <SID>xx\n" .
         \ "let s:SNR = '<SNR>' . s:SID"
exec s:sid_script

function s:T_Python(menu)
   exec "80menu " . a:menu . ".FT\\ Menu\\ Test :echom 'Python menu works'<cr>"
endfunc

function s:T_Vim(menu)
   exec "80menu " . a:menu . ".FT\\ Menu\\ Test :echom 'Vim menu works'<cr>"
endfunc

function s:Test()
   " This part is done by the plugins
   call AddFtMenuHook('python', s:SNR . "T_Python")
   call AddFtMenuHook('vim', s:SNR . "T_Vim")

   " Workaronds are provided by the user in vimrc. Unforutnately
   " AddFtWorkaround is not available in vimrc, so a global variable will have
   " to be used for that:
   "    let g:ftmenu_workaround = { 
   "         \ 'python': ['Python', 'IM-Python=>&Buffer'],
   "    ...  \ }
   call AddFtWorkaround('python', ['Python', 'IM-Python=>&Buffer'])
   call AddFtWorkaround('sh', ['Bash'])
   call AddFtWorkaround('perl', ['Perl'])
   call AddFtWorkaround('lua', ['Lua'])
   call AddFtWorkaround('html', ['HTML', 'XHtml'])
   " django-templates : replace <a0> with \<space> in code
   call AddFtWorkaround('htmldjango', ['HTML', 'XHtml', 'Django templates=>&Django'])
   call AddFtWorkaround('xhtml', ['XHtml'])

   " 'Global' functions should not be in the mode menu, but for testing it's ok
   call AddFtWorkaround('viki', ['Plugin.Viki'])
endfunc

call s:Test()

