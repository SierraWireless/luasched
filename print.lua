
require 'utils.table' -- needed for table.pack. To be removed when we switch to Lua5.2

-- Make sure stdout is actually flushed every line
if io and io.stdout then
    io.stdout:setvbuf("line")
end

local function quotestring(x)
    local function q(k) return
        k=='"'  and '\\"'  or 
        k=='\\' and '\\\\' or 
        string.format('\\%03d', k :byte()) 
    end
    return '"' .. x :gsub ('[%z\1-\9\11\12\14-\31\128-\255"\\]', q) .. '"'
end

------------------------------------------------------------------------------
-- virtual printer: print a textual description of the objects in `...', using
-- function `write()' as a writer. By providing the appropriate writer, one
-- can make this function write on a TCP channel, in a string,... anywhere.
-- print_indent is the number of indentation characters used to render
-- tables. If nil/false, tables are rendered without carriage returns.
------------------------------------------------------------------------------
function vprint (write, print_indent, ...)
   local cache = { }
   local indent_level = 0
   local tinsert = table.insert
   local function aux(x)
      local  t=type(x)
      if     t=="string"  then write(quotestring(x))
      elseif t=="boolean" then write(x and "true" or "false")
      elseif t=="number"  then write(tostring(x))
      elseif t=="nil"     then write("nil")
      elseif t=="table"   then
         if cache[x] then write(tostring(table)) else
            cache[x] = true
            indent_level = indent_level+1

            -- get the list of keys
            local keys = {}
            for k, _ in pairs(x) do tinsert(keys, k) end
            local len = #keys

            if print_indent and len > 1 then
                write("{\r\n" .. string.rep(" ", print_indent * indent_level))
            else write "{ " end


            for i, k in ipairs(keys) do
               -- implicit array idx
               if k==i then -- do nothing...
               -- keyword key
               elseif type(k)=="string" and k:match"^[%a_][%w_]*$" then write(k .. " = ")
               -- generic key
               else write("["); aux(k); write("] = ") end
               aux(x[k])
               if i<len then
                  if print_indent then
                     write(",\r\n" .. string.rep(" ", print_indent * indent_level))
                  else write(", ") end
               end
            end
            write (" }")

            indent_level = indent_level-1
            cache[x] = nil
         end
      else write(tostring(x)) end
   end
   local args = table.pack(...)
   local nb = args.n
   for k = 1, nb do aux(args[k]); if k<nb then write "\t" end end
end

------------------------------------------------------------------------------
-- A more precise print (on stdout)
------------------------------------------------------------------------------
function p (...)
   local out = {}
   local function write(s)
      table.insert(out, s)
   end
   vprint(write, 3, ...)
   print(table.concat(out))
end

------------------------------------------------------------------------------
-- Build up and return a string instead of printing in some channel.
------------------------------------------------------------------------------
function siprint(indent, ...)
   local ins, acc = table.insert, { }
   vprint(function(x) return ins(acc, x) end, indent, ...)
   return table.concat(acc)
end

function sprint(...)
    return siprint(false, ...)
end