# Author:  Viacheslav Lotsmanov
# License: GPLv3 https://raw.githubusercontent.com/unclechu/i3rc/master/apps/invert-window-colors/license.txt

from strutils import replace, format, join, parseuint
from re       import re, match
from posix    import exitnow
from os       import getenv, paramstr, paramcount, commandLineParams
import dbus

type
  State = enum on, off, toggle
  MaybeEnum = enum Just, Nothing
  Maybe[T] = object
    case kind: MaybeEnum
      of Just: value: T
      of Nothing: discard

const
  stCmd = ["on", "off", "toggle"]
  stCmdEnum = [on, off, toggle]

let
  bus: Bus        = getbus dbus.DBUS_BUS_SESSION
  dpy: string     = getenv("DISPLAY").replace(':', '_').replace('.', '_')
  dst: string     = "com.github.chjj.compton." & dpy
  obj: ObjectPath = "/".ObjectPath

proc dbusReq(callMethod: string; args: varargs[DbusValue]): Reply =
  let msg: Message = makecall(dst, obj, "com.github.chjj.compton", callMethod)
  for x in args: msg.append x
  result = waitForReply sendMessageWithReply(bus, msg)
  result.raiseIfError

proc getFocusedWnd(): uint32 =
  let reply = dbusReq("find_win", "focused".asDbusValue)
  var iter = reply.iterate
  result = iter.unpackCurrent uint32;
  iter.ensureEnd; reply.close

proc setState(wnd: Maybe[uint32]; state: State) =
  let curWnd = if wnd.kind == Nothing: getFocusedWnd() else: wnd.value
  var newState: bool

  if state != toggle:
    newState = state == on
  else:
    let reply = dbusReq( "win_get", curWnd.asDbusValue
                       , "invert_color_force".asDbusValue )
    var iter = reply.iterate
    newState = iter.unpackCurrent(uint16) != 1
    iter.ensureEnd; reply.close

  dbusReq( "win_set", curWnd.asDbusValue, "invert_color_force".asDbusValue
         , uint16(newState).asDbusValue ).close

proc isForCommand(): bool {.inline.} = (
  paramcount() in [2, 3] and paramstr(1) == "for" and
  paramstr(2).match(re r"\b\d+\b") and
  (paramcount() == 2 or (paramcount() == 3 and paramstr(3) in stCmd)))

dbusReq("opts_set", "track_focus".asDbusValue, true.asDbusValue).close

if paramcount() == 0 or (paramcount() == 1 and paramstr(1) in stCmd):
  let s = if paramcount() == 0: toggle else: stCmdEnum[stCmd.find paramstr(1)]
  setState(Maybe[uint32](kind: Nothing), s)
elif isForCommand():
  let s = if paramcount() == 2: toggle else: stCmdEnum[stCmd.find paramstr(3)]
  setState(Maybe[uint32](kind: Just, value: paramstr(2).parseuint.uint32), s)
else:
  stderr.writeline(
    "Incorrect arguments: [$1]".format(commandLineParams().join ", "))
  exitnow 1
