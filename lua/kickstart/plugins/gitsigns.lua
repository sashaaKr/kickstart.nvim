-- Intentionally empty.
--
-- `init.lua` still has `require 'kickstart.plugins.gitsigns'` in its plugin
-- list, so this module has to exist and return a valid (possibly empty) lazy
-- spec. Its original contents — the recommended gitsigns hunk keymaps — now
-- live in `lua/custom/plugins/git.lua` with every other git setting, so that
-- there is exactly one file to open when you want to change anything git.
--
-- Deleting this file means also deleting that `require` line from `init.lua`.

return {}
