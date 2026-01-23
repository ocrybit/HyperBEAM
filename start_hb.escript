#!/usr/bin/env escript
%%! -sname hb_startup

main(_) ->
    Wallet = <<".wallet.json">>,
    Port = 10001,
    hb:start_mainnet(#{port => Port, priv_key_location => Wallet}).
