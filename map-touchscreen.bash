#!/usr/bin/env bash
# map-touchscreen.bash — keep the external touchscreen's coordinates aligned
# with its display, wherever that display sits in the virtual desktop and
# whatever connector it lands on.
#
# `xinput map-to-output` re-derives the Coordinate Transformation Matrix from
# the *current* RandR geometry, so re-running it after any layout change keeps
# touch input correct regardless of the display's position, size, or connector
# name. We store no matrix; awesomerc.lua re-invokes this on every screen
# add/remove (and once at session start).
#
# The target output is found by EDID, NOT by connector name: with several
# external monitors connected, the connector name (and even "non-internal") is
# ambiguous, and a dock can move the panel to a different port. The WingCool
# USB-C touch monitor presents over video as a Realtek panel whose EDID
# monitor-name (descriptor 0xFC) is "TYPEC"; that identifier travels with the
# monitor across ports.
#
# Added 2026-06-02. To revert: drop the screen-signal hooks + startup call from
# awesomerc.lua and delete this file. To clear a bad mapping live, reset the
# matrix to identity:
#   xinput set-prop <id> "Coordinate Transformation Matrix" 1 0 0 0 1 0 0 0 1

set -u

# xinput device name of the touch panel (it exposes several pointer devices).
touch_name='WingCool Inc. TouchScreen'
# EDID 0xFC monitor-name of the touch panel's video side. Change this if the
# panel is replaced; find it with:  xrandr --props | sed -n '/EDID/,/:/p'
panel_edid_name='TYPEC'

# Print the connected RandR output whose EDID 0xFC monitor-name equals $1.
find_output_by_edid_name() {
    xrandr --props 2>/dev/null | gawk -v want="$1" '
        function flush(   i, namehex, j, c, name) {
            if (!have) return
            have = 0
            i = index(hex, "000000fc00")          # FC = monitor-name descriptor
            if (i == 0) return
            namehex = substr(hex, i + 10, 26)      # 13 bytes follow the tag
            name = ""
            for (j = 1; j <= length(namehex); j += 2) {
                c = strtonum("0x" substr(namehex, j, 2))
                if (c == 10) break                 # names are 0x0A-terminated
                if (c >= 32 && c < 127) name = name sprintf("%c", c)
            }
            sub(/[[:space:]]+$/, "", name)
            if (name == want) { print ediout; found = 1; exit }
        }
        / connected/ { flush(); out = $1 }
        /EDID:/      { have = 1; hex = ""; ediout = out; next }
        have && /^[[:space:]]*[0-9a-fA-F]+$/ { gsub(/[[:space:]]/, ""); hex = hex tolower($0); next }
        have         { flush() }
        END          { if (!found) flush() }
    '
}

# Count connected non-internal (non-eDP*) outputs.
count_external() {
    xrandr --query | awk '/ connected/ && $1 !~ /^eDP/' | wc -l
}

map_once() {
    local target ids id
    target=$(find_output_by_edid_name "$panel_edid_name")
    # Fallback only when unambiguous: exactly one external output connected.
    if [ -z "$target" ] && [ "$(count_external)" = 1 ]; then
        target=$(xrandr --query | awk '/ connected/ && $1 !~ /^eDP/ { print $1; exit }')
    fi
    # Refuse to guess when the panel can't be identified and the layout is
    # ambiguous: better an unmapped touchscreen than one mapped to the wrong
    # display.
    [ -z "$target" ] && return 1

    ids=$(xinput list | grep -F "$touch_name" | grep -i pointer \
              | grep -oE 'id=[0-9]+' | cut -d= -f2)
    [ -z "$ids" ] && return 1

    for id in $ids; do
        xinput map-to-output "$id" "$target"
    done
    return 0
}

# On hotplug the RandR output can appear a moment before the USB touch input
# device is registered, so retry briefly. If the panel is simply absent this
# exits 0 after a couple of seconds as a harmless no-op.
for _ in 1 2 3 4 5; do
    map_once && exit 0
    sleep 0.5
done
exit 0
