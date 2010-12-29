" vim:set fileencoding=utf-8 sw=3 ts=3 et:vim "
" ftmenu.vim - Create a 'Mode' menu based on te current file type
"    1. Plugins that register their menus will have them created as needed
"    2. A workaround is provided for other plugins
"
" Author: Marko Mahnič
" Created: December 2010
" License: Vim License ( :h license )
" This program comes with ABSOLUTELY NO WARRANTY.
"
" Note: AddFtMenuHook is similar to vimscript#1313, but more advanced

let s:debug = 0
let s:CurrentMode = ""
let s:CurrentMenu = ""

" Menus that were registered with the Mode-menu interface (AddFtMenu)
let s:MenuHooks = {}

" Menus that need workarounds, because they don't use the Mode-menu interface
let s:MenuCaptures = {}

" Wokrarounds defined by the user (AddFtWorkaround(mode, menunames))
let s:Workarounds = {}

" FileType menu hooks will be executed when the ft of the buffer is
" different than the ft of the current mode menu
function! AddFtMenuHook(filetype, function)
   if ! has_key(s:MenuHooks, a:filetype)
      let s:MenuHooks[a:filetype] = [ a:function ]
   else
      call add(s:MenuHooks[a:filetype], a:function)
   endif
endfunc

" The plugins that don't support Mode-menus may create some top-level
" menus. This function is used to bind top-level menus to filetypes.
function! AddFtWorkaround(filetype, menunames)
   if type(a:menunames) == type('')
      let menunames = [a:menunames]
   else
      let menunames = a:menunames
   endif
   call map(menunames, 'escape(substitute(v:val, "\\s*=>\\s*", "=>", ""), " ")')

   if ! has_key(s:Workarounds, a:filetype)
      let s:Workarounds[a:filetype] = menunames
   else
      call extend(s:Workarounds[a:filetype], menunames)
   endif
endfunc

" Check if the Mode-menu has to be recreated
function! s:RecreateFtMenu()
   if s:debug
      echom "RecreateFtMenu " . &ft
   endif
   if s:CurrentMode == &ft | return | endif
   if s:CurrentMenu != "" 
      try
         exec "aunmenu " . s:CurrentMenu
      catch
      endtry
   endif
   let s:CurrentMode = &ft
   if s:CurrentMode == ""
      let s:CurrentMenu = ""
      return
   endif

   let s:CurrentMenu = "&Mode-" .s:CurrentMode
   let s:CurrentMenu = substitute(s:CurrentMenu, '\s', '-', 'g')
   call s:CreateFtMenu(s:CurrentMode, s:CurrentMenu)
endfun

" Create Mode menu for curent filetype.
" 1. Captures the registered top-level menus and deletes them
" 2. Recreates the captured menus in the new menu
" 3. Calls registered menu-hooks
function! s:CreateFtMenu(filetype, menu)
   if has_key(s:Workarounds, a:filetype)
      let wrkrnds = s:Workarounds[a:filetype]
      for menumapdef in wrkrnds
         let inout = split(menumapdef, "=>")
         let existing = inout[0]
         if len(inout) > 1
            let newmenu = s:CurrentMenu . '.' . inout[1]
         else
            let newmenu = s:CurrentMenu
         endif
         let crv = s:CaptureMenu(existing)
         if crv >= 0
            try 
               exec "aunmenu " . existing
            catch
            endtry
         endif
         call s:CreateCapturedMenu(newmenu, existing)
      endfor
   endif

   if !has_key(s:MenuHooks, a:filetype) | return | endif

   for hook in s:MenuHooks[a:filetype]
      call call(hook, [a:menu])
   endfor
endfunc

