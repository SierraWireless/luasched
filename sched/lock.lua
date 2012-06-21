--------------------------------------------------------------------------------
-- Thread-bound lock objects
-- =========================
--
-- A lock allows to define atomic units of code execution: 
-- a portion of code that is protected by a lock will never be executed by more
-- than one thread at a time.
-- Because of the use of coroutines for the threading in Lua, the use of locks 
-- is only relevant when you want to protect a portion of code that contains
-- blocking APIs (i.e. network access, scheduling, etc...)
--
-- A lock must be acquired and released by the same thread: an error will be 
-- triggered if a thread tries to release a lock acquired by another thread.
-- This behavior is enforced because it is almost always a concurrency mistake
-- to have a thread releasing another thread's locks; but you can circumvent
-- this by passing the owning thread as an extra parameter.
--
-- A lock is automatically released when its owning thread dies, if it failed
-- to do so explicitly.
--
-- API
-- ---
--
-- lock.new()
--      return a new instance of a lock.
--
-- LOCK :acquire ()
--      acquire the lock.
--
-- LOCK :release ([thread])
--      release the lock. The optional thread param is defaulted to the 
--      current thread. A lock must be released by the thread that
--      acquired it (or use the thread params to release another thread's lock).
--
-- LOCK :destroy()
--      destroy the lock. Any waiting thread on that lock will trigger a
--      "destroyed" error
--
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Associative lock objects
-- ------------------------
--
-- Function lock (object) allows to associate a lock to an arbitrary object.
-- This API creates a standard lock (as above). It removes the burden of
-- creating the lock and managing the association between the object
-- and the lock.
--
-- Locks associated to objects still have an owning thread, and the rule
-- "locks must be released by the thread which owns them" still applies.
--
-- API
--
-- lock.lock (object)
--      lock the object.
--
-- lock.unlock(object, thread)
--      unlock the object. thread is optional as in lock:acquire() function.
--
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Synchronized functions
-- ----------------------
--
-- A common pattern is to have a function that must not be called more than once
-- at a given time: if the function is already running in another thread, one
-- must wait for this call to finish before calling it again.
--
-- API
--
-- lock.synchronized (f)
--      return a synchronized wrapper around f. A typical idiom is:
--
--      mysynchronizedfunction = lock.synchronized (function (...)
--          [code]
--      end)
--------------------------------------------------------------------------------
local sched = require 'sched'
local checks = require 'checks'
local setmetatable = setmetatable
local tostring = tostring
local string = string
local error = error
local assert = assert
local table = table
local next = next
local proc = proc -- sched internal table
local pairs = pairs
local type = type
local unpack = unpack

require 'utils.table' -- needed for table.pack. To be removed when we switch to Lua5.2


module(...)

--------------------------------------------------------------------------------
-- 
--------------------------------------------------------------------------------
LOCK = { hooks =  {}, objlocks = setmetatable({}, {__mode = "k"}) }
LOCK.__index = LOCK

--------------------------------------------------------------------------------
-- Create a new lock object. It remains unlocked.
--------------------------------------------------------------------------------
function new()
    return setmetatable({ waiting =  {} }, LOCK)
end

--------------------------------------------------------------------------------
-- Destroy a lock object.
--------------------------------------------------------------------------------
function LOCK:destroy()
    self.owner = "destroyed" -- means that the lock is being destroyed !
    for t, _ in pairs(self.waiting) do
        sched.signal(self, t)
        self.waiting[t] = nil
    end
end

--------------------------------------------------------------------------------
-- Helper to release locks on dead threads.
--------------------------------------------------------------------------------
local function autorelease(thread)
    for l, _ in pairs(LOCK.hooks[thread]) do
        if l.owner == thread then l:release(thread)
        elseif l.waiting then l.waiting[thread] = nil end
    end
    LOCK.hooks[thread] = nil
end

--------------------------------------------------------------------------------
-- Helper to release locks on dead threads.
--------------------------------------------------------------------------------
local function protectdie(self, thread)
    if not LOCK.hooks[thread] then
        local h = sched.sigonce(thread, "die", function() 
            autorelease(thread)
        end)
        LOCK.hooks[thread] = {sighook = h}
    end
    (LOCK.hooks[thread])[self] = true
end

--------------------------------------------------------------------------------
-- Helper to release locks on dead threads.
--------------------------------------------------------------------------------
local function unprotectdie(self, thread)
    (LOCK.hooks[thread])[self] = nil
    if not next(LOCK.hooks[thread], next(LOCK.hooks[thread])) then -- if this was the last lock attached to that thread...
        sched.kill(LOCK.hooks[thread].sighook)
        LOCK.hooks[thread] = nil
    end
end

--------------------------------------------------------------------------------
-- Attempt to take ownership of a lock; might block until the current owner
-- releases it.
--------------------------------------------------------------------------------
function LOCK:acquire()
    local t = proc.tasks.running --coroutine.running()
    assert(self.owner ~= t, "a lock cannot be acquired twice by the same thread")
    assert(self.owner ~= "destroyed", "cannot acquire a destroyed lock")
    protectdie(self, t) -- ensure that the lock will be unlocked if the thread dies before unlocking...

    while self.owner do
        self.waiting[t] = true
        sched.wait(self, {t}) -- wait on the current lock with the current thread
        if self.owner == "destroyed" then error("lock destroyed while waiting") end
    end
    self.waiting[t] = nil
    self.owner = t
end

--------------------------------------------------------------------------------
-- Release ownership of a lock. 
--------------------------------------------------------------------------------
function LOCK:release(thread)
    thread = thread or proc.tasks.running --coroutine.running()
    assert(self.owner ~= "destroyed", "cannot release a destroyed lock")
    assert(self.owner == thread, "unlock must be done by the thread that locked")
    unprotectdie(self, thread)
    self.owner = nil

    -- wakeup a waiting thread, if any...
    local t = next(self.waiting)
    if t then
        sched.signal(self, t)
    end
end

--------------------------------------------------------------------------------
-- Create and acquire a new lock, associated to an arbitrary object.
--------------------------------------------------------------------------------
function lock(object)
    assert(object, "you must provide an object to lock on")
    assert(type(object) ~= "string" and type(object) ~= "number", "the object to lock on must be a collectable object (no string or number)")
    if not LOCK.objlocks[object] then LOCK.objlocks[object] = new() end
    LOCK.objlocks[object]:acquire()
end


--------------------------------------------------------------------------------
-- Release an object created with lock().
--------------------------------------------------------------------------------
function unlock(object, thread)
    assert(object, "you must provide an object to unlock on")
    assert(LOCK.objlocks[object], "this object was not locked")
    LOCK.objlocks[object]:release()
end

--------------------------------------------------------------------------------
-- Create a synchronized version of function f, i.e. a function that behaves
-- as f, except that no more than one instance of it will be running at a 
-- given time.
--------------------------------------------------------------------------------
function synchronized(f)
    checks('function')
    local function sync_f(...)
        local k = lock (f)
        local r = table.pack( f(...) )
        unlock(f)
        return unpack (r, 1, r.n)
    end
    return sync_f
end
