# Author:  Viacheslav Lotsmanov
# License: GPLv3 https://raw.githubusercontent.com/unclechu/i3rc/master/apps/invert-window-colors-nim/license.txt

from strutils import format, join, parseuint, replace, split
from sequtils import filterIt, mapIt, newSeqWith
from re       import re, match
from os       import paramstr, paramcount, commandLineParams
from posix    import exitnow
from dbus     import asDbusValue, close

import types, ipc, app

const
  stCmd     = [ "on",     "off",     "toggle"     ]
  stCmdEnum = [ State.on, State.off, State.toggle ]

proc isForCommand(): bool {.inline.} = (
  paramcount() in [2, 3] and paramstr(1) == "for" and
  paramstr(2).match(re"\d+") and
  (paramcount() == 2 or paramstr(3) in stCmd)
  )

proc isAppCommand(): bool {.inline.} = (
  paramcount() in [2, 3] and paramstr(1) == "app" and
  (paramstr(2) == "all" or paramstr(2).match(re"[a-z, ]+")) and
  (paramcount() == 2 or paramstr(3) in stCmd)
  )

proc toState(cmd: string): State {.inline.} = stCmdEnum[stCmd.find cmd]

proc usageInfo(): string = """
$1 usage info:
  `$1 help` to show this usage info
  `$1` without any arguments will toggle current focused window
  `$1 toggle` explicitly toggle
  `$1 on`
  `$1 off`
  `$1 for 123456` will toggle window where "123456" is X window id
    (usually it's wrapper-window, the compton needs it)
  `$1 for 123456 toggle` explicitly toggle
  `$1 for 123456 on`
  `$1 for 123456 off`
  `$1 app all` to toggle all known apps
  `$1 app all toggle` explicitly toggle
  `$1 app all on`
  `$1 app all off`
  `$1 app gajim` toggle windows of gajim apps
    (mapping for "gajim" must be declared in this app code)
  `$1 app gajim toggle` explicitly toggle
  `$1 app gajim on`
  `$1 app gajim off`
  `$1 app gajim,audacious`
  `$1 app gajim,audacious toggle`
  `$1 app 'gajim, audacious' on`
  `$1 app 'gajim , audacious' off`
""".format(paramstr 0)

dbusReq("opts_set", "track_focus".asDbusValue, true.asDbusValue).close

if paramcount() == 0 or (paramcount() == 1 and paramstr(1) in stCmd):
  let s = if paramcount() == 0: toggle else: toState(paramstr 1)
  setState(nothing[uint32](), s)
elif isForCommand():
  let s = if paramcount() == 2: toggle else: toState(paramstr 3)
  setState(paramstr(2).parseuint.uint32.just, s)

elif isAppCommand():

  let s = if paramcount() == 2: toggle else: toState(paramstr 3)
  var appsIndexes: seq[int]

  if paramstr(2) == "all":
    appsIndexes = getApps().len.newSeqWith(-1)
    for idx, _ in getApps().pairs: appsIndexes[idx] = idx
  else:

    let apps: seq[string] =
      paramstr(2).replace(" ", "").split(',').filterIt(it != "")

    for app in apps:
      if app notin getApps():
        stderr.writeline "Unknown app: '$1'".format(app)
        exitnow 1

    appsIndexes = apps.len.newSeqWith(-1)
    for n, app in apps.pairs: appsIndexes[n] = getApps().find app

  handleApps(appsIndexes, s)

elif paramcount() == 1 and paramstr(1) == "help":
  stdout.write usageInfo()
  exitnow 2
else:
  stderr.write usageInfo()
  stderr.writeline(
    "Incorrect arguments: [$1]"
      .format(commandLineParams().mapIt("'" & it & "'").join ", "))
  exitnow 1
