-- This file was automatically generated for the LuaDist project.

package = "web_sanitize"
version = "0.2.0-1"

-- LuaDist source
source = {
  tag = "0.2.0-1",
  url = "git://github.com/LuaDist-testing/web_sanitize.git"
}
-- Original source
-- source = {
--   url = "git://github.com/leafo/web_sanitize.git",
--   branch = "v0.0.1",
-- }

description = {
  summary = "Lua library for sanitizing untrusted HTML",
  license = "MIT",
  maintainer = "Leaf Corcoran <leafot@gmail.com>",
  homepage = "https://github.com/leafo/web_sanitize",
}

dependencies = {
  "lua >= 5.1",
  "lpeg"
}

build = {
  type = "builtin",
  modules = {
    ["web_sanitize"] = "web_sanitize/init.lua",
    ["web_sanitize.css"] = "web_sanitize/css.lua",
    ["web_sanitize.whitelist"] = "web_sanitize/whitelist.lua",
  }
}