function! s:CaptureMenu(menu)
   if s:debug
      echom "CaptureMenu " . a:menu
   endif
   let themenu = ""
   redir => l:themenu
   try
      exec "silent menu " . a:menu
      redir END
   catch
      redir END
      if s:debug
         echom "FAILED " . a:menu
      endif
      return -1
   endtry
   let lines = split(l:themenu, '\n')
   let menupath = []
   let priors   = []
   let level = -1
   let donemodes = ''

   let capMenus = []
   let capMenuIds = {}
   if has_key(s:MenuCaptures, a:menu)
      let capMenus = s:MenuCaptures[a:menu]
      let i = 0
      for mx in capMenus
         let capMenuIds[mx.id] = i
         let i = i + 1
      endfor
   endif

   for line in lines
      let mtitle = matchstr(line, '^\s*\d\+\s.\+') | " space digits space any
      if mtitle != ''
         " We have a title: push to stack or pop
         let parts = matchlist(line,  '^\(\s*\)\(\d\+\)\s\+\(.\+\)')
         let tlevel = len(parts[1]) / 2
         let pri = parts[2]
         let ttl = parts[3]
         let ttl = escape(ttl, " .")
         let ttl = substitute(ttl, '\^I', '<tab>', '')

         if tlevel > level
            call add(priors, pri)
            call add(menupath, ttl)
            let level = tlevel
         else
            let menupath = menupath[:level]
            let priors = priors[:level]
            let level = tlevel
         endif
         let priors[level] = pri
         let menupath[level] = ttl
         let donemodes = ''
      elseif level >= 0
         let parts = matchlist(line,  '^\s*\(.....\)\(.*\)')
         let mflags = parts[1]
         let menumode = mflags[0]
         if donemodes =~ menumode
            continue
         endif
         let mallmenu = mflags[1]
         if mallmenu == '*'
            let menumode = 'a'
            let donemodes = donemodes + 'nvso'
         endif
         if mflags[2] == 's' | let msilent = '<silent> ' 
         else | let msilent = ''
         endif
         let mcommand = menumode . 'menu ' . msilent
         let mcmd = parts[2]
         let entry = {
                  \ "pri": priors,
                  \ "cmd": mcommand,
                  \ "menu": menupath,
                  \ "rhs": escape(mcmd, '|'),
                  \ "id": menumode . " " . join(menupath, '.')
                  \ }
         if has_key(capMenuIds, entry.id)
            let capMenus[capMenuIds[entry.id]] = entry
         else
            let capMenuIds[entry.id] = len(capMenus)
            call add(capMenus, entry)
         endif
      endif
   endfor

   if len(capMenus) > 0
      let s:MenuCaptures[a:menu] = capMenus
   endif

   return len(capMenus)
endfunc

" Recreate the menu 'oldmenu' as menu 'newmenu'
function! s:CreateCapturedMenu(newmenu, oldmenu)
   if !has_key(s:MenuCaptures, a:oldmenu) | return | endif
   let entries = s:MenuCaptures[a:oldmenu]
   for mx in entries
      let cmd = '80' . mx.cmd . ' ' . a:newmenu . '.' . join(mx.menu[1:], '.') . ' ' . mx.rhs
      " echo cmd
      try
         silent exec cmd
      catch
         if s:debug
            echom "Failed " . cmd
         endif
      endtry
   endfor
endfunc

function! s:CaptureKnownMenus()
   let tried = {}
   for mnk in keys(s:Workarounds)
      let wrkrnds = s:Workarounds[mnk]
      for menumapdef in wrkrnds
         let inout = split(menumapdef, "=>")
         let existing = inout[0]
         if has_key(tried, existing) 
            continue
         endif
         let tried[existing] = 1
         let crv = s:CaptureMenu(existing)
         if crv >= 0
            try 
               exec "aunmenu " . existing
            catch
            endtry
         endif
      endfor
   endfor
endfunc

function! s:StartupStuff()
   call s:CaptureKnownMenus()
endfunc

augroup FtMenu
   au!
   au FileType * call <SID>RecreateFtMenu()
   au BufEnter * call <SID>RecreateFtMenu()
   au VimEnter * call <SID>StartupStuff()
augroup END

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
   call AddFtMenuHook('python', s:SNR . "T_Python")
   call AddFtMenuHook('vim', s:SNR . "T_Vim")
   call AddFtWorkaround('python', ['Python', 'IM-Python=>&Buffer'])
   call AddFtWorkaround('sh', ['Bash'])
   call AddFtWorkaround('perl', ['Perl'])
   call AddFtWorkaround('lua', ['Lua'])
   call AddFtWorkaround('html', ['HTML', 'XHtml'])
   " django-templates : replace <a0> with \<space> in code
   call AddFtWorkaround('htmldjango', ['HTML', 'XHtml', 'Django templates=>&Django'])
   call AddFtWorkaround('xhtml', ['XHtml'])
   call AddFtWorkaround('viki', ['Plugin.Viki'])
endfunc

call s:Test()

