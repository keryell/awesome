set -vx

skip-in-xfce() {
  if [ "$XDG_SESSION_DESKTOP" != "xfce-awesome" ]; then
    "$@"
  fi
}

# The typical things loaded in a Xilinx session for Ronan Keryell

RK_TERMINAL=
skip-in-xfce eval `ssh-agent -s`
ssh-add

# This seems to break ibus: XMODIFIERS=@im=ibus
skip-in-xfce unset XMODIFIERS
skip-in-xfce ibus exit

# For some reasons there is already a screensaver
#killall mate-screensaver
# Wait for reloading Awesome WM after this
#mate-keyboard-properties
#mate-appearance-properties
# Only the network config seems to work
skip-in-xfce /usr/bin/cinnamon-control-center &

# Try GNOME controler to have online accounts working in nautilus
skip-in-xfce XDG_CURRENT_DESKTOP=GNOME gnome-control-center &

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
# It looks like the FingerLow=0 FingerHigh=3 above to have the touchpad
# pressure-sensitive is not enough, coin it in another way:
# xinput set-prop "VEN_27C6:00 27C6:0F60 Touchpad" "Synaptics Finger" 0 3 0

#mate-display-properties
skip-in-xfce nm-applet &

# Enable all the CPU because on my laptop sometimes is stuck with only 2 CPU and
# cpupower-gui breaks among other chaos
skip-in-xfce bash -c "for ((i = 0; $i < 16; i++)); do echo 1 | sudo tee /sys/devices/system/cpu/cpu$i/online; done"

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
skip-in-xfce gnome-terminal --title="T 1" &
skip-in-xfce sleep 2
skip-in-xfce gnome-terminal --title="T 2" &
skip-in-xfce gnome-terminal --title="T 3" &
skip-in-xfce gnome-terminal --title="T 4" &

# Fix an address for the Windows VM to ssh back into Linux
#sudo ip address add 1.2.3.4/32 dev wlan0

/usr/bin/firefox &
#/snap/bin/firefox &

# Classic mail
#thunderbird &

# Emacs for e-mail
emacs --iconic --execute '(setq frame-title-format "GNUS : %b <%f>")' &

# Very verbose
slack &

# BlueTooth
skip-in-xfce blueman-applet &
# Sound control
skip-in-xfce pavucontrol &
# Mute the default output by default
skip-in-xfce pactl set-sink-mute @DEFAULT_SINK@ 1

# This is deprecated, now use the web application instead
#teams --proxy-server=socks://localhost:8081 &

zoom &

#mate-network-properties &
# A simple display size selector
skip-in-xfce arandr &
# Control the processor clock frequency
skip-in-xfce sudo cpupower-gui &

# Skip to debug AMD CPU power
#sudo powertop --auto-tune

# To try Teams. Cannot get the system proxy, so set it manually
#chromium --proxy-server=socks5://localhost:8081 &

# Here mate-screensaver is probably no longer working
xscreensaver &

#picom --daemon --backend glx --inactive-dim 0.1 --fading --inactive-opacity 0.8 --frame-opacity 0.8 --dbus
picom --daemon --backend glx --fading --inactive-opacity 0.9 --fade-in-step=0.07 --fade-out-step=0.07 --dbus


# Discord
discord &

# Relaunch NTP because of Windows messing up with time
sudo /etc/init.d/ntpsec restart &

exit

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
