--[[
ModuleName :
Path : preload.lua
Author : jinlei
CreateTime : 2019-05-21 14:16:12
Description :
--]]
local skynet_helper = require "common.utils.skynet_helper"

__G_TRACE_BACK__ = skynet_helper.traceback

local __LUA_SERACH_PATH__ = "./script"
function g_loadfile(relapath, env)
	return loadfile(__LUA_SERACH_PATH__ .. "/" .. relapath, "bt", env)
end

function g_dofile(relapath)
	local m = nil
	xpcall(function()
		local func, err = assert(GLoadFile(relapath, _G))
		m = func()
	end, __G_TRACE_BACK__)
	return m
end

local function load_globalfilelist()
	local globalfilelist = {
		"common/base/macro.lua",
		"lualib/common/base/macro.lua",
		"lualib/common/base/global.lua",
		"common/base/import.lua",
		"common/base/class.lua",
		"common/base/extend.lua",
	}

	for _, filepath in ipairs(globalfilelist) do
		g_dofile(filepath)
	end
end

load_globalfilelist()

TIME          = import("common/module/time.lua")
IMPL_TIMER    = import("lualib/common/module/impl_timer.lua")
TIMER         = import("common/module/timer.lua")
EVENT         = import("common/module/event.lua")
HEAP          = import("common/module/heap.lua")
