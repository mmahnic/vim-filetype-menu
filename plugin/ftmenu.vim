" vim:set fileencoding=utf-8 sw=3 ts=8 et:vim "
" ftmenu.vim - Create a 'Mode' menu based on te current file type
"    1. Plugins that register their menus will have them created as needed
"    2. A workaround is provided for other plugins
"
" Author: Marko Mahnič
" Created: December 2010
" License: Vim License ( :h license )
" This program comes with ABSOLUTELY NO WARRANTY.

function! s:StartupStuff()
   if exists("g:ftmenu_mode_menus") 
      for mnk in keys(g:ftmenu_mode_menus)
         call ftmenu#AddWorkaround(mnk, g:ftmenu_mode_menus[mnk])
      endfor
      unlet g:ftmenu_mode_menus
   endif

   call ftmenu#CaptureKnownMenus()
endfunc

augroup FtMenu
   au!
   au FileType * call ftmenu#RecreateFtMenu(0)
   au BufEnter * call ftmenu#RecreateFtMenu(0)
   au VimEnter * call <SID>StartupStuff()
augroup END

" Force RecreateFtMenu
command RecreateFtMenu  :call ftmenu#RecreateFtMenu(1)

