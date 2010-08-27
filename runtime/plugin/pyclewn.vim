" pyclewn run time file
" Maintainer:   <xdegaye at users dot sourceforge dot net>
"
" Configure VIM to be used with pyclewn and netbeans
"

" pyclewn version
let g:pyclewn_version = "pyclewn-1.3"

" enable balloon_eval
if has("balloon_eval")
    set ballooneval
    set balloondelay=100
endif

" The 'Pyclewn' command starts pyclewn and vim netbeans interface.
command -nargs=0 Pyclewn call pyclewn#StartClewn()
