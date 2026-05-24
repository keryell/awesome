#!/usr/bin/env bash
set -vx

skip-in-xfce() {
  if [ "$XDG_SESSION_DESKTOP" != "xfce-awesome" ]; then
    "$@"
  fi
}

# The typical things loaded in a Xilinx session for Ronan Keryell


# --- Knobs -----------------------------------------------------------
# Enable AT-SPI introspection for the session.  When on, Electron apps
# (Slack, Discord) build their renderer accessibility tree and Mozilla
# apps (Firefox, Thunderbird) opt into the GNOME accessibility bus,
# which lets external tools (e.g. Claude Code agents) read message
# threads, page content, etc. via AT-SPI.  GTK and Qt apps already
# expose themselves by default.  Set to 0 to skip the Electron a11y
# tree's perf cost.  See ~/.claude/CLAUDE.md "Reading Slack messages
# the hard way" for the read-side workflow.
ENABLE_ASSISTIVE_TECHNOLOGY=1

if [ "$ENABLE_ASSISTIVE_TECHNOLOGY" = 1 ]; then
  # Electron: passed on the command line of each Electron app below.
  ELECTRON_AT_ARGS=("--force-renderer-accessibility")
  # Mozilla / Gecko: env var inherited by firefox / thunderbird below.
  export GNOME_ACCESSIBILITY=1
else
  ELECTRON_AT_ARGS=()
fi
# ---------------------------------------------------------------------


# Desktop daemons that xfce4-session used to launch for us.
# Under the plain awesome session we bring them up explicitly,
# guarded with pgrep so a manual re-source does not duplicate them.
skip-in-xfce bash -c 'pgrep -x xfsettingsd          >/dev/null || xfsettingsd &'
skip-in-xfce bash -c 'pgrep -x xfce4-power-manager  >/dev/null || xfce4-power-manager &'
skip-in-xfce bash -c 'pgrep -x lxpolkit             >/dev/null || lxpolkit &'

# For some reasons the WiFi is randomly blocked
# rkeryell@8835865-lcelt:~$ rfkill
# ID TYPE      DEVICE              SOFT      HARD
#  0 wlan      dell-wifi        blocked unblocked
#  1 bluetooth dell-bluetooth unblocked unblocked
#  2 wlan      phy0             blocked   blocked
#  3 bluetooth hci0           unblocked unblocked
rfkill unblock all

RK_TERMINAL=
skip-in-xfce eval `ssh-agent -s`
# Under autostart there is no tty, so route the passphrase prompt through
# the X11 askpass dialog. Redirecting stdin from /dev/null also triggers the
# dialog when this script is sourced from a terminal.
#SSH_ASKPASS=/usr/bin/ssh-askpass ssh-add < /dev/null

# This seems to break ibus: XMODIFIERS=@im=ibus
skip-in-xfce unset XMODIFIERS
skip-in-xfce ibus exit

# Lock-on-suspend / idle-lock chain: xss-lock holds a logind inhibit lock and
# spawns i3lock with the inhibit FD passed through (--transfer-sleep-lock), so
# the kernel suspend only proceeds once i3lock has actually painted the lock
# window. Switched from xscreensaver on 2026-05-09 because xscreensaver-systemd
# only used a delay inhibitor and the lock window often was not in VRAM at
# suspend time, causing a desktop flash on resume.
# `xset s 600 0` makes the X server emit a screensaver event after 10 min idle,
# which xss-lock catches and turns into a lock.
xset s 600 0
xss-lock --transfer-sleep-lock -- i3lock --nofork --color=000000 &
# xssproxy claims org.freedesktop.ScreenSaver on the session bus and forwards
# Inhibit/UnInhibit calls to X11's screensaver-inhibit, so video apps (Zoom,
# Firefox, mpv, ...) can suppress the 10-min `xset s` idle lock during
# playback. Without it those calls have no provider and the screen would lock
# in the middle of a meeting. 2026-05-09.
xssproxy &

# Wait for reloading Awesome WM after this
#mate-keyboard-properties
#mate-appearance-properties
# Only the network config seems to work
# skip-in-xfce /usr/bin/cinnamon-control-center &

# Try GNOME controler to have online accounts working in nautilus
# skip-in-xfce XDG_CURRENT_DESKTOP=GNOME gnome-control-center &

#xfce4-keyboard-settings
# Cf /etc/default/keyboard instead
# From: keryell@fisel:~$ setxkbmap -query
# rules:      evdev
# model:      pc101
# layout:     us,fr
# variant:    ,
# options:    eurosign:e,eurosign:5,mod_led:compose,grp_led:scroll,lv3:ralt_switch,compose:rctrl
setxkbmap -rules evdev -model pc101 -layout us,fr -variant , -option eurosign:e -option eurosign:5 -option mod_led:compose -option grp_led:scroll -option lv3:ralt_switch -option compose:rctrl
# Configure keyboard repeat
xset r rate 300 40
# Configure the touchpad, for some reasons it is configured with FingerLow=24 FingerHigh=29 at boot time.
synclient ClickFinger2=2 ClickFinger3=3 FingerLow=0 FingerHigh=3 HorizEdgeScroll=1 HorizTwoFingerScroll=1 PalmDetect=1 TapButton2=2 TapButton3=3
# The following is not necessary actually.
# Actually it is required again since 2026/03/23.
# It looks like the FingerLow=0 FingerHigh=3 above to have the touchpad
# pressure-sensitive is not enough, coin it in another way:
xinput set-prop "VEN_27C6:00 27C6:0F60 Touchpad" "Synaptics Finger" 0 3 0

