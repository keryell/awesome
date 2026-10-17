-- A menu taller than the screen scrolls instead of extending past its edge.

local runner = require("_runner")
local awful = require("awful")
local beautiful = require("beautiful")

local item_height = beautiful.menu_height or 16
local workarea = screen[1].workarea
-- Several screens' worth of entries, one of them opening a sub-menu.
local count = math.floor(workarea.height / item_height) * 3
local sub = math.floor(count * 2 / 3)
local items = {}
for i = 1, count do
    items[i] = { "entry " .. i, function() end }
end
items[sub] = { "sub-menu", { { "a", function() end }, { "b", function() end } } }
local big = awful.menu({ items = items, theme = { height = item_height } })
local small = awful.menu({ items = { items[1], items[2], items[3] },
                           theme = { height = item_height } })

local function press(m, key)
    m._keygrabber({}, key, "press")
end

runner.run_steps {
    function()
        big:show({ coords = { x = workarea.x, y = workarea.y } })
        assert(big.wibox.visible)
        assert(big.wibox.height <= workarea.height,
               "menu height " .. big.wibox.height .. " exceeds workarea " .. workarea.height)
        assert(big.wibox.y >= workarea.y, "menu placed above the workarea")
        assert(big._scrolling, "menu does not scroll")
        assert(big._scroll_offset == 0, "offset " .. big._scroll_offset)
        assert(big._scroll_visible < count, "all entries displayed")
        return true
    end,
    function()
        -- Keyboard selection past the visible range scrolls.
        local visible = big._scroll_visible
        big:item_enter(visible + 1)
        assert(big._scroll_offset == 1, "offset " .. big._scroll_offset)
        -- Wrapping to the last entry shows the end...
        big:item_enter(count)
        assert(big._scroll_offset + big._scroll_visible == count,
               "last entry not displayed")
        -- ...and wrapping to the first entry shows the start.
        big:item_enter(1)
        assert(big._scroll_offset == 0, "offset " .. big._scroll_offset)
        return true
    end,
    function()
        -- Page keys move the selection by one window of entries.
        big:item_enter(5)
        local visible = big._scroll_visible
        press(big, "Next")
        assert(big.sel == 5 + visible, "selection " .. tostring(big.sel))
        press(big, "Prior")
        assert(big.sel == 5, "selection " .. tostring(big.sel))
        return true
    end,
    function()
        -- A sub-menu of a scrolled parent opens on the row of its entry.
        big:item_enter(sub)
        big:scroll(math.floor(big._scroll_visible / 2))
        big:exec(sub)
        local child = big.active_child
        assert(child and child.wibox.visible, "sub-menu not shown")
        local expected = big.wibox.y + item_height * (sub - big._scroll_offset)
        assert(child.wibox.y == expected,
               "sub-menu at y=" .. child.wibox.y .. ", entry row at y=" .. expected)
        -- Scrolling moves the entry away, so the sub-menu closes.
        big:scroll(3)
        assert(big.active_child == nil, "sub-menu still open after scrolling")
        return true
    end,
    function()
        -- scroll() clamps at both ends, hide() rewinds.
        big:scroll(-1000)
        assert(big._scroll_offset == 0, "offset " .. big._scroll_offset)
        big:scroll(10 * count)
        assert(big._scroll_offset + big._scroll_visible == count,
               "last entry not displayed")
        big:hide()
        assert(big._scroll_offset == 0, "offset " .. big._scroll_offset)
        return true
    end,
    function()
        -- A menu that fits keeps its full height and ignores scroll().
        small:show({ coords = { x = workarea.x, y = workarea.y } })
        assert(not small._scrolling, "small menu scrolls")
        assert(small.wibox.height == 3 * item_height,
               "height " .. small.wibox.height)
        small:scroll(1)
        assert(small._scroll_offset == 0, "offset " .. small._scroll_offset)
        small:hide()
        return true
    end,
}
