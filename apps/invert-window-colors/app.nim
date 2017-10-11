# Author:  Viacheslav Lotsmanov
# License: GPLv3 https://raw.githubusercontent.com/unclechu/i3rc/master/apps/invert-window-colors/license.txt

from strutils import parseInt, format
from posix    import exitnow
from re       import Regex, re, find

# import osproc, streams, locks, types, ipc, threadpool
import osproc, streams, locks, types, ipc

type
  Filter = object
    class: Maybe[string]
    name:  Maybe[string]
  AppDecl = tuple[name: string, filters: seq[Filter]]
  AppMapping = array[9, AppDecl]

let
  nop = nothing[string]()
  mapping*: AppMapping =
    [ ("audacious",   @[Filter(class: just("^Audacious$"),   name: nop)])
    , ("thunderbird", @[Filter(class: just("^Thunderbird$"), name: nop)])
    , ("gajim",       @[Filter(class: just("^Gajim$"),       name: nop)])
    , ("nheko",       @[Filter(class: just("^nheko$"),       name: nop)])
    , ("keepassx",    @[Filter(class: just("^Keepassx$"),    name: nop)])
    , ("qbittorrent", @[Filter(class: just("^qBittorrent$"), name: nop)])
    , ("hexchat",     @[Filter(class: just("^Hexchat$"),     name: nop)])
    , ("doublecmd",   @[Filter(class: just("^Doublecmd$"),   name: nop)])
    , ("gmrun",       @[Filter(class: just("^Gmrun$"),       name: nop)])
    ]

var
  appsCache: Maybe[seq[string]] = nothing[seq[string]]()
  # L: Lock

proc getApps*(): seq[string] =
  case appsCache.kind
    of Just: result = appsCache.value
    of Nothing:
         result = @[]
         for x in mapping: result.add x.name
         appsCache = result.just

#[
  FIXME Sometimes it fails with error like this:
    Traceback (most recent call last)
    app.nim(122)             handleWnd
    app.nim(101)             getParentWnd
    app.nim(48)              childProc
    osproc.nim(808)          startProcess
    osproc.nim(916)          startProcessAuxFork
    oserr.nim(113)           raiseOSError
    Error: unhandled exception:
      Additional info: Could not find command: 'xwininfo'. OS error: Bad file descriptor [OSError]
  Sometimes with this one:
    Traceback (most recent call last)
    app.nim(122)             handleWnd
    app.nim(101)             getParentWnd
    app.nim(50)              childProc
    osproc.nim(1211)         errorStream
    osproc.nim(1196)         createStream
    oserr.nim(113)           raiseOSError
    Error: unhandled exception: Bad file descriptor [OSError]
  Usually it happens with "Gotcha OSError [1]: …".
  I have never seen it happened with "Gotcha OSError [2]: …".
]#
proc childProc( cmd: string; args: openarray[string]
              ; handler: proc (hproc: Process; sout: Stream)
              ; careAboutFail: Maybe[string] ) =

  var
    hproc: Process
    sout:  Stream
    serr:  Stream
  try: # FIXME this is hacky
    hproc = startProcess(command=cmd, args=args, options={poUsePath})
    sout  = hproc.outputStream
    serr  = hproc.errorStream
  except OSError:
    # L.acquire
    stderr.writeline "Gotcha OSError [1]: " & getCurrentExceptionMsg()
    # L.release

    childProc(cmd, args, handler, careAboutFail)
    return

  handler(hproc, sout)

  try: # FIXME this is hacky
    let code: int = hproc.waitForExit

    if careAboutFail.isJust and code != 0:
      var line: string = ""
      # L.acquire
      while serr.readline(line): stderr.writeline line
      stderr.writeline careAboutFail.value & " failed with exit code: " & $code
      exitnow 1

    hproc.close
  except OSError:
    # L.acquire
    stderr.writeline "Gotcha OSError [2]: " & getCurrentExceptionMsg()
    # L.release

    childProc(cmd, args, handler, careAboutFail)
    return

# FIXME Sometimes it fails with:
#       Getting root window id failed with exit code: 143
#       (That comes from `childProc`)
proc getRootWnd(): uint32 =

  var matches: array[1, string] = [""]

  proc handler(hproc: Process; sout: Stream) =
    var line: string = ""
    while sout.readline(line):
      if line == "":
        continue
      elif line.find(re"Window\sid:\s+(\d+)", matches) != -1:
        hproc.terminate
        break
    if matches[0] == "":
      # L.acquire; stderr.writeline "Root window id not found!"; exitnow 1
      stderr.writeline "Root window id not found!"

  childProc( "xwininfo", ["-int", "-root"], handler
           , "Getting root window id".just )
  matches[0].parseInt.uint32

var rootWnd: uint32

# FIXME Sometimes threads doesn't finishes and app is stuck forever.
proc handleApps*(indexes: seq[int]; state: State) =
  rootWnd = getRootWnd()
  rootWnd.echo
  "Done with apps.".echo

# initLock L
