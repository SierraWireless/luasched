--------------------------------------------------------------------------------
-- Task scheduler.
-- Copyright SierraWireless (c) 2007-2011                   
-- @module sched                                            
--------------------------------------------------------------------------------

require 'log'
require 'checks'

local sched = { }; _G.sched = sched

require 'sched.timer'

--
-- if true, scheduling functions are stored in the global environment as well
--  as in table 'sched'. For instance, signal is accessible both as
--  signal() and as sched.signal().
--
local UNPACK_SCHED = true

--
-- When this magic token is passed to a resumed task, it's expected to
--  kill itself with an [error "KILL"].
--  Used by [kill] to order suicide, and [wait] to execute it.
--
local KILL_TOKEN = setmetatable({ "<KILL-TOKEN>" }, 
    { __tostring = function() return "Killed thread" end})

--
-- Set to true when parts of `proc' need to be cleaned up by a gc()
--
local CLEANUP_REQUIRED = false

-- This table keeps the state of the scheduler and its threads.
__tasks       = { }
if   rawget(_G, 'proc') then proc.tasks=__tasks
else rawset(_G, 'proc', { tasks=__tasks}) end

------------------------------------------------------------------------------
--- List of tasks ready to be rescheduled.   
--  The first task in the list will be rescheduled first by the next non-nested
--  call to @{sched.run}(). Tasks can be represented:
--
--  * as functions or threads if it is the first time they will be scheduled
--  * as a 2 elements list, thread and args list if rescheduled by a signal.
--
--  Hooks are never listed as ready: they are executed within @{sched.signal}().
------------------------------------------------------------------------------
__tasks.ready = { }

------------------------------------------------------------------------------
--- True when a signal is being processed.   
--  Prevents a garbage collector from removing a list of registered cells which
--  are currently being processed.
------------------------------------------------------------------------------
__tasks.hold  = false

------------------------------------------------------------------------------
-- Table of tasks and hooks waiting for signals.  
--  Keys are potential signal emitters; values are sub-tables where keys are
--  event names and values are cell lists.
--  A cell holds either a paused task or a hook.
--
--  Hooks have a field 'hook' containing the synchronous hook function.
--
--  Tasks have a field 'thread' containing the paused coroutine. They have
--  another field 'multiwait' set to 'true' if the cell is registered to more
--  than one event (can only be set by @{sched.multiwait}()).
--
--  Both cell types have a field 'multi' set to 'true' if they are registered
--  to more than one event (including event wildcard '\*' and timeout callbacks).
--  Both cell types can have an 'xtrargs' list of parameters which will be
--  passed as extra hook parameters just after the triggering event.
--
--  The table is weak in its key, so that it will not prevent the garbage collection
--  of an emitter.
-- @table __tasks.waiting
------------------------------------------------------------------------------
__tasks.waiting = setmetatable({ }, {__mode='k'})

------------------------------------------------------------------------------
--  Hold the coroutine which is currently running or [nil] if no task
--  is currently running.
--  
------------------------------------------------------------------------------
__tasks.running = nil

local getinfo=debug.getinfo
local function iscfunction(f) return getinfo(f).what=='C' end

------------------------------------------------------------------------------
-- Runs a function as a new thread.  
-- sched.run(f[, args...]), runs f(args...) as a new thread.  
-- sched.run(t), with t a task presumably removed from __tasks.waiting[x][y],
-- reschedules the task in @{__tasks.ready}.
-- @param f function or task to run 
-- @param ... optional arguments to pass to param f
-- @return new thread created to run the function/task
------------------------------------------------------------------------------
function sched.run (f, ...)
    checks ('function')
    local ready = __tasks.ready

    if iscfunction(f) then local cf=f; f=function(...) return cf(...) end end

    local thread = coroutine.create (f)
    local cell   = { thread, ... }
    table.insert (ready, cell)
    log.trace ('sched', 'DEBUG', "RUN %s", tostring (thread))

    return thread
end

------------------------------------------------------------------------------
-- Runs all the tasks which are ready to run, until there are no tasks
-- left which are waiting for something 
-- (i.e. __tasks.ready is empty).
------------------------------------------------------------------------------
function sched.step()
    local ptr = __tasks.ready

    -- If scheduling already runs, don't relaunch it
    if __tasks.running or __tasks.hook then return nil, 'already running' end

    --------------------------------------------------------------------
    -- 2 - If there are no task currently running, resume scheduling by
    --     going through [__tasks.ready] until it's empty.
    --------------------------------------------------------------------
    while true do
        local cell = table.remove (ptr, 1)
        if not cell then break end
        local thread = cell[1]
        __tasks.running = thread
        local success, msg = coroutine.resume (unpack (cell))
        if not success and msg ~= KILL_TOKEN then 
            -- report the error msg
            print ("In " .. tostring(thread)..": error: " .. tostring(msg))
            print (debug.traceback(thread))
        end
        ---------------------------------------------
        -- If the coroutine died, signal it for those
        -- who synchronize on its termination.
        ---------------------------------------------
        if coroutine.status (thread) == "dead" then 
            sched.signal (thread, "die", success, msg)
        end
    end

    __tasks.running = nil

    -- IMPROVE: a better test for idleness is required: maybe there are
    -- TCP data coming at a fast pace, for instance. Putting the cleanup
    -- in a timer, so that it's triggered after a couple seconds of idleness,
    -- would be better.
    if CLEANUP_REQUIRED then sched.gc(); CLEANUP_REQUIRED = false end
end

------------------------------------------------------------------------------
-- Run a cell:
--  * if it has been emptied, leave it alone
--  * if it is a task, insert the list of appropriate run() args in wokenup_tasks
--  * if it is a hook, run it immediately. If it must be reattached and there is
--    a new_queue list, insert it there.
-- If wokenup_tasks isn't provided, insert tasks in __tasks.ready instead.
------------------------------------------------------------------------------
local function runcell(c, emitter, event, args, wokenup_tasks, new_queue)
    local nargs  = args.n
    if c.xtrargs then
        -- before: args = {ev, a2, a3}, args2={b1, b2, b3}
        -- after:  args = {ev, b1, b2, b3, a2, a3}
        local nxtrargs = c.xtrargs.n
        local newargs = { args[1], unpack(c.xtrargs, 1, nxtrargs) }
        for i=2,nargs do newargs[i+nxtrargs] = args[i] end 
        args = newargs
        nargs = nargs + nxtrargs
    end

    if c.multi then CLEANUP_REQUIRED = true end -- remember to clean ptw
    
    local thread = c.thread
    if thread then -- coroutine to reschedule
        local newcell = 
            c.multiwait and { thread, emitter, unpack(args, 1, nargs) } or 
            { thread, unpack(args, 1, nargs) }
        if not wokenup_tasks then wokenup_tasks = __tasks.ready end
        table.insert(wokenup_tasks, newcell)
        for k in pairs(c) do c[k]=nil end

    elseif c.hook then -- callback is run synchronously
        local function f() return c.hook(unpack(args, 1, nargs)) end
        local ok, errmsg = xpcall(f, debug.traceback)
        local reattach_hook = not c.once
        if ok then -- pass
        elseif errmsg == KILL_TOKEN then -- killed with killself()
            reattach_hook = false
        else -- non-KILL error
            if type(errmsg)=='string' and errmsg :match "^attempt to yield" then
                errmsg = "Cannot block in a hook, consider sched.sigrun()\n" ..
                    (errmsg :match "function 'yield'\n(.-)%[C%]: in function 'xpcall'"
                    or errmsg)
            end
            errmsg = string.format("In signal %s.%s: %s",
                tostring(emitter), event, tostring(errmsg))
            log('sched', 'ERROR', errmsg)
            print (errmsg)
        end
        if reattach_hook then 
            if new_queue then table.insert (new_queue, c) end
        else for k in pairs(c) do c[k]=nil end end
    else end -- emptied cell, ignore it.
end


------------------------------------------------------------------------------
-- Sends a signal from [emitter] with message [event].                                              
--                                                                          
-- This means:
-- 
-- * waking up--by calling [run()]--all tasks which were waiting for        
--   this event;                                                            
-- * running all synchronous callbacks listening for that event;            
-- * delisting the tasks, and the callbacks which returned [false].        
--                                                                          
-- 
-- @param emitter string defining the entity which sends the signal
-- @param event a string representing the event's kind.
-- @param ... extra args passed to the woken up tasks and triggered hooks.
--
-- @return nothing.
------------------------------------------------------------------------------                                                            
function sched.signal (emitter, event, ...)
    log.trace ('sched', 'DEBUG', "SIGNAL %s.%s", tostring(emitter), event)
    local args  = table.pack(event, ...) -- args passed to hooks & rescheduled tasks
    local ptw   = __tasks.waiting
    local ptr   = __tasks.running
    local ptrdy = __tasks.ready

    --------------------------------------------------------------------
    -- [emq]: the row of waiting tasks associated with [emitter]
    -- [queues]: the event queues to parse: the one associated with the
    --           event, and the wildcard queue ['*']
    -- [wokenup_tasks]: tasks to reschedule because they were waiting
    --                  for this signal
    --------------------------------------------------------------------
    local emq = ptw [emitter]; if not emq then return end
    local wokenup_tasks = { }

    local function parse_queue (event_key)
        local old_queue = emq [event_key]
        if not old_queue then return end
        local new_queue = { }
        emq[event_key] = new_queue

        --------------------------------------------------------------------
        -- 1 - accumulate tasks to wake up, run callbacks, list
        --     the callbacks to reattach (others will be lost).
        --------------------------------------------------------------------
        for _, c in ipairs(old_queue) do -- c :: cell to parse
            runcell(c, emitter, event, args, wokenup_tasks, new_queue)
        end

        --------------------------------------------------------------------
        -- 2 - remove expired tasks / hooks / rows
        --------------------------------------------------------------------
        if not next(new_queue) then
            emq [event_key] = nil -- nobody left waiting for this event
            if not next(emq) then -- nobody left waiting for this emitter
                ptw [emitter] = nil
            end
        end
    end

    local prev_hold = __tasks.hold; __tasks.hold = true

    parse_queue('*')
    parse_queue(event)

    --------------------------------------------------------------------
    -- 3 - Actually reschedule the tasks
    --------------------------------------------------------------------
    for _, t in ipairs (wokenup_tasks) do table.insert (ptrdy, t) end

    __tasks.hold = prev_hold
    if not prev_hold then sched.step() end
end

------------------------------------------------------------------------------
-- Helper to let sighook, sigrun, sigrunonce etc. register and be notified
-- when a signal of interest occurs.
--
-- @usage
--
-- `register(cell, timeout)` registers for a timer event after the specified
-- time elapsed (in seconds).
--
-- `register(cell, emitter, event_string)` is an admissible shortcut for
-- `register(cell, emitter, {event_string})`.
--
-- @param cell entry to register
-- @param emitter of the signal of interest
-- @param events list of events to register, or `"*"` for every event;
--        the list can feature a timeout number.
-- @return the list of events subscribed
------------------------------------------------------------------------------
local function register (cell, emitter, events)

    --------------------------------------------------------------------
    -- 1 - Set emitters and events. events still contain timer events
    --------------------------------------------------------------------
    if events==nil and type(emitter)=='number' then
        emitter, events = nil, { emitter }
    end    
    if #events > 1 then cell.multi = true end

    local ptw  = __tasks.waiting
    local ptwe = ptw[emitter]
    if not ptwe then ptwe={ }; ptw[emitter]=ptwe end
    
    --------------------------------------------------------------------
    -- 2 - register timeout callbacks
    --------------------------------------------------------------------
    local hastimeout = false
    for _, event in ipairs(events) do
        if type(event)=='number' then
            if hastimeout then error("Several timeouts for one signal registration") end
            local function timeout_callback()
                if next(cell) then
                    runcell(cell, emitter, 'timeout', { 'timeout', event, n=2 })
                    for k in pairs(cell) do cell[k]=nil end
                    --sched.step() -- schedule it
                end                                    
            end
            hastimeout  = true
            local delay = event
            local ev    = sched.timer.set(delay, emitter, timeout_callback)
            local ptwet = ptwe.timeout
            if ptwet then table.insert(ptwet, cell) else ptwe.timeout={cell} end
            log.trace('sched', 'DEBUG', "Registered cell for %ds timeout event", event)
        end
    end

    --------------------------------------------------------------------
    -- 3 - register non-timer events
    --------------------------------------------------------------------
    -- Retrieve the row, or create it if it doesn't already exist
    if emitter then
        local emq = ptw[emitter]
        if not emq then emq = { }; ptw[emitter] = emq end
        for _, event in ipairs(events) do
            if type(event) ~= 'number' then
                -- Retrieve the cell in the row, or create it if required
                local evq = emq [event]
                if not evq then emq[event] = { cell }
                else table.insert (evq, cell) end
            end
        end
    end
    return events
end



------------------------------------------------------------------------------
--  Forces the currently running task out of scheduling until a certain 
--  signal is received.                                       
--                                                                          
--  Take a list of emitters, and a list of events. The task will be         
--  rescheduled the next time one of the listed events happens to one of the    
--  listed emitters. If there is a single emitter (resp. a single event),    
--  it can be passed outside of a table, i.e. 
--      wait(x, "open")
--  is the same as 
--      wait({x}, {"open"})                                          
--                                                                          
--  If no emitter or no event is listed, the task waits for nothing in      
--  particular, i.e. it puts itself back at the end of the scheduling       
--  queue, thus giving other threads a chance to run.                       
--                                                                          
--  There must be a task currently running, i.e.                            
--  @{__tasks.running} ~= nil.                                            
--                                                                          
--  Cf. description of @{__tasks.waiting} for a description of how tasks  
--  are put to wait on signals.                                             
--                                                                          
-- @param emitter table listing emitters to wait on. Can also be string to define
-- single emitter, or a number to specify a timeout (wait used as sleep function) 
-- @param ... optional vararg: can be events list in a table, or several events in
-- several arguments. Last event can be a number to specify a timeout call.
--
-- @usage                                                                         
-- wait()
-- wait(delay)
-- wait(emitter, event)
-- wait(emitter, event_list)
-- wait(emitter, event_and_timeout_list)
-- wait(emitter, event1, ..., eventN)
-- wait(emitter, event1, ..., eventN, timeout)
--
------------------------------------------------------------------------------
function sched.wait (emitter, ...)
    local current = __tasks.running or
        error ("Don't call wait() while not running!\n"..debug.traceback())
    local cell = { thread = current }
    local nargs = select('#', ...)

    if emitter==nil and nargs == 0 then -- wait()
        log('sched', 'DEBUG', "Rescheduling %s", tostring(current))
        table.insert (__tasks.ready, { current })
    else
        local events
        if nargs==0 then 
            emitter, events = '*', {emitter}
        elseif nargs==1 then
            events = (...)
            if type(events)~='table' then events={events} end
        else -- nargs>1, wait(emitter, ev1, ev2, ...)
            events = {...}
        end
        
        register(cell, emitter, events)
        
        if log.musttrace('sched', 'DEBUG') then -- TRACE:
            local ev_msg = { }
            for i=1, #events do ev_msg[i] = tostring(events[i]) end
            local msg =
                "WAIT emitter = " .. tostring(emitter) ..
                ", events = { " .. table.concat(ev_msg,", ") .. " } )"
            log.trace ('sched', 'DEBUG', msg)
        end -- /TRACE
    end

    --------------------------------------------------------------------
    -- Yield back to step() *without* reregistering in __tasks.ready
    --------------------------------------------------------------------
    __tasks.running = nil
    local x = { coroutine.yield () }

    if x and x[1] == KILL_TOKEN then 
        for k in pairs(cell) do cell[k]=nil end; error(KILL_TOKEN)
    else return unpack(x) end
end

------------------------------------------------------------------------------
-- Waits on several emitters.  
-- Same as @{wait}(), except that:
-- 
--  * the first argument is a list of emitters rather than an emitter;
--  * it returns emitter, event, args... instead of just event, args...
--
-- @param emitters table containing a list of the emitters to wait on
-- @param events table containing a list of the events to wait on, or a string 
-- describing an event's kind, or a number defining timeout for this call.
-- @return emitter, event, args that caused this call to end.
------------------------------------------------------------------------------
function sched.multiwait (emitters, events)
    checks('table', 'string|table|number')
    local current = __tasks.running or
        error ("Don't call wait() while not running!\n"..debug.traceback())
    if type(events)~='table' then events={events} end

    local cell = { thread=current, multiwait=true, multi=true }
    for _, emitter in ipairs(emitters) do
        register(cell, emitter, events)
    end 

    if log.musttrace('sched', 'DEBUG') then -- TRACE:
        local em_msg = { }
        for i=1, #emitters do em_msg[i] = tostring(emitters[i]) end
        local ev_msg = { }
        for i=1, #events do ev_msg[i] = tostring(events[i]) end
        local msg =
            "WAIT emitters = { " .. table.concat(em_msg,", ") ..
            " }, events = { " .. table.concat(ev_msg,", ") .. " } )"
        log.trace ('sched', 'DEBUG', msg)
    end -- /TRACE

    --------------------------------------------------------------------
    -- Yield back to step() *without* reregistering in __tasks.ready
    --------------------------------------------------------------------
    __tasks.running = nil
    local x = { coroutine.yield () }

    if x and x[1] == KILL_TOKEN then 
        for k in pairs(cell) do cell[k]=nil end; error(KILL_TOKEN)
    else return unpack(x) end
end


------------------------------------------------------------------------------
--  Hooks a callback function to a set of signals.                  
--                                                                          
--  Signals are described as for @{wait}(). See this function for more      
--  details.                                                                
--                                                                          
--  The callback is called synchronously as soon as the corresponding
--  signal is sent. If it returns [false] or [nil], it is detached after
--  being run. If it returns a non-false value, it will continue to be
--  triggered by this signal the next time it is sent.                           
--                                                                          
--  The hook will receive as arguments the event and any extra params
--  passed along with the signal.                                           
--
-- @param emitter list of signal emitters to watch or a string describing 
-- single emitter to watch
-- @param events events to watch from the emitters: a table containing a list 
-- of the events to wait on, a string discribing an event's kind, 
-- or a number defining timeout for this call.
-- @param f function to be used as hook 
-- @param ... extra optional params to be given to hook when called
-- @return registred hook
------------------------------------------------------------------------------
function sched.sighook (emitter, events, f, ...)
    checks ('?', 'string|table|number', 'function')
    local xtrargs = table.pack(...); if not xtrargs[1] then xtrargs=nil end
    local cell = { hook = f, xtrargs=xtrargs }
    if type(events)~='table' then events={events} end
    register (cell, emitter, events)
    return cell
end

------------------------------------------------------------------------------
--  Hooks a callback function to a set of signals. The hook will be 
-- triggered only one time.   
-- Same as @{sched.sighook}, except that the hook will be called only one time.
-- @param emitter a list of signal emitters to watch or a string describing 
-- a single emitter to watch
-- @param events events to watch from the emitters: a table containing a list 
-- of the events to wait on, a string describing an event's kind, 
-- or a number defining timeout for this call.
-- @param f function to be used as hook 
-- @param ... extra optional params to be given to hook when called
-- @return registred hook
------------------------------------------------------------------------------
function sched.sigonce (emitter, events, f, ...)
    checks ('?', 'string|table|number', 'function')
    local xtrargs = table.pack(...); if not xtrargs[1] then xtrargs=nil end
    local cell = { hook = f, once=true, xtrargs=xtrargs }
    if type(events)~='table' then events={events} end
    register (cell, emitter, events)
    return cell
end

-- Common helper for sigrun and sigrunonce
local function sigrun(once, emitter, events, f, ...)
    local xtrargs = table.pack(...); if not xtrargs[1] then xtrargs=nil end
    local cell, hook
    -- To ensure that a killself() in the task also kills
    -- the wrapping hook, attach this to the task's 'die' event.
    -- TODO: ensure that the hook cannot leak by leaving a zombie event
    local function propagate_killself(die_event, status, err)
        if not status and err==KILL_TOKEN then sched.kill(cell) end
    end
    local function hook (ev, ...)
        local t = sched.run(f, ev, ...)
        if not once then 
            sched.sigonce(t, 'die', propagate_killself) 
        end
    end
    cell = { hook=hook, once=once, xtrargs = xtrargs }
    if type(events)~='table' then events={events} end
    register (cell, emitter, events)
    return cell
end

------------------------------------------------------------------------------
--  Hooks a callback function to a set of signals. The hook will be called 
-- in a new thread, thereby allowing the hook to block.
-- Same as @{sched.sighook}, except that the hook will be called using @{sched.run}.
-- @param emitters a list of signal emitters to watch or a string describing 
-- single emitter to watch
-- @param events events to watch from the emitters: a table containing a list 
-- of the events to wait on, a string describing an event's kind, 
-- or a number defining timeout for this call.
-- @param f function to be used as hook 
-- @param ... extra optional params to be given to hook when called
-- @return registred hook
------------------------------------------------------------------------------
function sched.sigrun(...)
    checks ('?', 'string|table|number', 'function')
    return sigrun(false, ...)
end
------------------------------------------------------------------------------
--  Hooks a callback function to a set of signals. The hook will be called 
-- in a new thread (allowing the hook to block), and only one time.
-- Same as @{sched.sigrun}, except that the hook will be called only one time.
-- @param emitters a list of signal emitters to watch or a string describing 
-- a single emitter to watch
-- @param events events to watch from the emitters: a table containing a list 
-- of the events to wait on, a string describing an event's kind, 
-- or a number defining timeout for this call.
-- @param f function to be used as hook 
-- @param ... extra optional params to be given to hook when called
-- @return registred hook
------------------------------------------------------------------------------
function sched.sigrunonce(...)
    checks ('?', 'string|table|number', 'function')
    return sigrun(true, ...)
end

------------------------------------------------------------------------------
--  Does a full Garbage Collect and removes dead tasks from waiting lists.  
--
--  Dead tasks are removed when the expected event happens or when the expected 
--  event emitter dies. If that never occurs, and you still want to claim    
--  the memory associated with these dead tasks, you can always call this
--  function and it will remove them.
--                     
--  @return memory available (in number of bytes) after gc.                                     
------------------------------------------------------------------------------
function sched.gc()
    -- Design note: no need to do that on the `__tasks.ready` list: it
    -- auto-cleans itself when `run`() goes through it.                   --
    local costatus, cg = coroutine.status, collectgarbage
    local not_pth, ptw = not __tasks.hold, __tasks.waiting

    -- Getting rid of entries waiting for a dead thread / dead channel
    for emitter, events in pairs(ptw) do
        for event, event_queue in pairs(events) do
            local i, len = 1, #event_queue
            while i<=len do
                local cell = event_queue[i]
                if not next(cell) -- dead cell
                or cell.thread and costatus(cell.thread)=="dead" -- dead thread
                then table.remove(event_queue, i); len=len-1 else i=i+1 end
            end
            if not_pth and not next(event_queue) then events[event] = nil end  -- event with empty queue
        end
        -- remove emitter if there's no pending event left:
        if not_pth and not next(events) then ptw[emitter] = nil end
    end

    cg 'collect'; return math.floor(cg 'count' * 1000)
end

------------------------------------------------------------------------------
-- Kills a task.  
-- The task is killed by:
--
--  * making it send a KILL_TOKEN error if it is currently running           
--  * waking it up from a @{wait}() yielding with KILL_TOKEN as an argument
--  which in turn makes wait() to send ["KILL"] error.          
--  
-- @param x task to kill, as returned by @{sched.sighook} for example.
-- @return  nil if it killed another task,                             
-- never returns if it killed the calling task.                 
--                                                                          
------------------------------------------------------------------------------
function sched.kill (x)
    local tx = type(x)
    if tx=='table' then
        if x.hook then
            -- Cancel a hook
            for k in pairs(x) do x[k]=nil end
            CLEANUP_REQUIRED = true
        elseif not next(x) then -- emptied cell
            log('sched', 'DEBUG', "Attempt to kill a dead cell")
        else
            log("sched", "WARNING", "Don't know how to kill %s", sprint(x))
        end
    elseif x==__tasks.running then
        -- Kill current thread
        error (KILL_TOKEN)
    elseif tx=='thread' then
        -- Kill a non-running thread
        coroutine.resume (x, KILL_TOKEN)
        sched.signal (x, "die", "killed")
    else 
        log("sched", "WARNING", "Don't know how to kill %s", sprint(x))
    end
end

------------------------------------------------------------------------------
-- Kills the current task.  
--@return never returns as the current task is killed.
------------------------------------------------------------------------------
function sched.killself()
    error (KILL_TOKEN)
end

-- Export sched content if applicable
if UNPACK_SCHED then
    for k, v in pairs(sched) do
        rawset (_G, k, v)
    end
end

-- platform-dependent code
require 'sched.platform'

return sched