-- Select an implementation of `rpc`, depending on whether `sched` is enabled.

if global then global 'sched'; global 'rpc' end -- Avoid 'strict' errors
rpc = require (sched and 'rpc.sched' or 'rpc.nosched')

rpc.signature = require 'rpc.proxy' .signature

require 'rpc.builtinsignatures' (rpc)

return rpc