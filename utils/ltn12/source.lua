---LTN12 source utils.
--
--
--@module utils.ltn12.source

local checks = require 'checks'
local ltn12 = require 'ltn12'
local table = table

local M = {}

--------------------------------------------------------------------------------
--- Transforms a LTN12 source into a string.
-- @param src LTN12 source.
-- @return string. 
-- @function toString
--------------------------------------------------------------------------------
local function tostring(src)
    checks('function|table')
    local snk, dump = ltn12.sink.table()
    ltn12.pump.all(src, snk)
    return table.concat(dump)
end

--------------------------------------------------------------------------------
--- Returns a LTN12 source on table.
-- @param t the table, must be a list (indexed by integer).
-- @param empty optional boolean, true to remove the table's values.
-- @return LTN12 source function on the table.
-- @function table
--------------------------------------------------------------------------------
local function table(t, empty)
    checks('table', '?boolean')
    local index = 0  
    return function()
        index = index + 1
        local chunk = t[index] 
        if empty then t[index] = nil end
        return chunk
    end
end


M.tostring=tostring; M.toString=tostring
M.table=table

return M
