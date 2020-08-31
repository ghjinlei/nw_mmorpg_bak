--[[
ModuleName :
Path : import.lua
Author : jinlei
CreateTime : 2019-05-22 09:43:43
Description :
--]]

_G.__import_modules = _G.__import_modules or {}
local __import_modules = _G.__import_modules
_G.__module_list = _G.__module_list or {}
local __module_list = _G.__module_list

_G.setfenv = _G.setfenv or function(f, t)
	f = (type(f) == 'function' and f or debug.getinfo(f + 1, 'f').func)
	local name
	local up = 0
	repeat
		up = up + 1
		name = debug.getupvalue(f, up)
	until name == '_ENV' or name == nil
	if name then
		debug.setupvalue(f, up, t)
	end
	return f
end

local function loadluafile(relapath)
	return g_loadfile(relapath, nil)
end

local function call_module_init(module, updated)
	if rawget(module, "__init__") then
		xpcall(module.__init__, __G_TRACE_BACK__, module, updated)
	end
end

local function insert_var_with_warning(t, k, v)
	print("warning: insert global var %s to %s", k, tostring(t))
	rawset(t, k, v)
end

local function do_import(relapath, env)
	local old = __import_modules[relapath]
	if old then
		return old
	end

	local func, err = loadluafile(relapath)
	if not func then
		return nil, err
	end

	local new = {__is_module__ = true}
	__import_modules[relapath] = new
	table.insert(__module_list, new)

	setmetatable(new, {__index = _G})
	setfenv(func, new)()

	new_module.__import_time__ = os.time()

	call_module_init(new, false)

	return new
end

--[[ class更新逻辑: new_class->old_class
各变量处理:
	1.function : 直接用new_class的函数替换old_class
	2.table    : 深拷贝替换
	3.mt       : new_class下变量mt替换old_class下变量mt
	4.其他     : 保留旧值,视为静态变量,不能更新

变量类型不同的情况: 新值替换旧值
--]]
local class_ignore_map = {
	__subclass   = true,
	__superclass = true,
	__class_mt   = true,
}
local function update_class(old_class, new_class)
	local function deep_update(old_tbl, new_tbl, deep)
		if deep > 64 then
			return
		end

		for k, new_value in pairs(new_tbl) do
			if not class_ignore_map[k] then
				local old_value = rawget(old_class, k)
				if old_value then
					local old_type = type(old_value)
					local new_type = type(new_value)
					if new_type ~= old_type then
						old_class[k] = new_value
					elseif new_type == "function" then
						old_class[k] = new_value
					elseif new_type == "table" then
						if is_class(old_value) then
							old_class[k] = old_value
						else
							deep_update(old_value, new_value, deep + 1)
						end
					end
				else
					old_class[k] = new_value
				end
			end
		end
	end

	deep_update(old_class, new_class, 1)

	old_class:__update__()
end

local function do_update(relapath, data)
	local old_module = __import_modules[relapath]

	local func, err
	if data then
		func, err = loadstring(data)
	else
		func, err = loadluafile(relapath)
	end

	if not func then
		return nil, err
	end

	local mt = getmetatable(old_module)
	mt.__newindex = nil

	local oldcache = {}
	for k, v in pairs(old_module) do
		oldcache[k] = v
		old_module[k] = nil
	end

	local new_module = old_module
	setfenv(func, new_module)()

	for k, old_value in pairs(oldcache) do
		local new_value = new_module[k]
		local new_type = type(new_value)

		if new_type == "function" then
			new_module[k] = new_value
		elseif new_type == "table" then
			local old_type = type(old_value)
			if old_type == "table" then
				if is_class(old_value) then
					update_class(old_value, new_value)
				else
					local mt = getmetatable(new_value)
					if mt then
						setmetatable(old_value, mt)
					end
				end
			end
			new_module[k] = old_value
		else
			new_module[k] = old_value
		end
	end

	mt.__newindex = insert_var_with_warning

	new_module.__import_time__ = os.time()

	return new_module
end

function import(relapath, env)
	local module, err = do_import(relapath, env)
	assert(module, err)
	return module
end

local function try_clear_module(module)
	-- TODO: clear
	if TIMER then
		TIMER.table_remove_all_timers(module)
	end

	if EVENT then
		EVENT.remove_all_listeners(module)
	end
end

function reimport(relapath, data, env)
	local module, err, updated
	if __import_modules[relapath] then
		module, err = do_update(relapath, data)
		updated = true
	else
		module, err = do_import(relapath, env)
		updated = false
	end
	assert(module, err)

	if updated then
		try_clear_module(module)

		call_module_init(module, updated)

		if EVENT then
			EVENT.dispatch(nil, EVENT.EVENT_MODULE_UPDATED, relapath, module)
		end
	end
end

function unload(relapath)
	local module = __import_modules[relapath]
	if not module then
		return
	end

	try_clear_module(module)

	__import_modules[relapath] = nil
	for idx, m in ipairs(__module_list) do
		if m == module then
			table.remove(__module_list, idx)
			break
		end
	end
end

