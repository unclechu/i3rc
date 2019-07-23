#!/usr/bin/env bash
set -e
SINK=`(pactl info | grep -i 'default sink:' | sed 's/^default sink:[ ]*//i')`

case "$1" in
	mute)
		pactl set-sink-mute "$SINK" true
		;;
	unmute)
		pactl set-sink-mute "$SINK" false
		;;
	mute-toggle)
		pactl set-sink-mute "$SINK" toggle
		;;
	inc)
		x=$([[ -n $2 ]] && printf -- '+%s' "$2" || printf -- '+1.0dB')
		pactl set-sink-mute   "$SINK" false
		pactl set-sink-volume "$SINK" "$(printf '%s' "$x")"
		;;
	dec)
		x=$([[ -n $2 ]] && printf -- '-%s' "$2" || printf -- '-1.0dB')
		pactl set-sink-mute   "$SINK" false
		pactl set-sink-volume "$SINK" "$(printf '%s' "$x")"
		;;

	reset)
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
	*)
		printf 'Unknown command: "%s"\n' "$1" 1>&2
		exit 1
		;;
esac
