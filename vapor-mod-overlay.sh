#!/bin/bash
# Do you even vape, bruh?
declare -r VAPOR_VERSION="0.0.1"
declare -r VAPOR_UPSTREAM="https://github.com/ChristianSilvermoon/vapor-mod-overlay"
DATA="${XDH_DATA_HOME:-$HOME/.local/share}/vapor-mod-overlay"

case "$1" in
	"--help"|"-?")
		echo -e "\e[32;1m${0##*/}\e[37m - \e[36mSimple OverlayFS-based Mod Loader for Steam\e[0m\n"

		echo -e "\e[1mUSAGE (Set Steam Launch Options)\e[0m"
		echo "   ${0##*/} MOD_1 MOD_2 -- %command%"
		echo -e "\n\e[1mOPTIONS\e[0m"
		printf "  %-28s %s\n" \
			"--list, -l"     "List all mods"             \
			"--version, -v"  "Print Version Information" \
			"--help, -?"     "Display this message"

		echo -e "\n\e[1mENVIRONMENT\e[0m\n"
		printf "  %-28s %s\n%45s\n\n" \
			"\$VAPOR_DONT"             "Do Not Do Anything (useful for quick disabling mods)" "<on|true|1>" \
			"\$VAPOR_LOGGING"          "Enable Logging To Disk."                              "<on|true|1>" \
			"\$VAPOR_DEBUG"            "If Logging is enabled, log Environment and Options"   "<ANY VALUE>" \
			"\$VAPOR_UNIVERSAL_UPPER"  "Use a Universal OverlayFS Upper (NOT RECOMMENDED)"    "<on|true|1>"

		echo -e "\e[1mSPECIAL MOD FOLDER FILES\e[0m\n"
		printf "  %s\n    %s\n\n" \
			"VAPOR_LAUNCH_OPTIONS_APPEND.txt"  "Additional Arguments placed AFTER %command% (one per line)"  \
			"VAPOR_LAUNCH_OPTIONS_PREPEND.txt" "Additional Arguments placed BEFORE %command% (one per line)" \
			"VAPOR_INFO.txt"                   "Descriptive text displayed for a mod when '--list' is used."
		exit
	;;
	"--list"|"-l")
		cd "$DATA/mods"
		echo -e "\e[32;4;1mVAPOR MOD OVERLAY - MODS\e[0m\n"
		echo -e "\e[1mLocation: \e[0m$DATA/mods\n"

		for GAME in *; do
			[ -d "$GAME" ] || continue
			echo -e "\e[1m$GAME\e[0m"
			MODS=$(
				for MOD in "$GAME"/*; do
					[ -d "$MOD" ] || continue
					echo "  - ${MOD#*/}"
					if [ -f "$MOD/VAPOR_INFO.txt" ]; then
						echo -en "\e[2m"
						while read modline; do
							echo "      $modline"
						done < "$MOD/VAPOR_INFO.txt"
						echo -e "\e[0m"
					fi
				done
			)
			if [ "$MODS" ]; then
				echo "$MODS"
			else
				echo -e "  \e[31;2mNo Mods Available\e[0m"
			fi

			echo ""
		done
		exit
	;;
	"--version"|"-v")
		printf "%s\n" \
			"Vapor Mod Overlay, v${VAPOR_VERSION}"                               \
			"Copyright (C) 2025-2026 Krissy Silvermoon"                          \
			"License: MIT <https://opensource.org/license/mit>"                  \
			""                                                                   \
			"This is free software; you are free to change and redistribute it." \
			"There is NO WARRANTY, to the extent permitted by law."              \
			""                                                                   \
			"Upstream Source Repository"
			echo -e "  \e]8;;${VAPOR_UPSTREAM}\e\\${VAPOR_UPSTREAM}\e]8;;\e\\"

		exit
	;;
esac

GAMEDIR="$STEAM_COMPAT_INSTALL_PATH"

# We can't really safely assume we can do non-steam games
[ "$SteamAppId" = "0" ] && exit

if [ "$SteamAppId" != "0" ]; then
	GDNAME="$SteamGameId - ${STEAM_COMPAT_INSTALL_PATH##*/}"
else
	mapfile -d '/' -t GDNAME < <(pwd)

	GDNAME="$(printf "%s_" "${GDNAME[@]: -2:2}" | tr -d '\n')"
	GDNAME="$SteamGameId - NONSTEAM - ${GDNAME%_}"
fi

GAME_MOD_DIR="$DATA/mods/$GDNAME"
GAME_LOG_DIR="$DATA/logs/$GDNAME"
GAME_OVERLAY_UPPER_DIR="$DATA/overlayfs/$GDNAME/upper"
GAME_OVERLAY_WORK_DIR="$DATA/overlayfs/$GDNAME/work"
LOG="$GAME_LOG_DIR/${EPOCHSECONDS}.log"

