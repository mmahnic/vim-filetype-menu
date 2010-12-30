" vim:set fileencoding=utf-8 sw=3 ts=8 et:vim "
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
let s:MenuPrefix  = "&Mode-"
let s:MenuPriority = "80"

" Instead of using function references in s:MenuHooks we use named hooks. This
" way the user will be able to modify the placement of the menus provided by
" the hook. This dictionary maps names to function references that can be
" call()ed.
let s:HookFunctions = {}

" Menus that were registered with the Mode-menu interface (AddHook). For each
" filetype (key) there is a list of hooknames to be called.
" TODO: add submenu to hooknames so that the hook-function can generate the
"       items in a submenu. eg. "FT_Vim=>&Vim"
" TODO: add references to other filetypes. eg. hookname '!vim=>&Vim' will add all
"       hooks for ft=vim to this list of hooks. All added hooks will be
"       created in Vim submenu
let s:MenuHooks = {}

" Menus that need workarounds, because they don't use the Mode-menu interface
let s:MenuCaptures = {}

" Wokrarounds defined by the user (AddWorkaround(mode, menunames))
let s:Workarounds = {}

function! ftmenu#RegisterHook(name, function)
   " TODO: don't allow to overwrite a registered hook
   let s:HookFunctions[a:name] = a:function
endfunc

" FileType menu hooks will be executed when the ft of the buffer is
" different than the ft of the current mode menu
function! ftmenu#AddHook(filetype, hookname)
   " TODO: additional parameter: submenu name
   if ! has_key(s:MenuHooks, a:filetype)
      let s:MenuHooks[a:filetype] = [ a:hookname ]
   else
      call add(s:MenuHooks[a:filetype], a:hookname)
   endif
endfunc

" The plugins that don't support Mode-menus may create some top-level
" menus. This function is used to bind top-level menus to filetypes.
function! ftmenu#AddWorkaround(filetype, menunames)
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

" Captures a menu and returns a list of entries from which the menu can be
" recreated. The entries in existingEntries will be updated and returned. If
" the menu doesn't exist the function will return -1.
function! ftmenu#CaptureMenu(menu, existingEntries)
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

   let capMenus = a:existingEntries
   let capMenuIds = {}
   let i = 0
   for mx in capMenus
      let capMenuIds[mx.id] = i
      let i = i + 1
   endfor

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
      elseif level >= 0
         let parts = matchlist(line,  '^\s*\(.....\)\(.*\)')
         let mflags = parts[1]
         let menumode = mflags[0]
         let mnoremap = mflags[1]
         if mflags[2] == 's' | let msilent = '<silent> ' 
         else | let msilent = ''
         endif
         if mnoremap == '*'
            let mcommand = menumode . 'noremenu ' . msilent
         else
            let mcommand = menumode . 'menu ' . msilent
         endif
         let mcmd = escape(parts[2], '|') " XXX
         let entry = {
                  \ "pri": priors,
                  \ "cmd": mcommand,
                  \ "menu": menupath,
                  \ "rhs": mcmd,
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

   return capMenus
endfunc

" Create menu items from entries under the menu menuPath.
"
" The first item in the menupath of every entey will be removed. If for
" example the menu 'Tools.Spelling' is captured in entries, then menu[0] of
" each entry is 'Tools.Spelling' which will be removed.
function! ftmenu#CreateMenu(menuPath, entries)
   for mx in a:entries
      let cmd = '80' . mx.cmd . ' ' . a:menuPath . '.' . join(mx.menu[1:], '.') . ' ' . mx.rhs
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

function! s:CaptureMenu(menu)
   if has_key(s:MenuCaptures, a:menu)
      let capMenus = s:MenuCaptures[a:menu]
   else
      let capMenus = []
   endif

   let updatedMenus = ftmenu#CaptureMenu(a:menu, capMenus)

   if type(updatedMenus) == type(1)
      return updatedMenus
   endif

   if len(updatedMenus) > 0
      let s:MenuCaptures[a:menu] = updatedMenus
   endif

   return len(updatedMenus)
endfunc

" Check if the Mode-menu has to be recreated
function! ftmenu#RecreateFtMenu(force)
   if s:debug
      echom "RecreateFtMenu " . &ft
   endif
   if !a:force && s:CurrentMode == &ft | return | endif
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

   let s:CurrentMenu = s:MenuPrefix .s:CurrentMode
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

         if has_key(s:MenuCaptures, existing)
            let entries = s:MenuCaptures[existing]
            call ftmenu#CreateMenu(newmenu, entries)
         endif
      endfor
   endif

   if !has_key(s:MenuHooks, a:filetype) | return | endif

   for hook in s:MenuHooks[a:filetype]
      try
         let hook = s:HookFunctions[hook]
         call call(hook, [s:MenuPriority, a:menu])
      catch
      endtry
   endfor
endfunc

function! ftmenu#MoveMenu(oldMenuPath, newMenuPath)
   let capMenu = ftmenu#CaptureMenu(a:oldMenuPath, [])
   if type(capMenu) == type(1)
      return
   endif
   try 
      exec "aunmenu " . a:oldMenuPath
   catch
   endtry

   call ftmenu#CreateMenu(a:newMenuPath, capMenu)
endfunc

function! ftmenu#CaptureKnownMenus()
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

