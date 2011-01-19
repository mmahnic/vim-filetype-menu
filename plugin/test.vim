
" From vxlib/plugin.vim
let s:sid_script = "map <SID>xx <SID>xx\n" .
         \ "let s:SID = substitute(maparg('<SID>xx'), '<SNR>\\(\\d\\+_\\)xx$', '\\1', '') \n" .
         \ "unmap <SID>xx\n" .
         \ "let s:SNR = '<SNR>' . s:SID"
exec s:sid_script

function s:T_Python(priority, menu)
   exec a:priority . "amenu " . a:menu . ".FT\\ Menu\\ Test :echom 'Python menu works'<cr>"
endfunc

function s:T_Vim(priority, menu)
   exec a:priority . "amenu " . a:menu . ".FT\\ Menu\\ Test :echom 'Vim menu works'<cr>"
   exec a:priority . "amenu " . a:menu . ".&Source :so %<cr>"
endfunc

function s:TestHooks()
   " This part is done by the plugins
   call ftmenu#RegisterHook("T_Python", s:SNR . "T_Python")
   call ftmenu#AddHook('python', "T_Python")
   call ftmenu#RegisterHook("T_Vim", s:SNR . "T_Vim")
   call ftmenu#AddHook('vim', "T_Vim")
endfunc

function s:TestWorkarounds()
   " Workaronds are provided by the user in vimrc. Unforutnately
   " AddFtWorkaround is not available in vimrc, so a global variable will have
   " to be used for that:
   "    let g:ftmenu_prebuilt_menus = { 
   "         \ 'python': ['Python', 'IM-Python=>&Buffer'],
   "    ...  \ }
   call ftmenu#AddPrebuiltMenu('python', ['Python', 'IM-Python=>&Buffer'])
   call ftmenu#AddPrebuiltMenu('sh', ['Bash'])
   call ftmenu#AddPrebuiltMenu('perl', ['Perl'])
   call ftmenu#AddPrebuiltMenu('lua', ['Lua'])

   " HTML wants to disable menu items when switching buffers
   "    => some code removed from HTML.vim#MenuControl()
   call ftmenu#AddPrebuiltMenu('html', ['HTML', 'XHtml=>&XHtml'])

   " django-templates: encoding problem; replace <a0> with \<space> in code
   call ftmenu#AddPrebuiltMenu('htmldjango', ['XHtml', 'HTML=>&Html', 'Django templates=>&Django'])
   call ftmenu#AddPrebuiltMenu('xhtml', ['XHtml', 'HTML=>&Html'])

   " 'Global' functions should not be in the mode menu, but for testing it's ok
   call ftmenu#AddPrebuiltMenu('viki', ['Plugin.Viki'])

   let g:ftmenu_move_menus = [
            \ ['Bash.Help', 'Help.&Bash'],
            \ ]

   " Timing: gvim --startuptime out
   "
   " Plugins bash-support and perl-support create _huge_ menus. Plugin
   " filetype-menu captures and deletes registered menus in VimEnter.
   "
   " bash-support: 56ms      3.5%
   " perl-support: 87ms      5.4%
   " Starting GUI: 552ms    34.7%
   " VimEnter: 660ms        41.5%
   " VIM Started: 1590ms
endfunc

function s:TestMoveMenu()
   call ftmenu#MoveMenu('Tools.Spelling', '&Test.Move&Spelling')

   let entries = ftmenu#CaptureMenu('Tools.Folding', [])
   call ftmenu#CreateMenu('&Test.Copy&Folding', entries)

   " Real example
   call ftmenu#MoveMenu('DrChip.AlignMaps', 'Plugin.DrChip-&Align')
endfunc

function s:MakeTestMenu()
   menu   Test.Menu  :
   amenu  Test.AMenu  :
   noremenu Test.NoReMenu :
   anoremenu Test.ANoReMenu :

   menu    Test.Mix-Menu-VMenu :
   vmenu   Test.Mix-Menu-VMenu :

   noremenu Test.Mix-NoReMenu-VMenu :
   vmenu    Test.Mix-NoReMenu-VMenu :
endfunc

function! s:Test()
   call s:MakeTestMenu()
   call s:TestHooks()
   call s:TestWorkarounds()
   call s:TestMoveMenu()
endfunc

call s:Test()

