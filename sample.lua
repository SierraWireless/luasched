-- (c) Sierra Wireless 2012.
--
-- Basic scheduling sample: launches several data transfer tasks in parallel,
-- as well as an interactive shell over telnet.
-- This example does not demonstrate inter-tasks communication APIs.

-- Fix the path if necessary: by default, "./?.lua" is in the LUA_PATH,
-- but "./?/init.lua" isn't. Without this, the sample would require sched
-- to be installed in a standard lib directory.
if not package.path :find ("./?/init.lua", 1, 'plain') then
	package.path = "./?/init.lua;"..package.path
end

require 'sched'        -- The scheduler
require 'socket'       -- Must be the version adapted to the scheduler, check the paths!
require 'log'          -- Log managmeent module
require 'shell.telnet' -- Interactive, scheduler-compatible shell over telnet

-- Set default log verbosity
log.setlevel 'INFO'
--log.setlevel 'ALL' -- Very verbose, including scheduling logs

TELNET_PORT = 2000 
N_SENDERS   = 20   -- Number of parallel tasks to create
PORT        = 8765 -- Listening port
SERVER      = nil  -- Future listening socket
START_DELAY = 5    -- will wait before starting the test.

-- Some data to exchange
LOREM_IPSUM = string.rep([[
Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do
eiusmod tempor incididunt ut labore et dolore magna aliqua.  Ut enim ad
minim veniam, quis nostrud exercitation ullamco laboris nisi ut
aliquip ex ea commodo consequat.  Duis aute irure dolor in
reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla
pariatur.  Excepteur sint occaecat cupidatat non proident, sunt in
culpa qui officia deserunt mollit anim id est laborum.
]], 1000)

-- Connection the the listening socket and send data
function send_data()
    local client = assert(socket.connect('localhost', PORT))
    assert (client :send (LOREM_IPSUM))
    assert (client :close())
end

receiver_id      = 1 -- give a unique number id to each socket spawned by the listening socket
active_receivers = 0 -- keep count of currently running sockets.

-- Launched as a new task every time someone attempts to connect to the listening socket.
-- Receive data, count the bytes and discard it.
function receive_data(connected_socket, listening_socket)
    local my_id = receiver_id
    receiver_id = receiver_id + 1
    active_receivers = active_receivers + 1
    log('SAMPLE', 'INFO', "Starting reception task #%d, %d active receivers", my_id, active_receivers)
    local txt = assert(connected_socket :receive '*a')
    assert (connected_socket :close())
    active_receivers = active_receivers - 1
    log('SAMPLE', 'INFO', "End of reception task #%d, received %d bytes, %d active receivers", my_id, #txt, active_receivers)
end

-- Start a listening socket, which will spawn a `receive_data` task every time
-- someone connects to it.
function spawn_receiver()
    log('SAMPLE', 'INFO', "Creating server")
    SERVER = socket.bind('localhost', PORT, receive_data)
    sched.signal('sample', 'server_ready')
    log('SAMPLE', 'INFO', "Server readiness signalled")
end

-- Start the listening socket, connect a bunch of sockets to it in parallel.
function runtest()
    spawn_receiver()
    log('SAMPLE', 'INFO', "Creating %d parallel data-sending tasks", N_SENDERS)
    for i = 1, N_SENDERS do
        sched.run(send_data)
    end
end

-- Main function: start the telnet shell and launch the test after a short delay.
function main()
    shell.telnet.init{
        address     = '0.0.0.0', 
        port        = TELNET_PORT,
        editmode    = "edit",
        historysize = 100 }

    print ("A telnet interactive shell has been started on local port "..TELNET_PORT..
           "; the parallel data transfer test will start in "..START_DELAY.." seconds")

    sched.wait(START_DELAY)

    sched.run(runtest)
end

sched.run(main)
sched.loop()