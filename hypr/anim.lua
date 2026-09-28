-- Window open/close animation
-- https://wiki.hypr.land/Configuring/Animations/
--
-- Separate from look.lua so the open/close feel can be changed
-- without touching the rest of the theme. Switch with:
--
--     island-anim            show current preset and the options
--     island-anim subtle     switch, then reload
--
-- The one hard constraint: the window leaves accept only "slide"
-- or "popin". "fade" is rejected on them with "unknown style",
-- even though it is valid on layers/workspaces -- which is why
-- the fade lines in look.lua parse fine and these ones did not.
-- So there is no cross-fade to fall back on, and the choice is
-- really: how big a zoom, how fast, or nothing at all.
--
-- The percentage after "popin" is the size the window starts at,
-- as a fraction of its final size, and it scales about the centre
-- so nothing travels across the screen. Closer to 100% is a
-- smaller movement. "popin 100%" is effectively no zoom, which
-- leaves a fade-in of the window's own opacity.

local PRESET = "none"

-- The "official" preset is spring-driven rather than bezier, the
-- way Hyprland v0.56.2 ships it (example/hyprland.lua). Defining
-- the curve unconditionally keeps the rest of the table free of
-- "does this preset need it yet" conditionals.
hl.curve("easy", { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.21279333 })

local PRESETS = {
    -- Instant. Windows just appear.
    none = {
        windows    = { enabled = false },
        windowsIn  = { enabled = false },
        windowsOut = { enabled = false },
    },

    -- Barely there. Try this one first.
    flicker = {
        windows    = { enabled = true, speed = 10, bezier = "linear" },
        windowsIn  = { enabled = true, speed = 10, bezier = "linear", style = "popin 98%" },
        windowsOut = { enabled = true, speed = 12, bezier = "linear", style = "popin 98%" },
    },

    -- Small, quick zoom.
    subtle = {
        windows    = { enabled = true, speed = 7, bezier = "linear" },
        windowsIn  = { enabled = true, speed = 7, bezier = "linear", style = "popin 95%" },
        windowsOut = { enabled = true, speed = 9, bezier = "linear", style = "popin 95%" },
    },

    -- Noticeable but still in place.
    gentle = {
        windows    = { enabled = true, speed = 5, bezier = "linear" },
        windowsIn  = { enabled = true, speed = 5, bezier = "linear", style = "popin 90%" },
        windowsOut = { enabled = true, speed = 7, bezier = "linear", style = "popin 90%" },
    },

    -- Verbatim from Hyprland v0.56.2 example/hyprland.lua.
    -- Slower to open, and much slower to close (speed 1.49).
    official = {
        windows    = { enabled = true, speed = 4.79, spring = "easy" },
        windowsIn  = { enabled = true, speed = 4.1, spring = "easy", style = "popin 87%" },
        windowsOut = { enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" },
    },

    -- The original, kept so the difference is easy to feel.
    slide = {
        windows    = { enabled = true, speed = 4, bezier = "spring" },
        windowsIn  = { enabled = true, speed = 4, bezier = "spring", style = "slide" },
        windowsOut = { enabled = true, speed = 8, bezier = "closeOut", style = "slide" },
    },
}

local chosen = PRESETS[PRESET]

if not chosen then
    local names = {}
    for name in pairs(PRESETS) do
        names[#names + 1] = name
    end
    table.sort(names)
    error("anim: unknown preset '" .. PRESET .. "'; have: " .. table.concat(names, ", "))
end

for _, leaf in ipairs({ "windows", "windowsIn", "windowsOut" }) do
    local spec = chosen[leaf]
    spec.leaf = leaf
    hl.animation(spec)
end
