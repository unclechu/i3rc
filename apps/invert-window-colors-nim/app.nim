# Author:  Viacheslav Lotsmanov
# License: GPLv3 https://raw.githubusercontent.com/unclechu/i3rc/master/apps/invert-window-colors-nim/license.txt

from strutils import parseInt, format
from posix    import exitnow
from re       import Regex, re, find

import osproc, streams, locks, types, ipc, threadpool

type
  Filter = object
    class: Maybe[string]
    name:  Maybe[string]
  AppDecl = tuple[name: string, filters: seq[Filter]]
  AppMapping = array[2, AppDecl]
  # AppMapping = array[9, AppDecl]

let
  nop = nothing[string]()
  mapping*: AppMapping =
    [ #("audacious",   @[Filter(class: just("^Audacious$"),   name: nop)])
    # , ("thunderbird", @[Filter(class: just("^Thunderbird$"), name: nop)])
    # , ("gajim",       @[Filter(class: just("^Gajim$"),       name: nop)])
      ("nheko",       @[Filter(class: just("^nheko$"),       name: nop)])
    # , ("keepassx",    @[Filter(class: just("^Keepassx$"),    name: nop)])
    , ("qbittorrent", @[Filter(class: just("^qBittorrent$"), name: nop)])
    # , ("hexchat",     @[Filter(class: just("^Hexchat$"),     name: nop)])
    # , ("doublecmd",   @[Filter(class: just("^Doublecmd$"),   name: nop)])
    # , ("gmrun",       @[Filter(class: just("^Gmrun$"),       name: nop)])
    ]

var
  appsCache: Maybe[seq[string]] = nothing[seq[string]]()
  L: Lock

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
    L.acquire
    stderr.writeline "Gotcha OSError [1]: " & getCurrentExceptionMsg()
    L.release

    childProc(cmd, args, handler, careAboutFail)
    return

  handler(hproc, sout)

  try: # FIXME this is hacky
    let code: int = hproc.waitForExit

    if careAboutFail.isJust and code != 0:
      var line: string = ""
      L.acquire
      while serr.readline(line): stderr.writeline line
      stderr.writeline careAboutFail.value & " failed with exit code: " & $code
      exitnow 1

    hproc.close
  except OSError:
    L.acquire
    stderr.writeline "Gotcha OSError [2]: " & getCurrentExceptionMsg()
    L.release

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
      L.acquire; stderr.writeline "Root window id not found!"; exitnow 1

  childProc( "xwininfo", ["-int", "-root"], handler
           , "Getting root window id".just )
  matches[0].parseInt.uint32

proc getParentWnd(childWnd: uint32): Maybe[uint32] =

  var matches: array[1, string] = [""]

  #[
    FIXME Sometimes (pretty rare) this happens:
      Traceback (most recent call last)
      threadpool.nim(329)      slave
      app.nim(173)             handleWndWrapper
      app.nim(156)             handleWnd
      app.nim(146)             getParentWnd
      app.nim(86)              childProc
      app.nim(134)             handler
      streams.nim(266)         readLine
      streams.nim(180)         readChar
      streams.nim(102)         readData
      streams.nim(390)         fsReadData
      sysio.nim(65)            checkErr
      sysio.nim(57)            raiseEIO
      system.nim(2724)         sysFatal
      Error: unhandled exception: Unknown IO Error [IOError]
  ]#
  proc handler(hproc: Process; sout: Stream) =
    var line: string = ""
    while sout.readline(line):
      if line == "":
        continue
      elif line.find(re"Parent\swindow\sid:\s+(\d+)", matches) != -1:
        hproc.terminate
        break
    if matches[0] == "":
      L.acquire
      stderr.writeline "Parent window id for '$1' not found!".format(childWnd)
      exitnow 1

  childProc( "xwininfo", ["-int", "-children", "-id", $childWnd], handler
           , nothing[string]() )

  if matches[0] == "":
    nothing[uint32]()
  else:
    matches[0].parseInt.uint32.just

var rootWnd: uint32

proc handleWnd(wnd: uint32; state: State) =
  let parwnd: Maybe[uint32] = wnd.getParentWnd
  if parwnd.isNothing or parwnd.value == rootWnd: return
  {.gcsafe.}:
    if state == toggle:
      # TODO do this hacky stuff different way
      ipc.setState(parwnd, State.off, failProtect=true)
      ipc.setState(parwnd, State.on,  failProtect=true)
    else:
      ipc.setState(parwnd, state, failProtect=true)

proc handleAppFilter(filter: Filter; state: State) =
  var args: seq[string] = @["search", "--onlyvisible", "--all"]
  if isJust filter.class: args.add(["--class", filter.class.value])
  if isJust filter.name: args.add(["--name", filter.name.value])

  proc handler(hproc: Process; sout: Stream) =
    var line: string = ""
    while sout.readline(line): spawn handleWnd(line.parseInt.uint32, state)

  childProc("xdotool", args, handler, nothing[string]())

proc handleApp(idx: int, state: State) {.thread.} =
  {.gcsafe.}: (let app: AppDecl = mapping[idx])
  L.acquire; "Handling '$1' application…".format(app.name).echo; L.release
  for n, x in app.filters.pairs: spawn handleAppFilter(x, state)

# FIXME Sometimes threads doesn't finishes and app is stuck forever.
proc handleApps*(indexes: seq[int]; state: State) =
  rootWnd = getRootWnd()
  for n, idx in indexes.pairs: spawn handleApp(idx, state)
  sync() # wait for all threads to finish
  L.acquire; "Done with apps.".echo; L.release

initLock L
