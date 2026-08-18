-- Animation Configuration
-- Animation curves and settings
--
-- In hyprlang the `bezier`/`animation` lines lived inside the `animations {}`
-- block. Under the Lua provider only `animations.enabled` is a config value;
-- curves are declared with hl.curve() and leaves with hl.animation().

hl.config({
    animations = {
        enabled = true,
    },
})

-- bezier = myBezier, 0.05, 0.9, 0.1, 1.05
hl.curve("myBezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })

hl.animation({ leaf = "windows",     enabled = true, speed = 7,  bezier = "myBezier" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 7,  bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "border",      enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 8,  bezier = "default" })
hl.animation({ leaf = "fade",        enabled = true, speed = 7,  bezier = "default" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 6,  bezier = "default" })
