#!/bin/bash

exec 0<&-

displays=$(
	xrandr --current \
	| grep -oP '(?! )(\d+)x(\d+)\+(\d+)\+(\d+)' \
	| sed 's/[x+]/ /g'
)
[ $? -ne 0 ] && { echo 'Error while getting displays info' 1>&2; exit 1; }
displays_count=$[$(echo "$displays" | wc -l)]
[ $? -ne 0 ] && { echo 'Error while getting displays info' 1>&2; exit 1; }

usage() {
	echo \
		"Usage: $(basename "$0") [-p <lt|ct|rt|lc|cc|rc|lb|cb|rb>]" \
		"<number> (display number)" \
		1>&2
	exit 1
}

# positions of mouse cursor in percents of screen size
offset_x=
offset_y=

# parsing arguments
while getopts ":p:" opt; do
	case "$opt" in
		p)
			if [[ -n $offset_x ]]; then
				echo 'Position already set' 1>&2
				usage
			fi
			case "$OPTARG" in
				lt) offset_x=10 offset_y=10 ;;
				ct) offset_x=50 offset_y=10 ;;
				rt) offset_x=90 offset_y=10 ;;
				lc) offset_x=10 offset_y=50 ;;
				cc) offset_x=50 offset_y=50 ;;
				rc) offset_x=90 offset_y=50 ;;
				lb) offset_x=10 offset_y=90 ;;
				cb) offset_x=50 offset_y=90 ;;
				rb) offset_x=90 offset_y=90 ;;
				*)
					echo 'Incorrect position' 1>&2
					usage
					;;
			esac
			;;
		*)
			echo 'Invalid arguments' 1>&2
			usage
			;;
	esac
done
shift $((OPTIND-1))

# default offset values (as 'rb' position)
[[ -z $offset_x ]] && offset_x=90
[[ -z $offset_y ]] && offset_y=90

if [ "$#" -ne 1 ] \
|| ! echo "$(seq "$displays_count")" | grep -F -- "$1" 2>&1 1>/dev/null; then
	echo 'Incorrect arguments' 1>&2
	usage
fi

display_info=$(echo "$displays" | head -n "$[$1]" | tail -n 1)
display_w=$[`echo "$display_info" | cut -d ' ' -f 1`]
display_h=$[`echo "$display_info" | cut -d ' ' -f 2`]
display_x=$[`echo "$display_info" | cut -d ' ' -f 3`]
display_y=$[`echo "$display_info" | cut -d ' ' -f 4`]

to_display_x=$[$display_x + $[ $display_w * $offset_x / 100 ]]
to_display_y=$[$display_y + $[ $display_h * $offset_y / 100 ]]

xdotool mousemove "$to_display_x" "$to_display_y"
exit $?
