" Vimball Archiver by Charles E. Campbell, Jr., Ph.D.
UseVimball
finish
autoload/pyclewn.vim	[[[1
200
" pyclewn run time file
" Maintainer:   <xdegaye at users dot sourceforge dot net>
"
" Configure VIM to be used with pyclewn and netbeans
"
if exists("s:did_pyclewn")
    finish
endif
let s:did_pyclewn = 1

let s:start_err = "Error: pyclewn failed to start.\n\n"

" The following variables define how pyclewn is started when
" the ':Pyclewn' vim command is run.
" They may be changed to match your preferences.

if exists("pyclewn_python")
  let s:pgm = pyclewn_python
else
  let s:pgm = "python"
endif

if exists("pyclewn_args")
  let s:args = pyclewn_args
else
  let s:args = "--window=top --maxlines=10000 --background=Cyan,Green,Magenta"
endif

if exists("pyclewn_connection")
  let s:connection = pyclewn_connection
else
  let s:connection = "localhost:3219:changeme"
endif

" Uncomment the following line to print full traces in a file named 'logfile'
" for debugging purpose.
" let s:args .= " --level=nbdebug --file=logfile"

" The 'Pyclewn' command starts pyclewn and vim netbeans interface.
let s:fixed = "--daemon --editor= --netbeans=" . s:connection . " --cargs="

" Run the 'Cinterrupt' command to open the console
function s:interrupt(args)
    " find the prefix
    let argl = split(a:args)
    let prefix = "C"
    let idx = index(argl, "-x")
    if idx == -1
        let idx = index(argl, "--prefix")
        if idx == -1
            for item in argl
                if stridx(item, "--prefix") == 0
                    let pos = stridx(item, "=")
                    if pos != -1
                        let prefix = strpart(item, pos + 1)
                    endif
                endif
            endfor
        endif
    endif

    if idx != -1 && len(argl) > idx + 1
        let prefix = argl[idx + 1]
    endif

    " hack to prevent Vim being stuck in the command line with '--More--'
    echohl WarningMsg
    echo "About to run the 'interrupt' command."
    call inputsave()
    call input("Press the <Enter> key to continue.")
    call inputrestore()
    echohl None
    exe prefix . "interrupt"
endfunction

" Check wether pyclewn successfully wrote the script file
function s:pyclewn_ready(filename)
    let l:cnt = 1
    let l:max = 20
    echohl WarningMsg
    while l:cnt < l:max
        echon "."
        let l:cnt = l:cnt + 1
        if filereadable(a:filename)
            break
        endif
        sleep 200m
    endwhile
    echohl None
    if l:cnt == l:max
        throw s:start_err
    endif
    call s:info("Creation of vim script file \"" . a:filename . "\": OK.\n")
endfunction

" Start pyclewn and vim netbeans interface.
function s:start(args)
    if !exists(":nbstart")
        throw "Error: the ':nbstart' vim command does not exist."
    endif
    if has("netbeans_enabled")
        throw "Error: netbeans is already enabled and connected."
    endif
    if !executable(s:pgm)
        throw "Error: '" . s:pgm . "' cannot be found or is not an executable."
    endif
    let l:tmpfile = tempname()

    " remove console and dbgvar buffers from previous session
    if bufexists("(clewn)_console")
        bwipeout (clewn)_console
    endif
    if bufexists("(clewn)_dbgvar")
        bwipeout (clewn)_dbgvar
    endif

    " start pyclewn and netbeans
    call s:info("Starting pyclewn.\n")
    exe "silent !" . s:pgm . " -m clewn " . s:fixed . l:tmpfile . " " . a:args . " &"
    call s:info("Running nbstart, <C-C> to interrupt.\n")
    call s:pyclewn_ready(l:tmpfile)
    exe "nbstart :" . s:connection

    " source vim script
    if has("netbeans_enabled")
        if !filereadable(l:tmpfile)
            nbclose
            throw s:start_err
        endif
        " the pyclewn generated vim script is sourced only once
        if ! exists("s:source_once")
            let s:source_once = 1
            exe "source " . l:tmpfile
        endif
        call s:info("The netbeans socket is connected.\n")
        let argl = split(a:args)
        if index(argl, "pdb") == len(argl) - 1
            call s:interrupt(a:args)
        endif
    else
        throw "Error: the netbeans socket could not be connected."
    endif
endfunction

function pyclewn#StartClewn(...)
    " command to start pdb: Pyclewn pdb foo.py arg1 arg2 ....
    let l:args = s:args
    if a:0 != 0
        if a:1 == "pdb"
            if a:0 == 2 && filereadable(a:2) == 0
                call s:error("File '" . a:2 . "' is not readable.")
                return
            endif
            if a:0 > 1
                let l:args .= " --args \"" . join(a:000[1:], ' ') . "\""
            endif
            let l:args .= " pdb"
        else
            call s:error("Invalid optional first argument: must be 'pdb'.")
            return
        endif
    endif

    try
        call s:start(l:args)
    catch /.*/
        call s:info("The 'Pyclewn' command has been aborted.\n")
        let l:err = v:exception
        let l:argl = split(l:args)
        if index(l:argl, "pdb") == len(l:argl) - 1
            let l:err .= "Create a python script containing the line:\n"
            let l:err .= "   import clewn.vim as vim; vim.pdb(level='debug')\n"
            let l:err .= "and run this script to get the cause of the problem."
        else
            let l:err .= "Run '${pgm} -m clewn' to get the cause of the problem."
        endif
        call s:error(l:err)
        " vim console screen is garbled, redraw the screen
        if !has("gui_running")
            redraw!
        endif
        " clear the command line
        echo "\n"
    endtry
endfunction

function s:info(msg)
    echohl WarningMsg
    echo a:msg
    echohl None
endfunction

function s:error(msg)
    echohl ErrorMsg
    echo a:msg
    call inputsave()
    call input("Press the <Enter> key to continue.")
    call inputrestore()
    echohl None
endfunction
doc/pyclewn.txt	[[[1
1469
*pyclewn.txt*                                   Last change: 2015 January 15


                            PYCLEWN USER MANUAL

The Pyclewn user guide                              *pyclewn*

1. Introduction                                     |pyclewn-intro|
2. Starting pyclewn                                 |:Pyclewn|
3. Options                                          |pyclewn-options|
4. Using pyclewn                                    |pyclewn-using|
5. Gdb                                              |pyclewn-gdb|
6. Pdb                                              |pyclewn-pdb|
7. Key mappings                                     |pyclewn-mappings|
8. Watched variables                                |pyclewn-variable|
9. Extending pyclewn                                |pyclewn-extending|


==============================================================================
1. Introduction                                     *pyclewn-intro*


Pyclewn is a python program that allows the use of vim as a front end to a
debugger. Pyclewn supports the gdb and the pdb debuggers. Pyclewn uses the
netbeans protocol to control vim.

The debugger output is redirected to a vim window, the |pyclewn-console| . The
debugger commands are mapped to vim user-defined commands with a common letter
prefix (the default is the |C| letter), and with vim command completion
available on the commands and their first argument.

On unix when running gvim, the controlling terminal of the program to debug is
the terminal used to launch pyclewn. Any other terminal can be used when the
debugger allows it, for example after using the ``attach`` or ``tty`` gdb
commands or using the ``--tty`` option with pdb.


Pyclewn currently supports the following debuggers:

    * gdb:      version 6.2.1 and above, pyclewn uses the gdb MI interface

    * pdb:      the Python debugger

    * simple:   a fake debugger implemented in python to test pyclewn
                internals


Pyclewn provides the following features:
---------------------------------------

* A debugger command can be mapped in vim to a key sequence using vim key
  mappings. This allows, for example, to set/clear a breakpoint or print a
  variable value at the current cursor or mouse position by just hitting a
  key.

* A sequence of gdb commands can be run from a vim script when the
  |async-option| is set. This may be useful in a key mapping.

* Breakpoints and the line in the current frame are highlighted in the source
  code. Disabled breakpoints are noted with a different highlighting color.
  Pyclewn automatically finds the source file for the breakpoint if it exists,
  and tells vim to load and display the file and highlight the line.

* The value of an expression or variable is displayed in a balloon in gvim
  when the mouse pointer is hovering over the selected expression or the
  variable.

* Similarly to gdb, one may attach to a running python process with the pdb
  debugger, interrupt the process, manage a debugging session and terminate
  the debugging session by detaching from the process. A new debugging session
  may be conducted later on this same process, possibly from another Vim
  instance.

* An expression can be watched in a vim window. The expression value is
  updated and highlighted whenever it has changed. When the expression is a
  structure or class instance, it can be expanded (resp. folded) to show
  (resp. hide) its members and their values. This feature is only available
  with gdb.

* The |project-command| saves the current gdb settings to a project file that
  may be sourced later by the gdb "source" command. These settings are the
  working directory, the debuggee program file name, the program arguments and
  the breakpoints. The sourcing and saving of the project file can be
  automated to occur on each gdb startup and termination, whith the
  |project-file| command line option. The ``project`` command is currently only
  available with gdb.

* Vim command completion on the commands and their first argument.


The remaining sections of this manual are:
-----------------------------------------

    2. |:Pyclewn| explains how to start pyclewn.

    3. |pyclewn-options| lists pyclewn options and their usage.

    4. |pyclewn-using| explains how to use the pyclewn features common to all
       supported debuggers

    5. |pyclewn-gdb| details the topics relevant to pyclewn and the gdb
       debugger.

    6. |pyclewn-pdb| details the topics relevant to pyclewn and the pdb
       debugger.

    7. |pyclewn-mappings| lists the pyclewn key mappings and how to use them.

    8. |pyclewn-variable| explains how to use the variable debugger window with
    gdb.

    9. |pyclewn-extending| explains how to implement a new debugger in pyclewn

==============================================================================
2. Starting pyclewn                                 *:Pyclewn*


Start pyclewn from vim:
-----------------------
The |:Pyclewn| vim command requires at least vim 7.3. To start pyclewn with the
gdb debugger: >

    :Pyclewn

To start pyclewn with the pdb debugger: >

    :Pyclewn pdb [script.py]

Next, the gdb debugger is started by running a debugger command from vim
command line. For example, load foobar with the gdb command "file" and start
gbd by typing on the vim command line: >

    :Cfile foobar

To just start gdb with a command that does not have any effect: >

    :Cecho

To terminate pyclewn and the vim netbeans interface, run the following
command: >

    :nbclose

To know if the netbeans interface is connected, run the following command: >

    :echo has("netbeans_enabled")

The |:Pyclewn| command does the following:

    * spawn pyclewn
    * start the vim netbeans interface and connect it to pyclewn
    * source a script automatically generated by pyclewn containing utility
      functions and the debugger commands as vim commands


Global variables         *pyclewn_python* *pyclewn_args* *pyclewn_connection*
----------------

When starting pyclewn with |:Pyclewn|, the pyclewn command line arguments and
connection details may be set with the |pyclewn_python|, |pyclewn_args| and
|pyclewn_connection| global variables.

When those global variables are not set, pyclewn is spawned with the
following values:

    * pyclewn_python: "python"
    * pyclewn_connection: "localhost:3219:changeme"
    * pyclewn_args:
        "--window=top --maxlines=10000 --background=Cyan,Green,Magenta"


Start pyclewn from a shell:
---------------------------

Start pyclewn with: >

    python -m clewn [options] [debugger]

"debugger" defaults to "gdb".

So pyclewn with the gdb debugger is simply started as: >

    python -m clewn

==============================================================================
3. Options                                          *pyclewn-options*


The pyclewn options can be set:

    * on the command line

    * with the |pyclewn_python|, |pyclewn_args| and |pyclewn_connection| vim
      global variables when starting pyclewn with the |:Pyclewn| command

    * as the keyword parameters of the pdb function


Options:
  --version                   show program's version number and exit
  -h, --help                  show this help message and exit
  -g PARAM_LIST, --gdb=PARAM_LIST
                              set gdb PARAM_LIST
  -d, --daemon                run as a daemon (default 'False')
  -e EDITOR, --editor=EDITOR  set Vim program to EDITOR
  -c ARGS, --cargs=ARGS       set Vim arguments to ARGS
  -p PGM, --pgm=PGM           set the debugger pathname to PGM
  -a ARGS, --args=ARGS        set the debugger arguments to ARGS
  --terminal=TERMINAL         set the terminal to use with the inferiortty
                              command (default 'xterm,-e')
  --run                       allow the debuggee to run after the pdb() call
                              (default 'False')
  --tty=TTY                   use TTY for input/output by the python script
                              being debugged (default '/dev/null')
  -w LOCATION, --window=LOCATION
                              open the debugger console window at LOCATION
                              which may be one of (top, bottom, left,
                              right, none), the default is top
  -m LNUM, --maxlines=LNUM    set the maximum number of lines of the debugger
                              console window to LNUM (default 10000 lines)
  -x PREFIX, --prefix=PREFIX  set the commands prefix to PREFIX (default 'C')
  -b COLORS, --background=COLORS
                              COLORS is a comma separated list of the three
                              colors of the breakpoint enabled, breakpoint
                              disabled and frame sign background colors, in
                              this order (default 'Cyan,Green,Magenta')
  -n CONN, --netbeans=CONN    set netBeans connection parameters to CONN with
                              CONN as 'host[:port[:passwd]]', (the default is
                              ':3219:changeme' where the empty host represents
                              INADDR_ANY)
  -l LEVEL, --level=LEVEL     set the log level to LEVEL: critical, error,
                              warning, info, debug, nbdebug (default error)
  -f FILE, --file=FILE        set the log file name to FILE


The full description of pyclewn options follows:
------------------------------------------------

--version           Show program's version number and exit.

-h
--help              Show this help message and exit.

-g {PARAM_LIST}
--gdb={PARAM_LIST}  The PARAM_LIST option parameter is a comma separated list
                    of parameters and is mandatory when the option is present.
                    So, to run gdb with no specific parameter, the following
                    commands are equivalent: >

                        python -m clewn
                        python -m clewn -g ""
                        python -m clewn --gdb=
.
                    There are three optional parameters:

                        * the "async" keyword sets the |async-option|
                        * the "nodereference" keyword, see |gdb-balloon|.
                        * the project file name sets the |project-file|

                    The project file name can be an absolute pathname, a
                    relative pathname starting with '.' or a home relative
                    pathname starting with '~'. The directory of the project
                    file name must be an existing directory.
                    For example on unix: >

                        python -m clewn --gdb=async,./project_name

-d
--daemon            Run as a daemon (default 'False'): on unix, pyclewn is
                    detached from the terminal from where it has been
                    launched, which means that this terminal cannot be used as
                    a controlling terminal for the program to debug, and
                    cannot be used for printing the pyclewn logs as well.

-e {EDITOR}
--editor={EDITOR}   Set Vim program to EDITOR. EDITOR must be in one
                    of the directories listed in the PATH environment
                    variable, or the absolute pathname of the vim executable.
                    When this command line option is not set, pyclewn uses the
                    value of the EDITOR environment variable, and if this
                    environment variable is not set either, then pyclewn
                    defaults to using "gvim" as the name of the program to
                    spawn. Vim is not spawned by pyclewn when this option is
                    set to an empty string or when the debugger is pdb.

-c {ARGS}
--cargs={ARGS}      Set the editor program arguments to ARGS, possibly double
                    quoted (same as option --args).

-p {PGM}
--pgm={PGM}         Set the debugger program to PGM. PGM must be in one of the
                    directories listed in the PATH environment variable.

-a {ARGS}
--args={ARGS}       Set the debugger program arguments to ARGS. These
                    arguments may be double quoted. For example, start gdb
                    with the program foobar and "this is foobar argument" as
                    foobar's argument: >

                    python -m clewn -a '--args foobar "this is foobar argument"'

--terminal=TERMINAL Set the terminal to use with the inferiortty command for
                    running gdb or pdb inferior (default 'xterm,-e'). The
                    option is a comma separated list of the arguments needed
                    to start the terminal and a program running in this
                    terminal.

--run               By default the python debuggee is stopped at the first
                    statement after the call to pdb(). Enabling this option
                    allows the debuggee to run after the call to pdb().

--tty={TTY}         Use TTY for input/output by the python script being
                    debugged. The default is "/dev/null".

-w {LOCATION}
--window={LOCATION} The debugger console window pops up at LOCATION, which may
                    be one of top, bottom, left, right or none. The default is
                    top.  In the left or right case, the window pops up on the
                    left (resp. right) if there is only one window currently
                    displayed, otherwise the debugger window is opened at the
                    default top. When LOCATION is none, the automatic display
                    of the console is disabled.

-m {LNUM}
--maxlines={LNUM}   Set the maximum number of lines of the debugger console
                    window to LNUM (default 10000 lines). When the number of
                    lines in the buffer reaches LNUM, 10% of LNUM first lines
                    are deleted from the buffer.

-x {PREFIX}
--prefix={PREFIX}   Set the user defined vim commands prefix to PREFIX
                    (default |C|). The prefix may be more than one letter
                    long. The first letter must be upper case.

-b {COLORS}
--background={COLORS}
                    COLORS is a comma separated list of the three colors of
                    the breakpoint enabled, breakpoint disabled and frame sign
                    background colors, in this order (default
                    'Cyan,Green,Magenta'). The color names are case sensitive.
                    See |highlight-ctermbg| for the list of the valid color
                    names.

                    This option has no effect when vim version is vim72 or
                    older.

-n {CONN}
--netbeans={CONN}   Set netBeans connection parameters to CONN with CONN as
                    'host[:port[:passwd]]', (the default is ':3219:changeme'
                    where the empty host represents INADDR_ANY). Pyclewn
                    listens on host:port, with host being a name or the IP
                    address of one of the local network interfaces in standard
                    dot notation. These parameters must match those used by
                    vim for the connection to succeed.

-l {LEVEL}
--level={LEVEL}     Set the log level to LEVEL: critical, error, warning, info,
                    debug or nbdebug (default critical). Level nbdebug is very
                    verbose and logs all the netbeans pdu as well as all the
                    debug traces. Critical error messages are printed on
                    stderr. No logging is done on stderr (including critical
                    error messages) when the "--level" option is set to
                    something else than "critical" and the "--file" option is
                    set.

-f {FILE}
--file={FILE}       Set the log file name to FILE.

==============================================================================
4. Using pyclewn                            *pyclewn-using* *pyclewn-console*


Console:
--------
The debugger output is redirected to a vim window: the console.

The console window pops up whenever a |Ccommand| is entered on vim command line
or a key mapped by pyclewn is hit. This behavior may be disabled by setting to
`none` the `window` |pyclewn-options| and may be useful when using Vim tabs and
wanting to keep the console in a tab of its own. In this case, the cursor
position in the console is not updated by pyclewn, so you need to set manually
the cursor at the bottom of the console, the first time you open
(clewn)_console.

The initial console window height is set with the vim option 'previewheight'
that defaults to 12 lines.


Commands:                                           *Ccommand* *C*
---------
The prefix letter |C| is the default vim command prefix used to map debugger
commands to vim user-defined commands. These commands are called |Ccommand| in
this manual. The prefix can be changed with a command line option.

A debugger command can be entered on vim command line with the |C| prefix. It is
also possible to enter the command as the first argument of the |C| command. In
the following example with gdb, both methods are equivalent: >

    :Cfile /path/to/foobar
    :C file /path/to/foobar

The first method provides completion on the file name while the second one
does not.

The second method is useful when the command is a user defined command in the
debugger (user defined commands built by <define> in gdb), and therefore not a
vim command. It is also needed for gdb command names that cannot be mapped to
a vim command because vim does not accept non alphanumeric characters within
command names (for example <core-file> in gdb).

To get help on the pyclewn commands, use Chelp.

Pyclewn commands can be mapped to keys, or called within a Vim script or a
menu.

Note:
The gdb debugger cannot handle requests asynchronously, so the
|async-option| must be set, when mapping a key to a sequence of commands.
With this option set, one can build for example the following mapping: >

    :map <F8> :Cfile /path/to/foobar <Bar> Cbreak main <Bar> Crun <CR>

Note:
Quotes and backslashes must be escaped on vim command line. For example, to
print foo with a string literal as first argument to the foo function: >

    :Cprint foo(\"foobar\", 1)

And to do the same thing with the string including a new line: >

    :Cprint foo(\"foobar\\n\", 1)


Completion:
-----------
Command line completion in vim is usually done using the <Tab> key (set by the
'wildchar' option). To get the list of all valid completion matches, type
CTRL-D. For example, to list all the debugger commands (assuming the
default |C| prefix is being used): >

    :C<C-D>

See also the 'wildmenu' option. With this option, the possible matches are
shown just above the command line and can be selected with the arrow keys.

The first argument completion of a |Ccommand| may be done on a file name or on a
list. For example with gdb, the following command lists all the gdb help
items: >

    :Chelp <C-D>

The first argument completion of the |C| command is the list of all the debugger
commands. For example, to list all the debugger commands (note the space after
the |C|): >

    :C <C-D>


Command line search:
--------------------
Use the powerful command line search capabilities of the Vim command line.
For example, you want to type again, possibly after a little editing, one of
the commands previously entered: >

    :Cprint (*(foo*)0x0123ABCD)->next->next->part1->something_else.aaa

You can get rapidly to this command by using the Vim command line window
|cmdline-window|: >

    :<CTRL-F>
    /something_else
    <CR>

or from normal mode >
    q:
    /something_else
    <CR>


Vim in a terminal
-----------------
The debuggee output is redirected to '/dev/null' when the name of the program
is "vim" or "vi". One must use the "set inferior-tty" gdb command to redirect
the debuggee output to a terminal.

Do not use the "--daemon" command line option when running vim in a console.


Balloon:
--------
A variable is evaluated by the debugger and displayed in a balloon in gvim,
when the mouse pointer is hovering over the the variable. To get the
evaluation of an expression, first select the expression in visual mode in the
source code and point the mouse over the selected expression. To disable this
feature, set the vim option 'noballooneval'.

==============================================================================
5. Gdb                                              *pyclewn-gdb*


When gdb is started, it automatically executes commands from its init file,
normally called '.gdbinit'. See the gdb documentation.


                                                    *inferior_tty*

Debuggee standard input and output:
-----------------------------------
On unix, when starting pyclewn from a terminal and using gvim, pyclewn creates
a pseudo terminal that is the the controlling terminal of the program to
debug. Programs debugged by gdb, including those based on curses and termios
such as vim, run in this terminal. A <Ctl-C> typed in the terminal interrupts
the debuggee.

When pyclewn is started from vim with the |:Pyclewn| command, there is no
terminal associated with pyclewn. The |inferiortty| command provides the same
functionality as above and spawns the controlling terminal (using the
--terminal option, default xterm) of the debuggee and sets accordingly gdb
'inferior-tty' variable and the TERM environment variable. The gdb
'inferior-tty' variable MUST be set BEFORE the inferior is started.

One can also do step by step what the above command does automatically: start
the "inferior_tty.py" script installed with pyclewn. This script creates a
pseudo terminal to be used as the controlling terminal of the process debugged
by gdb. For example, to debug vim (not gvim) and start the debugging session
at vim's main function.  From pyclewn, spawn an xterm terminal and launch
"inferior_tty.py" in this terminal: >

    :Cfile /path/to/vim
    :Cshell setsid xterm -e inferior_tty.py &

"inferior_tty.py" prints the name of the pseudo terminal to be used by gdb and
the two gdb commands needed to configure properly gdb with this terminal. Copy
and paste these two commands in vim command line: >

    :Cset inferior-tty /dev/pts/nn
    :Cset environment TERM = xterm

Then start the debugging session of vim and stop at vim main(): >

    :Cstart

Note:
* <setsid> is necessary to prevent gdb from killing the xterm process when a
  <Ctl-C> is typed from gdb to interrupt the debuggee. This is not needed when
  the terminal emulator is not started from gdb.


                                                    *async-option*
Async option:
-------------
The gdb event loop is not asynchronous in most configurations, which means
that gdb cannot handle a command while the previous one is being processed and
discards it.
When gdb is run with the |async-option| set, pyclewn queues the commands in a
fifo and send a command to gdb, only when gdb is ready to process the command.
This allows the key mappings of a sequence of gdb commands. To set the
|async-option| , see |pyclewn-options|.


                                                    *gdb-keys*
List of the gdb default key mappings:
-------------------------------------
These keys are mapped after the |Cmapkeys| vim command is run.

        CTRL-Z  send an interrupt to gdb and the program it is running (unix
                only)
        B       info breakpoints
        L       info locals
        A       info args
        S       step
        CTRL-N  next: next source line, skipping all function calls
        F       finish
        R       run
        Q       quit
        C       continue
        W       where
        X       foldvar
        CTRL-U  up: go up one frame
        CTRL-D  down: go down one frame

cursor position: ~
        CTRL-B  set a breakpoint on the line where the cursor is located
        CTRL-E  clear all breakpoints on the line where the cursor is located

mouse pointer position: ~
        CTRL-P  print the value of the variable defined by the mouse pointer
                position
        CTRL-X  print the value that is referenced by the address whose
                value is that of the variable defined by the mouse pointer
                position


                                                    *$cdir*
Source path:
-----------
Pyclewn automatically locates the source file with the help of gdb, by using
the debugging information stored in the file that is being debugged. This is
useful when the program to debug is the result of multiple compilation units
located in different directories.


                                                    *Csymcompletion*
Symbols completion:
-------------------
The gdb <break> and <clear> commands are set initially with file name
completion. This can be changed to completion matching the symbols of the
program being debugged, after running the |Csymcompletion| command. This is a
pyclewn command.

To minimize the number of loaded symbols and to avoid fetching the shared
libraries symbols, run the Csymcompletion command after the file is loaded
with the gdb <file> command, and before the program is run.

Note: The <break> and <clear> filename completion is not the same as gdb file
name completion for these two commands. Gdb uses the symbols found in the
program file to debug, while pyclewn uses only the file system.


                                                    *gdb-balloon*
Balloon evaluation:
-------------------
The gdb <whatis> command is used by pyclewn to get the type of the variable or
the type of the selected expression that is being hovered over by the mouse.
When it is a pointer to data, the pointer is dereferenced and its value
displayed in the vim balloon. The paramater of the "--gdb" option named
"nodereference" disables this feature: the balloon prints the pointer address
value.


                                            *project-command* *project-file*
Project file:
-------------
The pyclewn |project-command| name is "project". This command saves the current
gdb settings to a project file that may be sourced later by the gdb "source"
command.

These settings are:
    * current working directory
    * debuggee program file name
    * program arguments
    * all the breakpoints (at most one breakpoint per source line is saved)

The argument of the |project-command| is the pathname of the project file.
For example: >

    :Cproject /path/to/project

When the "--gdb" option is set with a project filename (see |pyclewn-options|),
the project file is automatically sourced when a a gdb session is started, and
the project file is automatically saved when the gdb session or vim session,
is terminated.

Note: When gdb sources the project file and cannot set a breakpoint because,
for example, it was set in a shared library that was loaded at the time the
project file was saved, gdb ignores silently the breakpoint (see gdb help on
"set breakpoint pending").


Limitations:
------------
When setting breakpoints on an overloaded method, pyclewn bypasses the gdb
prompt for the multiple choice and sets automatically all breakpoints.

In order to set a pending breakpoint (for example in a shared library that has
not yet been loaded by gdb), you must explicitly set the breakpoint pending
mode to "on", with the command: >

    :Cset breakpoint pending on

After a "detach" gdb command, the frame sign remains highlighted because
gdb/mi considers the frame as still valid.

When answering "Abort" to a dialog after pyclewn attempts to edit a buffer and
set a breakpoint in a file already opened within another Vim session, the
breakpoint is set in gdb, but not highlighted in the corresponding buffer.
However, it is possible to |bwipeout| a buffer at any time, and load it again in
order to restore the correct highlighting of all the breakpoints in the
buffer.


Pyclewn commands:
-----------------
The |Ccommand| list includes all the gdb commands and some pyclewn specific
commands that are listed here:

    * |Ccwindow|       opens a vim quickfix window holding the list of the
                      breakpoints with their current state; the quickfix
                      window allows moving directly to any breakpoint
                      (requires the vim |+quickfix| feature)

    * |Cdbgvar|       add a watched variable or expression to the
                    (clewn)_dbgvar buffer

    * |Cdelvar|       delete a watched variable from the (clewn)_dbgvar buffer

    * Cdumprepr      print on the console pyclewn internal structures that
                     may be used for debugging pyclewn

    * |Cfoldvar|      collapse/expand the members of a watched structure or
                     class instance

    * Chelp          print on the console, help on the pyclewn specific
                     commands (those on this list) in addition to the help on
                     the debugger commands
                                                    *inferiortty*
    * Cinferiortty  spawn the controlling terminal (default xterm) of the
                    debuggee and sets accordingly gdb 'inferior-tty' variable
                    and the TERM environment variable; this command  MUST be
                    issued BEFORE starting the inferior.

    * Cloglevel      print or set the log level dynamically from inside Vim

    * |Cmapkeys|      map pyclewn keys

    * |Cproject|      save the current gdb settings to a project file

    * |Csetfmtvar|    set the output format of the value of a watched variable

    * Csigint        send a <C-C> character to the debugger to interrupt the
                     running program that is being debugged; only with gdb,
                     and when pyclewn and gdb communicate over a pseudo
                     terminal

    * |Csymcompletion| populate the break and clear commands with symbols
                     completion (only with gdb)

    * Cunmapkeys     unmap the pyclewn keys, this vim command does not invoke
                     pyclewn


List of illegal gdb commands:
-----------------------------
The following gdb commands cannot be run from pyclewn:

        complete
        edit
        end
        set annotate
        set confirm
        set height
        set width
        shell

==============================================================================
6. Pdb                                              *pyclewn-pdb*


Start a python script from Vim and debug it, or attach to a running python
process and start the debugging session.


Start a python script from Vim and debug it:
-------------------------------------------
To debug a python script named "script.py", run the vim command (arg1, arg2,
... being the script.py command line arguments): >

    :Pyclewn pdb script.py arg1 arg2 ...

Or, more conveniently, debug the python script being edited in vim as the
current buffer with: >

    :Pyclewn pdb %:p

On unix, the script is started without a controlling terminal unless the "tty"
option has been set (see below). The |Cinferiortty| command spawns a controlling
terminal (using the --terminal option that defaults to xterm) connected to a
pseudo tty, and redirects all three standard streams of the script to this
pseudo tty.

One may also redirect the script output to another tty, using the "tty" option
and setting the |pyclewn_args| vim global variable before starting the script.
For example: >

    :let g:pyclewn_args="--tty=/dev/pts/4"

The ":Cquit" command and the Vim ":quitall" command terminate the debugging
session and the script being debugged. Both commands MUST be issued at the pdb
prompt.


Attach to a python process and debug it: >
----------------------------------------
To debug a python process after having attached to it, first insert the
following statement in the debuggee source code before starting it: >

    import clewn.vim as vim; vim.pdb()

By default, the debuggee is stopped at the first statement following the call
to vim.pdb(). To let the debuggee run instead, then use the "run" option: >

    import clewn.vim as vim; vim.pdb(run=True)

Next, attach to the process and start the debugging session by running the vim
command: >

    :Pyclewn pdb

Notes:
The current debugging session may be terminated with the ":Cdetach" or the Vim
":quitall" command. Another debugging session with the same process can be
started later with the ":Pyclewn pdb" command.

The ":Cdetach", ":Cquit" or the Vim ":quitall" commands do not terminate the
debuggee. To kill the debuggee, issue the following command at the pdb prompt:
>
    :C import sys; sys.exit(1)

On posix platforms, when the python process is not attached, typing two
<Ctl-C> instead of one, is needed to kill the process. This is actually a
feature that allows the process to run without any tracing overhead (before
the first <Ctl-C>) when it is not attached and no breakpoints are being set
(there is still the small overhead of the context switches between the idle
clewn thread and the process threads).


Pdb commands:
-------------
The commands "interrupt", "detach" and "threadstack" are new pdb commands and
are the only commands that are available at the "[running...]" prompt when the
debuggee is running. Use the "help" command (and completion on the first
argument of the help command) to get help on each command.

The following list describes the pdb commands that are new or behave
differently from the pdb commands of the Python standard library:

                                                    *Cinterrupt*
interrupt
    This command interrupts the debuggee and is available from the
    "[running...]" prompt.

                                                    *Cinferiortty*
inferiortty
    Without argument, the pdb command "inferiortty" spawns a terminal
    connected to a pseudo tty and redirects all three standard streams to this
    pseudo tty.
    With the name of an existing pseudo tty as an argument, "inferiortty'
    redirects all three standard streams to this pseudo tty (convenient for
    re-using the same pseudo tty across multiple debugging sessions).
    This command can be issued after the script has been started.
    Available on unix.

                                                    *Cdetach*
detach
    This command terminates the debugging session by closing the netbeans
    socket. The debuggee is free to run and does not stop at the breakpoints.
    To start another debugging session, run the command: >

        :Pyclewn pdb

.   The breakpoints becomes effective again when the new session starts up.
    Available from the "[running...]" prompt and from the pdb prompt.

                                                    *Cquit*
quit
    This command terminates the debugging session by closing the netbeans
    socket, and removes the python trace function. The pyclewn thread in
    charge of handling netbeans connection terminates and it is not possible
    anymore to attach to the process. Since there is no trace function, the
    breakpoints are ineffective and the process performance is not impaired
    anymore by the debugging overhead.

    When the script has been started from Vim, this command terminates the
    script.

                                                    *Cthreadstack*
threadstack
    The command uses the sys._current_frames() function from the standard
    library to print a stack of the frames for all the threads.
    The function sys._current_frames() is available since python 2.5.
    Available from the "[running...]" prompt and from the pdb prompt.

                                                    *Cclear*
clear
    This command is the same as the Python standard library "clear" command,
    except it requires at least one parameter and therefore, it is not
    possible to clear all the breakpoints in one shot with the "clear" command
    without parameters.

the prefix alone:
    There is no "!" pdb command as in the Python standard library since Vim
    does not allow this character in a command name. However, the equivalent
    way to execute a python statement in the context of the current frame is
    with the command prefix alone, for example: >

        :C global list_options; list_options = ['-l']
        :C import sys; sys.exit(1)

.   The first word of the statement must not be a pdb command and will be
    expanded if it is an alias.

not implemented:
    The following pdb commands are not implemented: list, ll, whatis, source,
    display, undisplay, interact, run, restart.


                                                    *pdb-pdbrc*
The initialisation file .pdbrc:
-------------------------------
This file is read at initialisation and its commands are executed on startup.
See the pdb python documentation for the location of this file. Breakpoints
can be set through this file, or aliases may be defined. One useful alias
entered in the file would be for example: >

    alias kill import sys; sys.exit(1)

So that the debuggee may be killed with the command: >

    :C kill


                                                    *pdb-keys*
List of the pdb default key mappings:
-------------------------------------
These keys are mapped after the |Cmapkeys| vim command is run.

        CTRL-Z  interrupt the pdb process
        B       list all breaks, including for each breakpoint, the number of
                times that breakpoint has been hit, the current ignore count,
                and the associated condition if any
        A       print the argument list of the current function
        S       step
        CTRL-N  next: next source line, skipping all function calls
        R       continue execution until the current function returns
        C       continue
        W       where
        CTRL-U  up: go up one frame
        CTRL-D  down: go down one frame

cursor position: ~
        CTRL-B  set a breakpoint on the line where the cursor is located
        CTRL-E  clear all breakpoints on the line where the cursor is located

mouse pointer position: ~
        CTRL-P  print the value of the selected expression defined by the
                mouse pointer position


Pyclewn commands:
-----------------
The |Ccommand| list includes pdb commands and some pyclewn specific commands
that are listed here:

    * Cdumprepr      print on the console pyclewn internal structures that
                     may be used for debugging pyclewn

    * Cloglevel      print or set the log level dynamically from inside Vim

    * |Cmapkeys|      map pyclewn keys

    * Cunmapkeys     unmap the pyclewn keys, this vim command does not invoke
                     pyclewn


Troubleshooting:
----------------
* Pyclewn error messages can be logged in a file with the "--file" option.
  When starting the debuggee from vim, use the |pyclewn_args| vim global
  variable before starting the script: >

    :let g:pyclewn_args="--file=/path/to/logfile"

When attaching to a python process, use the corresponding keyword argument: >

    import clewn.vim as vim; vim.pdb(file='/path/to/logfile')


* To conduct two debugging sessions simultaneously (for example when debugging
  pyclewn with pyclewn), change the netbeans socket port with the
  |pyclewn_connection| vim global variable before starting the script: >

    :let g:pyclewn_connection="localhost:3220:foo"

And change the corresponding keyword argument: >

    import clewn.vim as vim; vim.pdb(netbeans='localhost:3220:foo')


Limitations:
------------
The |Cinterrupt| command does not properly interrupt the input() Python
function. Workaround: after the Cinterrupt command has been issued while at
the prompt displayed by input(), enter some data to allow the input() function
to complete execution of its C code implementation, this allows pdb to gain
control when back in python code and to stop.

==============================================================================
7. Key mappings                                     *pyclewn-mappings*


All |Ccommand| can be mapped to vim keys using the vim |:map-commands|.
For example, to set a breakpoint at the current cursor position: >

    :map <F8> :exe "Cbreak " . expand("%:p") . ":" . line(".")<CR>

Or to print the value of the variable under the cursor: >

    :map <F8> :exe "Cprint " . expand("<cword>") <CR>


                                                    *Cmapkeys*
Pyclewn key mappings:
---------------------
This section describes another mapping mechanism where pyclewn maps vim keys
by reading a configuration file. This is done when the |Cmapkeys| vim command is
run. The pyclewn keys mapping is mostly useful for the pyclewn casual user.
When the configuration file cannot be found, pyclewn sets the default key
mappings. See |gdb-keys| for the list of default key mappings for gdb
and |pdb-keys| for the list of default key mappings for pdb.

Please note that pyclewn relies on the vim |balloon-eval| feature to get the
text under the mouse position when expanding the ${text} macro. This feature
is not available with vim console. So in this case you must build your own
key mapping as in the above example.

The configuration file is named .pyclewn_keys.{debugger}, where debugger is
the name of the debugger. The default placement for this file is
$CLEWNDIR/.pyclewn_keys.{debugger}, or $HOME/.pyclewn_keys.{debugger}.

To customize pyclewn key mappings copy the configurations files found in the
distribution to the proper directory: >

    cp runtime/.pyclewn_keys.gdb        $CLEWNDIR

or >

    cp runtime/.pyclewn_keys.gdb        $HOME

The comments in the configuration file explain how to customize the key
mappings.

Copy these files to the $CLEWNDIR or $HOME directory, and customize the key
mappings.

==============================================================================
8. Watched variables                                *pyclewn-variable*


The Watched Variables feature is available with the gdb debugger. The vim
watched variables buffer is named "(clewn)_dbgvar".

                                                    *Cdbgvar*
The |Cdbgvar| command is used to create a gdb watched variable in the variables
buffer from any valid expression. A valid expression is an expression that is
valid in the current frame.
The argument of the |Cdbgvar| pyclewn command is the expression to be watched.
For example, to create a watched variable for the expression "len - max":
>
    :Cdbgvar len - max

Upon creation, the watched variable is given a name by gdb, for example:
<var1>.
The watched variables buffer, "(clewn)_dbgvar", is created upon creation of
the first watched variable. It is created but not displayed in a window.
To display "(clewn)_dbgvar" just after the creation of the first variable: >
    :e #
or >
    CTL-^

Use the following command to find the number N of the "(clewn)_dbgvar"
buffer: >
    :ls

Knowing N, the following commands display the "(clewn)_dbgvar" buffer: >
    :Nb
or >
    N CTL-^

To split the current window and display "(clewn)_dbgvar": >
    :Nsb
.

                                                    *Cfoldvar*
When the watched variable is a structure or class instance, it can be expanded
with the |Cfoldvar| pyclewn command to display all its members and their values
as children watched variables.
The argument of the |Cfoldvar| command is the line number of the watched
variable to expand, in the watched variable window.
For example: >

    :Cfoldvar 1

The |Cfoldvar| command is meant to be used in a key mapping. This is the 'X' key
when using pyclewn key mappings, or one can use the following mapping:
>
    :map <F8> :exe "Cfoldvar " . line(".")<CR>

The watched variable can also be collapsed with the |Cfoldvar| command.


                                                    *Cdelvar*
A gdb watched variable can be deleted with the |Cdelvar| pyclewn command.
The argument of the |Cdelvar| command is the name of the variable as given by
gdb upon creation.
For example: >

    :Cdelvar var1

When the watched variable is a structure or class instance and it has been
expanded, all its children are also deleted.


                                                    *Csetfmtvar*
Set the output format of the value of the watched variable <name>
to be <format>: >

    :Csetfmtvar <name> <format>

Parameter <name> is the gdb/mi name of the watched variable or one of its
children.
Parameter <format> is one of the strings in the following list:

    {binary | decimal | hexadecimal | octal | natural}

The "natural" format is the default format chosen automatically based on the
variable type (like "decimal" for an int, "hexadecimal" for pointers, etc.).
For a variable with children, the format is set only on the variable itself,
and the children are not affected.

Note: The setting of the format of a child watched variable is lost after
folding one of its parents (because the child is actually not watched anymore
by gdb after the folding).


Highlighting:
-------------
When the value of a watched variable has changed, it is highlighted with the
"Special" highlight group.

When a watched variable becomes out of scope, it is highlighted with the
"Comment" highlight group.

The foreground and background colors used by these highlight groups are setup
by the |:colorscheme| currently in use.

==============================================================================
9. Extending pyclewn                                *pyclewn-extending*


NAME
    debugger

FILE
    clewn/debugger.py

DESCRIPTION
    This module provides the basic infrastructure for using Vim as a
    front-end to a debugger.

    The basic idea behind this infrastructure is to subclass the 'Debugger'
    abstract class, list all the debugger commands and implement the
    processing of these commands in 'cmd_<command_name>' methods in the
    subclass. When the method is not implemented, the processing of the
    command is dispatched to the 'default_cmd_processing' method. These
    methods may call the 'Debugger' API methods to control Vim. For example,
    'add_bp' may be called to set a breakpoint in a buffer in Vim, or
    'console_print' may be called to write the output of a command in the
    Vim debugger console.

    The 'Debugger' subclass is made available to the user after adding an
    option to the 'parse_options' method in the 'Vim' class, see vim.py.

    The 'Simple' class in simple.py provides a simple example of a fake
    debugger front-end.

CLASSES
    __builtin__.object
        Debugger

    class Debugger(__builtin__.object)
     |  Abstract base class for pyclewn debuggers.
     |
     |  The debugger commands received through netbeans 'keyAtPos' events
     |  are dispatched to methods whose name starts with the 'cmd_' prefix.
     |
     |  The signature of the cmd_<command_name> methods are:
     |
     |      cmd_<command_name>(self, str cmd, str args)
     |          cmd: the command name
     |          args: the arguments of the command
     |
     |  The '__init__' method of the subclass must call the '__init__'
     |  method of 'Debugger' as its first statement and forward the method
     |  parameters as an opaque list. The __init__ method must update the
     |  'cmds' and 'mapkeys' dict attributes with its own commands and key
     |  mappings.
     |
     |  Instance attributes:
     |      cmds: dict
     |          The debugger command names are the keys. The values are the
     |          sequence of available completions on the command first
     |          argument. The sequence is possibly empty, meaning no
     |          completion. When the value is not a sequence (for example
     |          None), this indicates file name completion.
     |      mapkeys: dict
     |          Key names are the dictionary keys. See the 'keyCommand'
     |          event in Vim netbeans documentation for the definition of a
     |          key name. The values are a tuple made of two strings
     |          (command, comment):
     |              'command' is the debugger command mapped to this key
     |              'comment' is an optional comment
     |          One can use template substitution on 'command', see the file
     |          runtime/.pyclewn_keys.template for a description of this
     |          feature.
     |      options: optparse.Values
     |          The pyclewn command line parameters.
     |      vim_socket_map: dict
     |          The asyncore socket dictionary
     |      testrun: boolean
     |          True when run from a test suite
     |      started: boolean
     |          True when the debugger is started.
     |      closed: boolean
     |          True when the debugger is closed.
     |      pyclewn_cmds: dict
     |          The subset of 'cmds' that are pyclewn specific commands.
     |      __nbsock: netbeans.Netbeans
     |          The netbeans asynchat socket.
     |      _jobs: list
     |          list of pending jobs to run on a timer event in the
     |          dispatch loop
     |      _jobs_enabled: bool
     |          process enqueued jobs when True
     |      _last_balloon: str
     |          The last balloonText event received.
     |      prompt: str
     |          The prompt printed on the console.
     |      _consbuffered: boolean
     |          True when output to the vim debugger console is buffered
     |
     |  Methods defined here:
     |
     |  __init__(self, options, vim_socket_map, testrun)
     |      Initialize instance variables and the prompt.
     |
     |  __str__(self)
     |      Return the string representation.
     |
     |  add_bp(self, bp_id, pathname, lnum)
     |      Add a breakpoint to a Vim buffer at lnum.
     |
     |      Load the buffer in Vim and set an highlighted sign at 'lnum'.
     |
     |      Method parameters:
     |          bp_id: object
     |              The debugger breakpoint id.
     |          pathname: str
     |              The absolute pathname to the Vim buffer.
     |          lnum: int
     |              The line number in the Vim buffer.
     |
     |  balloon_text(self, text)
     |      Process a netbeans balloonText event.
     |
     |      Used when 'ballooneval' is set and the mouse pointer rests on
     |      some text for a moment.
     |
     |      Method parameter:
     |          text: str
     |              The text under the mouse pointer.
     |
     |  close(self)
     |      Close the debugger and remove all signs in Vim.
     |
     |  cmd_dumprepr(self, cmd, args)
     |      Print debugging information on netbeans and the debugger.
     |
     |  cmd_help(self, *args)
     |      Print help on all pyclewn commands in the Vim debugger
     |      console.
     |
     |  cmd_loglevel(self, cmd, level)
     |      Get or set the pyclewn log level.
     |
     |  cmd_mapkeys(self, *args)
     |      Map the pyclewn keys.
     |
     |  cmd_unmapkeys(self, cmd, *args)
     |      Unmap the pyclewn keys.
     |
     |      This is actually a Vim command and it does not involve pyclewn.
     |
     |  console_flush(self)
     |      Flush the console.
     |
     |  console_print(self, format, *args)
     |      Print a format string and its arguments to the console.
     |
     |      Method parameters:
     |          format: str
     |              The message format string.
     |          args: str
     |              The arguments which are merged into 'format' using the
     |              python string formatting operator.
     |
     |  debugger_background_jobs = _newf(self, *args, **kwargs)
     |      The decorated method.
     |
     |  default_cmd_processing(self, cmd, args)
     |      Fall back method for commands not handled by a 'cmd_<name>'
     |      method.
     |
     |      This method must be implemented in a subclass.
     |
     |      Method parameters:
     |          cmd: str
     |              The command name.
     |          args: str
     |              The arguments of the command.
     |
     |  delete_bp(self, bp_id)
     |      Delete a breakpoint.
     |
     |      The breakpoint must have been already set in a Vim buffer with
     |      'add_bp'.
     |
     |      Method parameter:
     |          bp_id: object
     |              The debugger breakpoint id.
     |
     |  get_console(self)
     |      Return the console.
     |
     |  get_lnum_list(self, pathname)
     |      Return a list of line numbers of all enabled breakpoints in a
     |      Vim buffer.
     |
     |      A line number may be duplicated in the list.
     |      This is used by Simple and may not be useful to other debuggers.
     |
     |      Method parameter:
     |          pathname: str
     |              The absolute pathname to the Vim buffer.
     |
     |  inferiortty(self)
     |      Spawn the inferior terminal.
     |
     |  netbeans_detach(self)
     |      Request vim to close the netbeans session.
     |
     |  not_a_pyclewn_method(self, cmd)
     |      "Warn that 'cmd' cannot be used as 'C' parameter.
     |
     |  post_cmd(self, cmd, args)
     |      The method called after each invocation of a 'cmd_<name>'
     |      method.
     |
     |      This method must be implemented in a subclass.
     |
     |      Method parameters:
     |          cmd: str
     |              The command name.
     |          args: str
     |              The arguments of the command.
     |
     |  pre_cmd(self, cmd, args)
     |      The method called before each invocation of a 'cmd_<name>'
     |      method.
     |
     |      This method must be implemented in a subclass.
     |
     |      Method parameters:
     |          cmd: str
     |              The command name.
     |          args: str
     |              The arguments of the command.
     |
     |  print_prompt(self)
     |      Print the prompt in the Vim debugger console.
     |
     |  remove_all(self)
     |      Remove all annotations.
     |
     |      Vim signs are unplaced.
     |      Annotations are not deleted.
     |
     |  set_nbsock(self, nbsock)
     |      Set the netbeans socket.
     |
     |  set_nbsock_owner(self, thread_ident, socket_map=None)
     |      Add nbsock to 'socket_map' and make 'thread_ident' nbsock owner.
     |
     |  show_balloon(self, text)
     |      Show 'text' in the Vim balloon.
     |
     |      Method parameter:
     |          text: str
     |              The text to show in the balloon.
     |
     |  show_frame(self, pathname=None, lnum=1)
     |      Show the frame highlighted sign in a Vim buffer.
     |
     |      The frame sign is unique.
     |      Remove the frame sign when 'pathname' is None.
     |
     |      Method parameters:
     |          pathname: str
     |              The absolute pathname to the Vim buffer.
     |          lnum: int
     |              The line number in the Vim buffer.
     |
     |  start(self)
     |      This method must be implemented in a subclass.
     |
     |  timer(self, callme, delta)
     |      Schedule the 'callme' job at 'delta' time from now.
     |
     |      The timer granularity is LOOP_TIMEOUT, so it does not make sense
     |      to request a 'delta' time less than LOOP_TIMEOUT.
     |
     |      Method parameters:
     |          callme: callable
     |              the job being scheduled
     |          delta: float
     |              time interval
     |
     |  update_bp(self, bp_id, disabled=False)
     |      Update the enable/disable state of a breakpoint.
     |
     |      The breakpoint must have been already set in a Vim buffer with
     |      'add_bp'.
     |      Return True when successful.
     |
     |      Method parameters:
     |          bp_id: object
     |              The debugger breakpoint id.
     |          disabled: bool
     |              When True, set the breakpoint as disabled.
     |
     |  update_dbgvarbuf(self, getdata, dirty, lnum=None)
     |      Update the variables buffer in Vim.
     |
     |      Update the variables buffer in Vim when one the following
     |      conditions is
     |      True:
     |          * 'dirty' is True
     |          * the content of the Vim variables buffer and the content of
     |            pyclewn 'dbgvarbuf' are not consistent after an error in the
     |            netbeans protocol occured
     |      Set the Vim cursor at 'lnum' after the buffer has been updated.
     |
     |      Method parameters:
     |          getdata: callable
     |              A callable that returns the content of the variables
     |              buffer as a string.
     |          dirty: bool
     |              When True, force updating the buffer.
     |          lnum: int
     |              The line number in the Vim buffer.
     |
     |  vim_script_custom(self, prefix)
     |      Return debugger specific Vim statements as a string.
     |
     |      A Vim script is run on Vim start-up, for example to define all
     |      the debugger commands in Vim. This method may be overriden to
     |      add some debugger specific Vim statements or functions to this
     |      script.
     |
     |      Method parameter:
     |          prefix: str
     |              The prefix used for the debugger commands in Vim.
     |

FUNCTIONS
    restart_timer(timeout)
        Decorator to re-schedule the method at 'timeout', after it has run.

==============================================================================
vim:tw=78:ts=8:ft=help:norl:et:
plugin/pyclewn.vim	[[[1
11
" Pyclewn run time file.
" Maintainer:   <xdegaye at users dot sourceforge dot net>

" Enable balloon_eval.
if has("balloon_eval")
    set ballooneval
    set balloondelay=100
endif

" The 'Pyclewn' command starts pyclewn and vim netbeans interface.
command -nargs=* -complete=file Pyclewn call pyclewn#StartClewn(<f-args>)
syntax/dbgvar.vim	[[[1
25
" Vim syntax file
" Language:	debugger variables window syntax file
" Maintainer:	<xdegaye at users dot sourceforge dot net>
" Last Change:	Oct 8 2007

if exists("b:current_syntax")
    finish
endif

syn region dbgVarChged display contained matchgroup=dbgIgnore start="={\*}"ms=s+1 end="$"
syn region dbgDeScoped display contained matchgroup=dbgIgnore start="={-}"ms=s+1 end="$"
syn region dbgVarUnChged display contained matchgroup=dbgIgnore start="={=}"ms=s+1 end="$"

syn match dbgItem display transparent "^.*$"
    \ contains=dbgVarUnChged,dbgDeScoped,dbgVarChged,dbgVarNum

syn match dbgVarNum display contained "^\s*\d\+:"he=e-1

high def link dbgVarChged   Special
high def link dbgDeScoped   Comment
high def link dbgVarNum	    Identifier
high def link dbgIgnore	    Ignore

let b:current_syntax = "dbgvar"

macros/.pyclewn_keys.gdb	[[[1
49
# .pyclewn_keys.gdb file
#
# The default placement for this file is $CLEWNDIR/.pyclewn_keys.gdb, or
# $HOME/.pyclewn_keys.gdb
#
# Key definitions are of the form `KEY:COMMAND'
# where the following macros are expanded:
#    ${text}:   the word or selection below the mouse
#    ${fname}:  the current buffer full pathname
#    ${lnum}:   the line number at the cursor position
#
# All characters following `#' up to the next new line are ignored.
# Leading blanks on each line are ignored. Empty lines are ignored.
#
# To tune the settings in this file, you will have to uncomment them,
# as well as change them, as the values on the commented-out lines
# are the default values. You can also add new entries. To remove a
# default mapping, use an empty GDB command.
#
# Supported key names:
#       . key function: F1 to F20
#             e.g., `F11:continue'
#       . modifier (C-,S-,M-) + function key
#             e.g., `C-F5:run'
#       . modifier (or modifiers) + character
#             e.g., `S-Q:quit', `C-S-B:info breakpoints'
#
# Note that a modifier is required for non-function keys. So it is not possible
# to map a lower case character with this method (use the Vim 'map' command
# instead).
#
# C-B : break "${fname}":${lnum} # set breakpoint at current line
# C-D : down
# C-E : clear "${fname}":${lnum} # clear breakpoint at current line
# C-N : next
# C-P : print ${text}            # print value of selection at mouse position
# C-U : up
# C-X : print *${text}           # print value referenced by word at mouse position
# C-Z : sigint                   # kill the inferior running program
# S-A : info args
# S-B : info breakpoints
# S-C : continue
# S-F : finish
# S-L : info locals
# S-Q : quit
# S-R : run
# S-S : step
# S-W : where
# S-X : foldvar ${lnum}          # expand/collapse a watched variable
macros/.pyclewn_keys.pdb	[[[1
44
# .pyclewn_keys.pdb file
#
# The default placement for this file is $CLEWNDIR/.pyclewn_keys.pdb, or
# $HOME/.pyclewn_keys.pdb
#
# Key definitions are of the form `KEY:COMMAND'
# where the following macros are expanded:
#    ${text}:   the word or selection below the mouse
#    ${fname}:  the current buffer full pathname
#    ${lnum}:   the line number at the cursor position
#
# All characters following `#' up to the next new line are ignored.
# Leading blanks on each line are ignored. Empty lines are ignored.
#
# To tune the settings in this file, you will have to uncomment them,
# as well as change them, as the values on the commented-out lines
# are the default values. You can also add new entries. To remove a
# default mapping, use an empty GDB command.
#
# Supported key names:
#       . key function: F1 to F20
#             e.g., `F11:continue'
#       . modifier (C-,S-,M-) + function key
#             e.g., `C-F5:run'
#       . modifier (or modifiers) + character
#             e.g., `S-Q:quit', `C-S-B:info breakpoints'
#
# Note that a modifier is required for non-function keys. So it is not possible
# to map a lower case character with this method (use the Vim 'map' command
# instead).
#
# C-B : break "${fname}:${lnum}" # set breakpoint at current line
# C-D : down
# C-E : clear "${fname}:${lnum}" # clear breakpoint at current line
# C-N : next
# C-P : p ${text}                # print value of selection at mouse position
# C-U : up
# C-Z : interrupt
# S-A : args
# S-B : break
# S-C : continue
# S-R : return
# S-S : step
# S-W : where
macros/.pyclewn_keys.simple	[[[1
38
# .pyclewn_keys.simple file
#
# The default placement for this file is $CLEWNDIR/.pyclewn_keys.simple, or
# $HOME/.pyclewn_keys.simple
#
# Key definitions are of the form `KEY:COMMAND'
# where the following macros are expanded:
#    ${text}:   the word or selection below the mouse
#    ${fname}:  the current buffer full pathname
#    ${lnum}:   the line number at the cursor position
#
# All characters following `#' up to the next new line are ignored.
# Leading blanks on each line are ignored. Empty lines are ignored.
#
# To tune the settings in this file, you will have to uncomment them,
# as well as change them, as the values on the commented-out lines
# are the default values. You can also add new entries. To remove a
# default mapping, use an empty GDB command.
#
# Supported key names:
#       . key function: F1 to F20
#             e.g., `F11:continue'
#       . modifier (C-,S-,M-) + function key
#             e.g., `C-F5:run'
#       . modifier (or modifiers) + character
#             e.g., `S-Q:quit', `C-S-B:info breakpoints'
#
# Note that a modifier is required for non-function keys. So it is not possible
# to map a lower case character with this method (use the Vim 'map' command
# instead).
#
# C-B : break ${fname}:${lnum}   # set breakpoint at current line
# C-E : clear ${fname}:${lnum}   # clear breakpoint at current line
# C-P : print ${text}            # print value of selection at mouse position
# C-Z : interrupt                # interrupt the execution of the target
# S-C : continue
# S-Q : quit
# S-S : step
