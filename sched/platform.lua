require 'sched.timer'
require 'sched.fd'
require 'print'
require 'pack'
require 'log'
require 'utils.table' -- used at least for table.pack

local os_time = os.time
------------------------------------------------------------------------------
--
------------------------------------------------------------------------------
local loop_state = 'stopped' -- stopped, running or stopping

function sched.stop()
   if loop_state=='running' then loop_state = 'stopping' end
end

function sched.loop ()
    loop_state = 'running'

    local timer_nextevent, timer_step, sched_step, fd_step = 
        sched.timer.nextevent, sched.timer.step, sched.step, sched.fd.step

    while loop_state=='running' do
        
        timer_step() -- Reschedule tasks and trigger hooks which wait for a timer        
        sched_step() -- Run all the tasks ready to run

        -- Find out when the next timer event is due
        local timeout = nil
        do
            local date = timer_nextevent()
            if date then
                local now=os_time()
                timeout = date<now and 0 or date-now 
            end
        end

        fd_step (timeout) -- Wait for FD events until next timer is due
    end
end

------------------------------------------------------------------------------
--
------------------------------------------------------------------------------
function sched.listen(port)
    if sched.luasignal_server then return end

    local socket = require 'socket'
    port = port or 18888

    local function evh (skt)
        -- started a new signal listener
        local queue
        local function sendsignals()
            while #queue > 0 do
                local t = table.remove(queue, 1)
                for k = 1, t.n do
                    t[k] = string.pack(">P", tostring(t[k])) 
                end
                t = table.concat(t)
                assert(skt:send(string.pack(">P", t)))
            end
            queue = nil
        end

        local function enqueue(...)
            local t = table.pack(...)
            if not queue then queue = {t} sched.run(sendsignals)
            else table.insert(queue, t) end
            return "again"
        end

        local hooks = {}
        local function reader()

            -- Read a string from the connected socket.
            local function readentry(skt)
                   local size, _ = assert(skt:receive(2))
                _, size = size:unpack(">H")
                return assert(skt:receive(size))
            end

            -- Get the name of the emitter to receive message from !
            local names, offset = readentry(skt)
            while true do
                local n
                offset, n = names:unpack(">P", offset)
                if not n then break end
                table.insert(hooks, sched.sighook(n, "*",
                     function (...) return enqueue(n, ...) end))
            end

            -- Waits for incoming signals
            while true do
                local entry = readentry(skt)
                local offset, emitter, event = entry:unpack(">PP")
                local args = {}
                local a = true
                while a do
                    offset, a = entry:unpack(">P", offset)
                    table.insert(args, a)
                end
                if emitter and event then -- protect against malformed events
                    sched.signal(emitter, event, unpack(args))
                end
            end
            return "ok"
        end

        local s, err = socket.protect(reader)()
        if not s then
            log('SCHED', 'ERROR', "Error while reading from listener socket: %s",
                tostring(err))
        end

        -- Remove all hooks
        for _, h in ipairs(hooks) do sched.kill(h) end
    end

    sched.luasignal_server = assert(socket.bind("localhost", port, evh))
    sched.LUASIGNAL_LISTEN_PORT = port -- the port is saved so that other modules can know which port to use.
end

return sched
