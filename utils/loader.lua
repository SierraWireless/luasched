--- Code loading/unloading utils
--
--
--@module utils.loader

local table = table
local load = load
local type= type
local _G = _G

local M={}
--------------------------------------------------------------------------------
--- Compiles a buffer (i.e. a list of strings) into an executable function.
-- As opposed to [loadstring](http://www.lua.org/manual/5.1/manual.html#pdf-loadstring) 
-- it does not require allocating a single string for
-- the whole source, thereby saving on memory load. Moreover, if the
-- last argument is true, the buffer is emptied as it is read, thus saving even
-- more memory (but destroying the buffer).
-- @param buffer a list of strings.
-- @param name is an optional chunk name used for debug traces.
-- @param destroy is a boolean. When true, the buffer is read destructively (saves RAM when handling big sources).
-- @return function resulting of the buffer compilation
-- @function loadBuffer
--------------------------------------------------------------------------------
function loadbuffer (buffer, name, destroy)
    local remove = table.remove
    local function dest_reader() return remove (buffer, 1) end
    local i = 0
    local function keep_reader() i=i+1; return buffer[i] end
    return load (destroy and dest_reader or keep_reader, name)
end

--------------------------------------------------------------------------------
--- Unloads a module by removing references to it.
-- Here is the sequence of operations made by this function:
--
-- 1. Call package.loaded[name].__unload() if existing
-- 1. Clear: package.loaded[name]
-- 1. Clear: _G[name]
-- @param name the name of the module to unload.
--------------------------------------------------------------------------------
function unload(name)
    local l = _G.package.loaded
    local p = l[name]
    local u = type(p) == 'table' and p.__unload
    if u then u() end
    l[name] = nil
    _G.rawset(_G, name, nil)
end

M.unload=unload; 
M.loadbuffer=loadbuffer;M.loadBuffer=loadbuffer
return M
