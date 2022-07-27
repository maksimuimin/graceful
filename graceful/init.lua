require('strict').on()

local checks	= require('checks')
local log		= require('log')

--------------------------
--- Internal functions ---
--------------------------

-- PTAL: http://lua-users.org/wiki/CopyTable
local function deepcopy(orig)
	local copies = {}
	local orig_type = type(orig)
	local copy
	if orig_type == 'table' then
		if copies[orig] then
			copy = copies[orig]
		else
			copy = {}
			copies[orig] = copy
			for orig_key, orig_value in next, orig, nil do
				copy[deepcopy(orig_key, copies)] = deepcopy(orig_value, copies)
			end
			setmetatable(copy, deepcopy(getmetatable(orig), copies))
		end
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end

--------------------
--- Global stash ---
--------------------

local stash_layout = {
	modules	= {},
}

local function stash_reset()
	local new_stash = deepcopy(stash_layout)
	rawset(_G, '__GRACEFUL_STASH__', new_stash)
	return new_stash
end

local function stash_get_full()
	local stash = rawget(_G, '__GRACEFUL_STASH__')
	if not stash then
		stash = stash_reset()
	end

	return stash
end

local function stash_get(key)
	checks('string')

	local stash = stash_get_full()
	return stash[key]
end

local function stash_set(key, value)
	checks('string')

	local stash = stash_get_full()
	stash[key] = value
	rawset(_G, '__GRACEFUL_STASH__', stash)
end

local function stash_upgrade(old_stash)
	checks('?table')

	stash_reset()

	if not old_stash then
		return
	end

	if old_stash.modules then
		stash_set('modules', old_stash.modules)
	end
end

---------------------
--- Module object ---
---------------------

local function module_find(name)
	checks('string')
	return stash_get('modules')[name]
end

local function module_stash(mod)
	checks('graceful_module')

	local modules = stash_get('modules')
	if modules[mod.name] then
		return error('module is already in stash')
	end

	modules[mod.name] = mod
	stash_set('modules', modules)
end

local function module_unstash(mod)
	checks('graceful_module')

	local modules = stash_get('modules')
	if not modules[mod.name] then
		return error('module is already not in stash')
	end

	modules[mod.name] = nil
	stash_set('modules', modules)
end

local function module_reload(mod)
	checks('graceful_module')

	local old_version = mod.version

	if mod.before_reload then
		mod:before_reload()
	end

	package.loaded[mod.name] = nil
	require(mod.name)

	if mod.on_reload then
		mod:on_reload()
	end

	log.info('graceful: module \"%s\" is reloaded: %s => %s', mod.name, tostring(old_version),
			 tostring(mod.version))
end

local function module_new(name, version, init, finalize, before_reload, on_reload)
	checks('string', '?string|table', '?function', '?function')

	local mod = {
		name			= name,
		version			= version,
		init			= init,
		finalize		= finalize,
		before_reload	= before_reload,
		on_reload		= on_reload,
		state			= {},
		reload			= module_reload,
	}

	mod = setmetatable(mod, {
		__type	= 'graceful_module',
	})

	return mod
end

-----------
--- API ---
-----------

local function semver(maj, min, patch)
	checks('number', 'number', 'number')

	local v = {
		maj		= maj,
		min		= min,
		patch	= patch,
		string	= function (self)
			return string.format('%d.%d.%d', maj, min, patch)
		end,
	}

	v = setmetatable(v, {
		__tostring	= function (self)
			return self:string()
		end,
	})

	return v
end

local function register_module(name, opts)
	checks('string', {
		version			= '?string|table',
		init			= '?function',
		finalize		= '?function',
		before_reload	= '?function',
		on_reload		= '?function',
	})

	local mod = module_find(name)
	if mod then
		mod.version = opts.version
		mod.init = init
		mod.finalize = finalize
		mod.before_reload = opts.before_reload
		mod.on_reload = opts.on_reload
		mod.reload = module_reload -- In case of method implementation changes
	else
		mod = module_new(name, opts.version, opts.init, opts.finalize, opts.before_reload,
						 opts.on_reload)
		module_stash(mod)

		if mod.init then
			mod:init()
		end

		log.info('graceful: module \"%s\" is registered', mod.name)
	end

	return mod
end

local function unregister_module(name)
	local mod = module_find(name)
	if not mod then
		return error('module not found')
	end

	module_unstash(mod)

	if mod.finalize then
		mod:finalize()
	end

	log.info('graceful: module \"%s\" is unregistered', mod.name)
end

local function reload()
	local modules = stash_get('modules')
	for _, mod in pairs(modules) do
		mod:reload()
	end
end

local function shutdown()
	local modules = stash_get('modules')
	for _, mod in pairs(modules) do
		if mod.finalize then
			-- This func is called in trigger, triggers must not throw
			local ok, err = pcall(mod.finalize, mod)
			if not ok then
				log.error('graceful: module \"%s\" finalization failed: %s', mod.name, err)
			end
		end
	end
end

----------------------------------------------
--- Register graceful module for reloading ---
----------------------------------------------

register_module('graceful', {
	version			= semver(1, 0, 0),
	init			= function (mod)
		checks('graceful_module')
		box.ctl.on_shutdown(shutdown)
	end,
	before_reload	= function (mod)
		checks('graceful_module')
		mod.state.old_stash = stash_get_full()
		stash_reset()
	end,
	on_reload		= function (mod)
		checks('graceful_module')
		local old_stash = mod.state.old_stash or stash_get_full()
		stash_upgrade(old_stash)
		mod.state = {} -- Clean up the old stash
	end,
})

return {
	semver				= semver,
	register_module		= register_module,
	unregister_module	= unregister_module,
	reload				= reload
}