[ -d "$DATA/mods"              ] || mkdir -p "$DATA/mods"
[ -d "$GAME_MOD_DIR"           ] || mkdir -p "$GAME_MOD_DIR"
[ -d "$GAME_LOG_DIR"           ] || mkdir -p "$GAME_LOG_DIR"
[ -d "$GAME_OVERLAY_UPPER_DIR" ] || mkdir -p "$GAME_OVERLAY_UPPER_DIR"
[ -d "$GAME_OVERLAY_WORK_DIR"  ] || mkdir -p "$GAME_OVERLAY_WORK_DIR"

log() {
	case "${VAPOR_LOGGING,,}" in
		"1"|"true"|"on")
			printf "%s\n" "$@" >> "$LOG"
		;;
		*) : ;;
	esac
}


[ "$SteamAppId" = "0" ] && pwd > "$GAME_LOG_DIR/pwd.log"

if [ "VAPORMOD_DEBUG" ]; then
	log "-- ARGUMENTS -------------"
	log "$(printf -- "%s\n" "$@")"
	log "--------------------------"
	log ""
	log "-- ENVIRONMENT -----------"
	log "$(printenv)"
	log "--------------------------"
	log ""
fi

for mod in "$@"; do
	shift # Eat the option off the list
	[ "$mod" = "--" ] && break

	if [ -d "$GAME_MOD_DIR/$mod"     ]; then
		MODS+=( "$GAME_MOD_DIR/$mod"     )
		MODLIST+=( "$mod" )
		continue
	fi

	MOD_NOT_FOUND+=( "$mod" )

done

# Handle Upper Directory so that OvrelayFS is read-write
case "${VAPOR_UNIVERSAL_UPPER,,}" in
	"1"|"true"|"on")
		GAME_OVERLAY_UPPER_DIR+="/UNIVERSAL"
	;;
	*)
		if [ "${#MODLIST[@]}" -gt "1" ]; then
			MODLIST_HASH="$(printf "%s\n" "${MODLIST[@]}" | sha256sum)"
			MODLIST_HASH="${MODLIST_HASH%% *}"
			GAME_OVERLAY_UPPER_DIR+="/$MODLIST_HASH"
			# Leave an explanation of the modlist for the user to see
			{
				echo "Mod List"
				printf -- "- %s\n" "${MODLIST[@]}"
			} > "${GAME_OVERLAY_UPPER_DIR}.modlist"
		else
			GAME_OVERLAY_UPPER_DIR+="/${MODLIST[0]}"
		fi
	;;
esac

[ -d "$GAME_OVERLAY_UPPER_DIR" ] || mkdir -p "$GAME_OVERLAY_UPPER_DIR"

# Skip mod loading if "VAPOR_DONT" is set to 1
case "${VAPOR_DONT,,}" in
	"1"|"true"|"on") exec "$@" ;;
	*) : ;;
esac
# ---------------------------------------

if [ "$MOD_NOT_FOUND" ]; then
	log "MODS NOT FOUND"
	log "$(printf -- " - %s\n" "${MOD_NOT_FOUND[@]}")"

	exit 1
fi



PROPER_PWD="$PWD"
cd ..


# READ Launch Options from mods
for x in "${MODS[@]}"; do
	[ -r "$x/VAPOR_LAUNCH_OPTIONS_PREPEND.txt" ] || continue
	mapfile -t extra_options < "$x/VAPOR_LAUNCH_OPTIONS_PREPEND.txt"
	VAPOR_LAUNCH_OPTIONS_PREPEND+=( "${extra_options[@]}" )
done

for x in "${MODS[@]}"; do
	[ -r "$x/VAPOR_LAUNCH_OPTIONS_APPEND.txt" ] || continue
	mapfile -t extra_options < "$x/VAPOR_LAUNCH_OPTIONS_APPEND.txt"
	VAPOR_LAUNCH_OPTIONS_APPEND+=( "${extra_options[@]}" )
done

# Move game directory to backup
mv "${PROPER_PWD##*/}" "${PROPER_PWD##*/}.vanilla"

# Setup Fuse Overlayfs
LOWDIRS="$(printf -- '%s:' "${MODS[@]}")" # Will have a trailing ":" conveniently for us :)
LOWDIRS+="${PROPER_PWD##*/}.vanilla"
mkdir "$PROPER_PWD"
fuse-overlayfs -o "lowerdir=${LOWDIRS},upperdir=${GAME_OVERLAY_UPPER_DIR},workdir=${GAME_OVERLAY_WORK_DIR}" "$PROPER_PWD" || exit 1 
"${VAPOR_LAUNCH_OPTIONS_PREPEND[@]}" "$@" "${VAPOR_LAUNCH_OPTIONS_APPEND[@]}" # Launch Game

# Clean up
fusermount -u "$PROPER_PWD"   || exit 1 # Unmount Overlayfs
rmdir "${PROPER_PWD}"         || exit 1 # Get rid of Empty directory
mv "${PROPER_PWD}"{.vanilla,}           # Restore Game Directory

