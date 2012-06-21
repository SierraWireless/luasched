-- Fetching script: copy all files necessary for the MIT Linux release
-- of the scheduler.

-- The `root` variable points to the Lua framework's root directory.
root = ... or "../luafwk"

-- List of file copies to perform:
--
-- * ">" lines introduce a new target directory;
--   paths are relative to the current working directory.
--
-- * "-" lines list files to copy in the latest target directory;
--   paths are relative to `root`.
--
script = [[

>.

-/common/misc/coxpcall.lua
-/common/misc/print.lua
-/common/misc/strict.lua
-/common/luasocket/common/ltn12.lua
-/common/luasocket/common/mime.lua
-/common/luasocket/common/socket.lua

>utils
-/common/utils/loader.lua
-/common/utils/path.lua
-/common/utils/table.lua

>utils/ltn12
-/common/utils/ltn12/source.lua

>c

-/common/checks/checks.c
-/common/checks/checks.h

-/common/lpack/lpack.c
-/common/lpack/lpack.h

-/linux/liblua/mem_define.h

-/common/luasocket/common/mime/mime.c
-/common/luasocket/common/mime/mime.h

-/common/sched/linux/sched/posixsignal/lposixsignal.h
-/common/sched/linux/sched/posixsignal/lposixsignal.c

-/common/luatobin/luatobin.c
-/../libs/c/common/awt_endian.c
-/../libs/c/common/awt_endian.h

>log

-/common/log/common/log/init.lua
-/common/log/common/log/tcp.lua
-/common/log/common/log/tools.lua

>c/log

-/common/log/common/log_store.h
-/common/log/common/log_store.c
-/common/log/common/log_storeflash.h
-/common/log/linux/log_storeflash.c

>sched

-/common/sched/common/sched/timer.lua
-/common/sched/common/sched/init.lua
-/common/sched/linux/sched/fd.lua
-/common/sched/linux/sched/platform.lua
-/common/misc/pipe.lua
-/common/misc/lock.lua

>rpc

-/common/rpc/init.lua
-/common/rpc/common.lua
-/common/rpc/sched.lua
-/common/rpc/nosched.lua
-/common/rpc/proxy.lua
-/common/rpc/builtinsignatures.lua

>shell

-/common/shell/common/shell/telnet.lua

>c/socket

-/common/luasocket/linux/socket.h

-/common/luasocket/linux/auxiliar.h
-/common/luasocket/linux/buffer.h
-/common/luasocket/linux/except.h
-/common/luasocket/linux/inet.h
-/common/luasocket/linux/io.h
-/common/luasocket/linux/luasocket.h
-/common/luasocket/linux/options.h
-/common/luasocket/linux/select.h
-/common/luasocket/linux/tcp.h
-/common/luasocket/linux/timeout.h
-/common/luasocket/linux/udp.h
-/common/luasocket/linux/unix.h
-/common/luasocket/linux/usocket.h

-/common/luasocket/linux/auxiliar.c
-/common/luasocket/linux/buffer.c
-/common/luasocket/linux/except.c
-/common/luasocket/linux/inet.c
-/common/luasocket/linux/io.c
-/common/luasocket/linux/luasocket.c
-/common/luasocket/linux/options.c
-/common/luasocket/linux/select.c
-/common/luasocket/linux/tcp.c
-/common/luasocket/linux/timeout.c
-/common/luasocket/linux/udp.c
-/common/luasocket/linux/unix.c
-/common/luasocket/linux/usocket.c

>socket

-/common/luasocket/common/socket/ftp.lua
-/common/luasocket/common/socket/http.lua
-/common/luasocket/common/socket/smtp.lua
-/common/luasocket/common/socket/tp.lua
-/common/luasocket/common/socket/url.lua

-/common/luasocket/linux/socket/platform.lua

>c/telnet

-/common/shell/common/telnet/actions.h
-/common/shell/common/telnet/buffers.h
-/common/shell/common/telnet/editor.h
-/common/shell/common/telnet/history.h
-/common/shell/common/telnet/teel.h
-/common/shell/common/telnet/telnet.h
-/common/shell/common/telnet/teel_internal.h

-/common/shell/common/telnet/actions.c
-/common/shell/common/telnet/buffers.c
-/common/shell/common/telnet/editor.c
-/common/shell/common/telnet/history.c
-/common/shell/common/telnet/teel.c
-/common/shell/common/telnet/telnet.c

>doc
-/../doc/ldoc/ldoc.css
-/../doc/ldoc/ldoc.ltp

]]

-- Interpret the script string:
-- create the necessary directories and perform file copies.
-- Actual operations are performed through `os.execute`,
-- and any execution error will halt the Lua script.
--
function process_script(script)
    local target
    for op, arg in script :gmatch "([^\r\n])([^\r\n]*)" do
        local cmd
        if op==">" then
            target = arg
            cmd = "mkdir -p "..target
        elseif op=="-" then
            local src, tgt = root..arg, target .. "/" .. arg :match "[^/]+$"
            --cmd = "if [ "..src.." -nt "..tgt.." ]; then echo 'update "..tgt.."'; cp "..src.." "..tgt.."; fi"
            cmd = "cp "..root..arg.." "..target.."/"
        elseif op=="#" then
            -- pass the comment
        else 
            error "Invalid script"
        end
        --print (cmd)
        assert(0==os.execute(cmd))
    end
end

process_script(script)