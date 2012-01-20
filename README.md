This is a preliminary release of the coroutine-based Lua scheduler at
the core of Sierra Wireless' M2M development framework. It allows
collaborative multitasking and synchronization within a single Lua state. 

A developer preview of Sierra Wireless' Lua SDK is available on 
[the Lua Workshop '11 website](http://www.lua.org/wshop11.html)
[[PDF]](http://www.lua.org/wshop11/m2m-embedded-development-with-lua.pdf).


Content
=======

Third party projects
--------------------

This project includes the following 3rd party projects, all under MIT
or other MIT-compatible public licences:

 * [coxpcall](http://coxpcall.luaforge.net/): part of the Kepler
   project, (c) Roberto Ierusalimschy, André Carregal, Thomas Harning
   Jr., Ignacio Burgueño, Gary NG, Fábio Mascarenhas

 * [LuaSocket](http://w3.impa.br/~diego/software/luasocket/), (c)
   Diego Nehab. Notice that the embedded version is heavily modified
   to integrate with the scheduler.

 * [LuaPack](http://www.tecgraf.puc-rio.br/~lhf/ftp/lua/), (c) Luiz
   Henrique de Figueiredo.


Sierra Wireless Modules
-----------------------

The following modules have been developped and are released by Sierra
Wireless. Although the current release lacks a compiled documentation,
every public API is properly documented with LuaDoc-compatible comment
headers.

* `sched`: the scheduler itself
** `sched.lock`: mutexes and synchronization
** `sched.pipe`: communication queues
* `checks`: a library to quickly and easily check Lua function and arguments,
   and generate proper error message when invalid arguments are detected.
* `print`: a Lua table pretty-printer, used among others by the shell
* `shell.telnet`: an interactive shell served over telnet
* `log`: a configurable applications log system, allowing fine-grained
  control over verbosity, as well as selective redirection of logs
  toward different back-ends.

Quick overview
==============

Scheduling API
--------------

New tasks are created by passing a function to `sched.run()`.
Communication and synchronization are usually best performed through
signal emission and monitoring, cf. `sched.signal`, `sched.wait`,
`sched.sigrun` etc. for detailled explanations.

For more advanced inter-task communications, check out `sched.lock`
and `sched.pipe`.

The scheduler is started by calling `sched.loop()`, which never
returns. You must have scheduled at least one task with `sched.run`
before starting the loop, otherwise your program won't do anything.

This scheduler is a collaborative scheduler: it won't preemptively
stop a task which never perform any blocking/rescheduling
operation. It is not suitable for real-time operations: these must be
performed in a separate thread on a real-time process, and then
optionally interfaced with Lua for convinience. A rogue task might
lock the whole lua_State in which it runs.


Interactive development
-----------------------

Since the loop blocks forever, it prevents interactive development
over the usual Lua shell. However, if you start a `shell.telnet` task,
you will be able to interact with a telnet client. For instance, you
can connect to a shell launched as below with "`telnet localhost
2000`":

     require 'sched'
     require 'shell.telnet'

     function main()
         shell.telnet.init{
             address     = '0.0.0.0', 
             port        = 2000,
             editmode    = "edit",
             historysize = 100 }
     end

     sched.run(main)
     sched.loop()

The shell offers history navigation, the usual edition capabilities,
and auto-completion. In addition, it supports the following features:

* an expression prefixed with "=" will print this expression's value
  on the shell, as does the usual Lua shell.

* an expression prefixed with ":" will print this expression's value
  on the shell in a detailed way: tables will be properly
  pretty-printed and indented. The system is protected against
  recursive tables.

* a statement prefixed with "&" will be launched in the background:
  the user can enter new commands in the shell before the task
  terminates.

* Ctrl-Z, pressed when a task is in the foreground and locks the
  shell, will put the task in the background and give back control
  over the shell.

* Ctrl-C, pressed when a task is in the foreground and locks the
  shell, will kill the task and give back control over the shell.

Installation
============

The external needs are:

* a Lua 5.1 VM (`sudo apt-get install lua5.1` on Ubuntu);
* the Lua 5.1 C header files, available on
  [the Lua website](http://www.lua.org/versions.html#5.1);
* GCC and Gnu Makefile.

This distribution has been successfully tested on Linux 32 and 64
bits. You need to edit the `LUA_INC` path to Lua headers in the
Makefile, then run `make`.

The LuaSocket port does NOT work under Mac OS X.

You can then either install the result (everything except the `c`
folder, the `Makefile`, `sample.lua` and the `fetch.lua` script) in a
Lua directory, or run it directly from the current directory. In the
later case, beware that by default, the `"./?/init.lua"` loader path
isn't included in the Lua path. You'll have to do a:

     export LUA_PATH="./?.lua;./?/init.lua"

You can test it with the sample provided:

     $ make
     $ export LUA_PATH="./?.lua;./?/init.lua"
     $ lua sample.lua


Important warnings
==================

This is a preliminary release, in response to interest expressed
towards Sierra Wireless' work. APIs are likely to change without
regard for backward compatibility.

The scheduler-adapted version of LuaSocket does not work under
Mac OS X, for yet uninvestigated reasons.
