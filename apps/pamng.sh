#! /usr/bin/env bash
# Author: Viacheslav Lotsmanov
# License: MIT https://raw.githubusercontent.com/unclechu/i3rc/master/LICENSE-MIT
set -eu

# guard dependencies
>/dev/null type -P pactl
>/dev/null type -P grep
>/dev/null type -P sed
>/dev/null type -P awk
>/dev/null type -P xargs

COMMANDS=(mute unmute mute-toggle inc dec reset)

show-usage() {
	echo
	echo Usage:
	printf '  %s COMMAND\n' "$(basename -- "$0")"
	echo
	echo Available COMMANDs:
	printf '  %s\n' "${COMMANDS[@]}"
	echo
}

if (( $# < 1 )); then
	>&2 echo Incorrect arguments! Provide a command!
	>&2 show-usage
	exit 1
fi

SINK=$(pactl info | grep -i 'default sink:' | sed 's/^default sink:[ ]*//i')

case $1 in
	mute)
		if (( $# != 1 )); then >&2 echo Incorrect arguments; exit 1; fi
		pactl set-sink-mute "$SINK" true
		;;
	unmute)
		if (( $# != 1 )); then >&2 echo Incorrect arguments; exit 1; fi
		pactl set-sink-mute "$SINK" false
		;;
	mute-toggle)
		if (( $# != 1 )); then >&2 echo Incorrect arguments; exit 1; fi
		pactl set-sink-mute "$SINK" toggle
		;;
	inc)
		if (( $# < 1 || $# > 2 )); then
			>&2 echo Incorrect arguments
			exit 1
		fi

		x=$(
			if (( $# == 2 ))
			then printf -- '+%s' "$2"
			else printf -- '+1.0dB'
			fi
		)

		pactl set-sink-mute   "$SINK" false
		pactl set-sink-volume "$SINK" "$x"
		;;
	dec)
		if (( $# < 1 || $# > 2 )); then
			>&2 echo Incorrect arguments
			exit 1
		fi

		x=$(
			if (( $# == 2 ))
			then printf -- '-%s' "$2"
			else printf -- '-1.0dB'
			fi
		)

		pactl set-sink-mute   "$SINK" false
		pactl set-sink-volume "$SINK" "$x"
		;;
	reset)
		if (( $# != 1 )); then >&2 echo Incorrect arguments; exit 1; fi

		# reset devices outputs volumes
		pactl list sinks short \
			| awk '{print $2}' \
			| xargs -I {} pactl set-sink-volume '{}' 0db

		# reset devices inputs volumes
		pactl list sources short \
			| awk '{print $2}' \
			| xargs -I {} pactl set-source-volume '{}' 0db

		# reset applications outputs volumes
		pactl list sink-inputs short \
			| awk '{print $1}' \
			| xargs -I {} pactl set-sink-input-volume '{}' 0db

		# reset applications inputs volumes
		pactl list source-outputs short \
			| awk '{print $1}' \
			| xargs -I {} pactl set-source-output-volume '{}' 0db
		;;
	-h|--help|help)
		show-usage
		exit
		;;
	*)
		>&2 printf 'Unknown command: "%s"!\n' "$1"
		>&2 show-usage
		exit 1
		;;
esac
