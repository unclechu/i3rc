# Author:  Viacheslav Lotsmanov
# License: GPLv3 https://raw.githubusercontent.com/unclechu/i3rc/master/apps/invert-window-colors/license.txt

from strutils import replace
from os       import getenv

import types, dbus, locks

let
  bus: Bus        = getbus dbus.DBUS_BUS_SESSION
  dpy: string     = getenv("DISPLAY").replace(':', '_').replace('.', '_')
  dst: string     = "com.github.chjj.compton." & dpy
  obj: ObjectPath = "/".ObjectPath

bus.GC_ref
var L: Lock

proc dbusReq*(callMethod: string; args: varargs[DbusValue]): Reply =
  L.acquire
  let msg: Message = makecall(dst, obj, "com.github.chjj.compton", callMethod)
  for x in args: msg.append x
  result = waitForReply sendMessageWithReply(bus, msg)
  L.release
  result.raiseIfError

proc getFocusedWnd(): uint32 {.inline.} =
  let reply = dbusReq("find_win", "focused".asDbusValue)
  var iter = reply.iterate
  result = iter.unpackCurrent uint32;
  iter.ensureEnd; reply.close

proc setState*(wnd: Maybe[uint32]; state: State, failProtect: bool = false) =
  let curWnd = if wnd.kind == Nothing: getFocusedWnd() else: wnd.value
  var newState: bool

  try:
    if state != toggle:
      newState = state == State.on
    else:
      let reply = dbusReq( "win_get", curWnd.asDbusValue
                         , "invert_color_force".asDbusValue )
      var iter = reply.iterate
      newState = iter.unpackCurrent(uint16) != 1
      iter.ensureEnd; reply.close

    dbusReq( "win_set", curWnd.asDbusValue, "invert_color_force".asDbusValue
           , uint16(newState).asDbusValue ).close
  except DbusRemoteException:
    if failProtect:
      stderr.writeline(
        "Prevented fail by remote DBus exception: " & getCurrentExceptionMsg())
    else:
      raise

initLock L
