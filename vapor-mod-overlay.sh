#!/bin/bash
# Do you even vape, bruh?

DATA="${XDH_DATA_HOME:-$HOME/.local/share}/vapor-mod-overlay"
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

