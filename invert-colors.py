#!/usr/bin/env python3
"""Toggle a colour negative on every connected output.

Complements the gamma ramps (value -> 65535 - value) of each RandR CRTC that
currently drives an output, so running it again restores the previous ramps.
Working per CRTC is what makes it cover all outputs of the screen.
"""
from Xlib import display
from Xlib.ext import randr


def toggle(d):
    """Complement the gamma ramps of every active CRTC of the default screen.

    Returns the CRTC ids that were changed.
    """
    root = d.screen().root
    res = root.xrandr_get_screen_resources_current()
    changed = []
    for crtc in res.crtcs:
        info = randr.get_crtc_info(d, crtc, res.config_timestamp)
        if info.mode == 0:  # not driving any output
            continue
        gamma = randr.get_crtc_gamma(d, crtc)
        size = len(gamma.red)
        if size == 0:  # no gamma support on this CRTC
            continue
        red, green, blue = ([65535 - v for v in ramp]
                            for ramp in (gamma.red, gamma.green, gamma.blue))
        randr.set_crtc_gamma(d, crtc, size, red, green, blue)
        changed.append(crtc)
    d.sync()
    return changed


if __name__ == "__main__":
    toggle(display.Display())
