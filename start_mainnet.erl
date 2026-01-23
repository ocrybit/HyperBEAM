-module(start_mainnet).
-export([start/0]).

start() ->
    hb:start_mainnet(#{
        port => 10001,
        priv_key_location => <<".wallet.json">>
    }).
