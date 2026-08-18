-- Input Configuration
-- Keyboard, mouse, and touchpad settings

hl.config({
    input = {
        kb_layout  = "gb", -- UK keyboard layout
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        follow_mouse = 1,

        sensitivity = 0, -- -1.0 - 1.0, 0 means no modification

        touchpad = {
            natural_scroll       = true,
            disable_while_typing = true,
            -- hyprlang spelled this `tap-to-click`; the Lua API uses `tap_to_click`
            tap_to_click = true,
        },

        -- Repeat rate (keyboard repeat speed)
        repeat_rate  = 25,
        repeat_delay = 600,
    },
})

-- XWayland settings
-- NOTE: XKEYBOARD warnings about "unsupported real modifier keysym" and
-- "multiply defined virtual modifier" are harmless - they indicate X11
-- keymap features that don't have direct Wayland equivalents.
hl.config({
    xwayland = {
        force_zero_scaling = true, -- Prevents scaling issues with XWayland apps
    },
})