#mate-display-properties
skip-in-xfce nm-applet &

# Enable all the CPU because on my laptop sometimes is stuck with only 2 CPU and
# cpupower-gui breaks among other chaos.
# Single quotes so $i expands inside the inner shell, not the outer one.
skip-in-xfce bash -c 'for ((i = 0; i < 16; i++)); do echo 1 | sudo tee /sys/devices/system/cpu/cpu$i/online; done'

ALL_PROXY_BACKUP=$ALL_PROXY
skip-in-xfce unset all_proxy
skip-in-xfce unset ALL_PROXY

# emacs ~/Xilinx/Job/Temps/2016-temps.rst &

#VirtualBoxVM --normal --startvm Xilinx &
# Launch the AMD Windows VM
# https://forums.virtualbox.org/viewtopic.php?t=112770
#sudo rmmod kvm_amd kvm
#VirtualBoxVM --normal --startvm AMD &

# Some terminal
#x-terminal-emulator --title="T 1" &
#x-terminal-emulator --title="T 2" &
#x-terminal-emulator --title="T 3" &
#x-terminal-emulator --title="T 4" &
# Use another terminal model to use current environment variables
xfce4-terminal --title="T 1" &
sleep 2
xfce4-terminal --title="T 2" &
xfce4-terminal --title="T 3" &
xfce4-terminal --title="T 4" &

# Fix an address for the Windows VM to ssh back into Linux
#sudo ip address add 1.2.3.4/32 dev wlan0

/usr/bin/firefox &
#/snap/bin/firefox &

# Classic mail
thunderbird &

# Emacs for e-mail
emacs --iconic --execute '(setq frame-title-format "GNUS : %b <%f>")' &

# Very verbose
slack "${ELECTRON_AT_ARGS[@]}" &

# BlueTooth
skip-in-xfce blueman-applet &

# Sound control
skip-in-xfce pavucontrol &
# Mute the default output by default
pactl set-sink-mute @DEFAULT_SINK@ 1

# This is deprecated, now use the web application instead
#teams --proxy-server=socks://localhost:8081 &

zoom &

#mate-network-properties &
# A simple display size selector
arandr &
# Control the processor clock frequency.
# NO_AT_BRIDGE=1 prevents the GTK app, run as root, from spawning at-spi
# under /root/.cache/ and clobbering the X AT_SPI_BUS selection for the user.
skip-in-xfce sudo NO_AT_BRIDGE=1 cpupower-gui &

# Skip to debug AMD CPU power
#sudo powertop --auto-tune

# To try Teams. Cannot get the system proxy, so set it manually
#chromium --proxy-server=socks5://localhost:8081 &


#picom --daemon --backend glx --inactive-dim 0.1 --fading --inactive-opacity 0.8 --frame-opacity 0.8 --dbus
# --opacity-rule + --fade-exclude pin i3lock to 100% opacity and skip the
# fade-in animation, so the lock screen is fully painted the instant it
# appears (otherwise picom's --inactive-opacity 0.9 makes it semi-transparent
# and the fade defeats xss-lock's anti-flash handshake on resume). 2026-05-09.
picom --daemon --backend glx --fading --inactive-opacity 0.9 --fade-in-step=0.07 --fade-out-step=0.07 --dbus \
      --opacity-rule '100:class_g = "i3lock"' --fade-exclude 'class_g = "i3lock"'


# Discord
discord "${ELECTRON_AT_ARGS[@]}" &

# Nvidia VPN GUI
/opt/cisco/secureclient/bin/vpnui &

# Use the Dell laptop Copilot key as compose key since there is no RightControl:
xmodmap -e 'keycode 201 = Multi_key'

# Return immediately; backgrounded apps survive on their own. Used to be
# `wait; exit` for the manual-source flow under xfce4-session.
exit 0

# Since I use a SOCKS 5 proxy and email-oauth2-proxy does not
# understand it, use another proxy to do the conversion with an HTTP
# API, listenng on port 8080. Does not run it in the background since
# it displays statistics if -vv
# ~/Xilinx/Projects/System/venv/bin/pip install pproxy
#~/Xilinx/Projects/System/venv/bin/pproxy -l http://0.0.0.0:8080 -r socks5://127.0.0.1:8081 -vv
~/Xilinx/Projects/System/venv/bin/pproxy -l http://0.0.0.0:8080 -r socks5://127.0.0.1:8081

# The mail with Emacs requiring an authorizing proxy.
# skipping a WebKit bug in my environment:
#   EGLDisplay Initialization failed: EGL_BAD_ACCESS
#   Cannot create EGL sharing context: invalid display (last error: EGL_SUCCESS)
# Also loop since it fails for consecutive authentications. :-(
# Think about updating it from time to time and
# ~/Xilinx/Projects/System/venv/bin/pip install -r requirements-core.txt -r requirements-gui.txt
( set +e
  while true ; do
    http_proxy=http://localhost:8080 WEBKIT_DISABLE_COMPOSITING_MODE=1 \
      ~/Xilinx/Projects/System/venv/bin/python ~/Xilinx/Projects/System/email-oauth2-proxy/emailproxy.py --no-gui --external-auth
    sleep 1
  done)
