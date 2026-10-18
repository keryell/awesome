#!/usr/bin/env bash
# fix-displays.bash — un-stick a display output that dropped its link while X
# still holds it enabled with a stale mode.
#
# After a resume or a hotplug, a DisplayPort output (e.g. the ultrawide on
# DP-1, which rides USB-C DP-alt-mode and whose UCSI firmware is buggy) can
# lose its link yet stay configured: the kernel reports the connector
# "disconnected" while X keeps a CRTC on it, so `xrandr` lists it as
# "disconnected <WxH>+<X>+<Y>" — a phantom that darkens the monitor and leaves
# a window stranded on an invisible screen. Turning the phantom off releases
# the connector, and the monitor re-attaches on the next probe (xfsettingsd
# then re-applies the saved layout). The `xrandr --query` here forces that
# probe, which also re-detects a monitor that is physically back.
#
# Bound to Mod4+Control+Shift+d in awesomerc.lua. Safe to run anytime: with no
# phantom output it is a no-op.
#
# Added 2026-10-07. To revert: drop the keybinding from awesomerc.lua and
# delete this file.
set -u
export DISPLAY="${DISPLAY:-:0}"

xrandr --query \
  | awk '$2 == "disconnected" && $3 ~ /^[0-9]+x[0-9]+\+[0-9]+\+[0-9]+$/ { print $1 }' \
  | while read -r out; do
        xrandr --output "$out" --off
    done
