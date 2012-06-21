return function(rpc)
    --log.setlevel('ALL', 'LUARPC')
    rpc.signature ('require', '#module')
end