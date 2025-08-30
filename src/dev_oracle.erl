-module(dev_oracle).
-export([ info/3, compute/3, init/3, snapshot/3, normalize/3 ]).
-include_lib("eunit/include/eunit.hrl").
-include("include/hb.hrl").

info(Msg1, Msg2_, Opts) ->
    JSON = dev_codec_json:to(#{ <<"version">> => <<"1.0">> }),
    {ok, JSON}.

compute(Msg1, Msg2, Opts) ->
    % Early exit if body doesn't exist
    Body = maps:get(<<"body">>, Msg2, undefined),
    if Body == undefined -> 
        {ok, hb_ao:set(Msg1, #{}, Opts)};
    true ->
        % Early exit if tags doesn't exist
        Tags = maps:get(<<"tags">>, Body, undefined),
        if Tags == undefined -> 
            {ok, hb_ao:set(Msg1, #{}, Opts)};
        true ->
            % Get required fields
            FromProcess = hb_ao:get([<<"body">>, <<"from-process">>], Msg2, not_found, Opts),
            Reference = hb_ao:get([<<"body">>, <<"reference">>], Msg2, not_found, Opts),
            
            % Get URL from tags or undefined
            URL = case [V || #{<<"name">> := <<"Url">>, <<"value">> := V} <- Tags] of
                      [U|_] -> U;
                      [] -> undefined
                  end,
            
            % Early exit if no URL found
            if URL == undefined ->
                {ok, hb_ao:set(Msg1, #{}, Opts)};
            true ->
                % Make the relay call
                {ok, Res} = hb_ao:resolve(
                    #{
                        <<"device">> => <<"relay@1.0">>,
                        <<"content-type">> => <<"application/json">>
                    },
                    #{
                        <<"path">> => <<"call">>,
                        <<"relay-method">> => <<"GET">>,
                        <<"relay-path">> => URL,
                        <<"content-type">> => <<"application/json">>
                    },
                    Opts#{
                        hashpath => ignore,
                        cache_control => [<<"no-store">>, <<"no-cache">>]
                    }
                ),
                
                JSON = maps:get(<<"body">>, Res),
                % Return based on what fields we have
                case {FromProcess, Reference} of
                    {not_found, _} -> {ok, hb_ao:set(Msg1, #{}, Opts)};
                    {_, not_found} -> {ok, hb_ao:set(Msg1, #{}, Opts)};
                    {FromProc, Ref} ->
                        {ok, hb_ao:set(Msg1, #{
                            <<"results">> => #{
                                <<"outbox">> => #{
                                    <<"1">> => #{
                                        <<"target">> => FromProc,
                                        <<"data">> => JSON,
                                        <<"action">> => <<"Reply">>,
                                        <<"x-reference">> => Ref,
                                        <<"type">> => <<"Message">>
                                    }
                                }
                            }
                        }, Opts)}
                end
            end
        end
    end.

init(Msg, Msg2, Opts) -> 
    {ok, hb_ao:set(Msg, #{ <<"count">> => 0 }, Opts)}.

snapshot(Msg, _Msg2, _Opts) -> {ok, Msg}.

normalize(Msg, _Msg2, _Opts) -> {ok, Msg}.
