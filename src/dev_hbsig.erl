-module(dev_hbsig).
-export([ json_to_erl/3, to_erl/1, to_str/1, structured_to/3, structured_from/3, httpsig_from/3, httpsig_to/3, msg2/3, flat_from/3, flat_to/3 ]).
-export([parse_binary_stack/1, patch_stack_forms/1]).
-export([safe_scheduler_location/2]).
-on_load(init/0).
-include_lib("eunit/include/eunit.hrl").
-include("include/hb.hrl").

%% On module load, patch hb_util:atom/1 to use binary_to_atom/list_to_atom
%% instead of list_to_existing_atom. This prevents crashes when custom atom
%% names (e.g., from JS Symbol values) arrive via ao-types annotations in
%% HTTP multipart requests, before device handlers can pre-create them.
init() ->
    ensure_prometheus_tables(),
    ensure_hb_name_table(),
    patch_hb_util_atom(),
    patch_dev_stack_transform(),
    patch_hb_name_all(),
    patch_scheduler_server_trap_exit(),
    patch_dev_scheduler_gateway(),
    patch_dev_codec_json_bundle(),
    patch_codec_structured_binary(),
    ok.

%% Pre-create prometheus ETS tables owned by a long-lived process.
%% Prometheus app starts as temporary during rebar3 boot and stops immediately,
%% destroying its supervisor-owned ETS tables. hb_event:server/0 then crashes
%% trying to insert into the missing tables. By creating them here during
%% on_load (synchronously) and giving ownership to a persistent process,
%% the tables survive prometheus app restarts.
%%
%% Note: During on_load, the module isn't fully loaded yet so we use an
%% inline fun for the spawned process instead of referencing a module function.
ensure_prometheus_tables() ->
    Tables = [
        {prometheus_registry_table, {bag, read_concurrency}},
        {prometheus_counter_table, write_concurrency},
        {prometheus_gauge_table, write_concurrency},
        {prometheus_summary_table, write_concurrency},
        {prometheus_quantile_summary_table, write_concurrency},
        {prometheus_histogram_table, write_concurrency},
        {prometheus_boolean_table, write_concurrency}
    ],
    %% Spawn a long-lived owner process using inline fun (safe during on_load)
    KeepAlive = fun Loop() -> receive _ -> Loop() end end,
    Owner = case whereis(hbsig_prometheus_owner) of
        undefined ->
            Pid = spawn(KeepAlive),
            try register(hbsig_prometheus_owner, Pid) catch _:_ -> ok end,
            Pid;
        Existing ->
            Existing
    end,
    %% Create tables synchronously, then give ownership to the long-lived process
    lists:foreach(fun({Name, Spec}) ->
        case ets:info(Name) of
            undefined ->
                {Type, Concurrency} = case Spec of
                    {T, C} -> {T, C};
                    C -> {set, C}
                end,
                ets:new(Name, [Type, named_table, public, {Concurrency, true}]),
                ets:give_away(Name, Owner, prometheus);
            _ ->
                ok
        end
    end, Tables).

%% Spawn a long-lived process to own the hb_name_registry ETS table.
%% Without this, the table may be created by a short-lived HTTP handler
%% process, and when that process dies, the table is destroyed along
%% with all registered names (including scheduler server registrations).
ensure_hb_name_table() ->
    Self = self(),
    spawn(fun() ->
        try
            ets:new(hb_name_registry, [
                named_table,
                public,
                {keypos, 1},
                {write_concurrency, true},
                {read_concurrency, true}
            ]),
            Self ! {hb_name_table, created}
        catch
            error:badarg ->
                Self ! {hb_name_table, already_exists}
        end,
        receive stop -> ok end
    end),
    receive
        {hb_name_table, _} -> ok
    after 5000 ->
        ok
    end.

%% Hot-patch hb_name:all/0 to call start() before ets:tab2list.
%% Without this, dev_scheduler_registry:get_processes/0 crashes with
%% badarg because the hb_name_registry ETS table was never created.
patch_hb_name_all() ->
    case code:get_object_code(hb_name) of
        {hb_name, Beam, Filename} ->
            case beam_lib:chunks(Beam, [abstract_code]) of
                {ok, {hb_name, [{abstract_code, {raw_abstract_v1, Forms}}]}} ->
                    PatchedForms = patch_hb_name_forms(Forms),
                    case compile:forms(PatchedForms, [return_errors]) of
                        {ok, hb_name, NewBinary} ->
                            code:load_binary(hb_name, Filename, NewBinary);
                        {ok, hb_name, NewBinary, _Warnings} ->
                            code:load_binary(hb_name, Filename, NewBinary);
                        _Error ->
                            ok
                    end;
                _ ->
                    ok
            end;
        error ->
            ok
    end.

%% Patch the all/0 function to call start() before ets:tab2list.
patch_hb_name_forms(Forms) ->
    lists:map(fun patch_hb_name_form/1, Forms).

patch_hb_name_form({function, Line, all, 0, Clauses}) ->
    %% Prepend start() call to the beginning of all/0 body
    PatchedClauses = lists:map(
        fun({clause, CL, Args, Guards, Body}) ->
            StartCall = {call, CL, {atom, CL, start}, []},
            {clause, CL, Args, Guards, [StartCall | Body]}
        end, Clauses),
    {function, Line, all, 0, PatchedClauses};
patch_hb_name_form(Other) ->
    Other.

%% Hot-patch dev_scheduler_server to add process_flag(trap_exit, true) in
%% spawn_link fun and handle EXIT messages in server/1 receive loop.
%% Without this, the scheduler server dies when the linked HTTP handler
%% process terminates, destroying ETS tables and hb_name registrations.
patch_scheduler_server_trap_exit() ->
    case get_sched_server_forms() of
        {ok, Forms, Filename} ->
            PatchedForms = patch_sched_forms(Forms),
            case compile:forms(PatchedForms, [return_errors]) of
                {ok, dev_scheduler_server, NewBinary} ->
                    code:load_binary(dev_scheduler_server, Filename, NewBinary);
                {ok, dev_scheduler_server, NewBinary, _Warnings} ->
                    code:load_binary(dev_scheduler_server, Filename, NewBinary);
                _Error -> ok
            end;
        error -> ok
    end.

get_sched_server_forms() ->
    case code:get_object_code(dev_scheduler_server) of
        {dev_scheduler_server, Beam, Filename} ->
            case beam_lib:chunks(Beam, [abstract_code]) of
                {ok, {dev_scheduler_server,
                      [{abstract_code, {raw_abstract_v1, Forms}}]}} ->
                    {ok, Forms, Filename};
                _ ->
                    SrcDir = filename:join(
                        filename:dirname(filename:dirname(Filename)), "src"),
                    SrcFile = filename:join(SrcDir,
                        "dev_scheduler_server.erl"),
                    IncDir = filename:join(
                        filename:dirname(filename:dirname(Filename)),
                        "include"),
                    case compile:file(SrcFile,
                            [debug_info, binary, return_errors,
                             {i, IncDir}]) of
                        {ok, dev_scheduler_server, NewBeam} ->
                            extract_sched_forms(NewBeam, Filename);
                        {ok, dev_scheduler_server, NewBeam, _} ->
                            extract_sched_forms(NewBeam, Filename);
                        _ -> error
                    end
            end;
        error -> error
    end.

extract_sched_forms(Beam, Filename) ->
    case beam_lib:chunks(Beam, [abstract_code]) of
        {ok, {dev_scheduler_server,
              [{abstract_code, {raw_abstract_v1, Forms}}]}} ->
            {ok, Forms, Filename};
        _ -> error
    end.

patch_sched_forms(Forms) ->
    lists:map(fun patch_sched_form/1, Forms).

patch_sched_form({function, Line, start, 3, Clauses}) ->
    {function, Line, start, 3,
        lists:map(fun patch_sched_start_clause/1, Clauses)};
patch_sched_form({function, Line, server, 1, Clauses}) ->
    {function, Line, server, 1,
        lists:map(fun patch_sched_server_clause/1, Clauses)};
patch_sched_form(Other) -> Other.

%% Patch start/3: Add process_flag(trap_exit, true) inside spawn_link fun
patch_sched_start_clause({clause, CL, Args, Guards, Body}) ->
    {clause, CL, Args, Guards,
        [patch_sched_spawn_link(E) || E <- Body]}.

patch_sched_spawn_link({call, L, {atom, FL, spawn_link} = Fun,
        [{'fun', FunL, {clauses, FunClauses}}]}) ->
    PatchedFunClauses = lists:map(
        fun({clause, CL, FArgs, FGuards, FBody}) ->
            TrapExit = {call, CL,
                {atom, CL, process_flag},
                [{atom, CL, trap_exit}, {atom, CL, true}]},
            {clause, CL, FArgs, FGuards, [TrapExit | FBody]}
        end, FunClauses),
    {call, L, Fun, [{'fun', FunL, {clauses, PatchedFunClauses}}]};
patch_sched_spawn_link(Other) -> Other.

%% Patch server/1: Add {'EXIT', _, _} -> server(State) to receive
patch_sched_server_clause({clause, CL, [StateArg], Guards, Body}) ->
    {clause, CL, [StateArg], Guards,
        [patch_sched_receive(E, StateArg) || E <- Body]};
patch_sched_server_clause(Other) -> Other.

patch_sched_receive({'receive', L, Clauses}, StateArg) ->
    ExitClause = {clause, L,
        [{tuple, L,
            [{atom, L, 'EXIT'}, {var, L, '_'}, {var, L, '_'}]}],
        [],
        [{call, L, {atom, L, server}, [StateArg]}]},
    {'receive', L, Clauses ++ [ExitClause]};
patch_sched_receive(Other, _) -> Other.

%% Wrapper for hb_gateway_client:scheduler_location/2 that catches
%% exceptions (e.g., network failures) and returns {error, Reason}.
safe_scheduler_location(Self, Opts) ->
    try hb_gateway_client:scheduler_location(Self, Opts) of
        Result -> Result
    catch
        _:Reason -> {error, Reason}
    end.

%% Hot-patch hb_gateway_client:scheduler_location/2 to wrap the entire
%% function body in try/catch. This prevents crashes when the gateway is
%% unreachable (DNS failure, connection refused, etc.) for ALL callers
%% including find_remote_scheduler, post_location, post_schedule, etc.
patch_dev_scheduler_gateway() ->
    case get_module_forms(hb_gateway_client) of
        {ok, Forms, Filename} ->
            PatchedForms = patch_gateway_client_forms(Forms),
            case compile:forms(PatchedForms, [return_errors]) of
                {ok, hb_gateway_client, NewBinary} ->
                    code:load_binary(hb_gateway_client, Filename, NewBinary);
                {ok, hb_gateway_client, NewBinary, _Warnings} ->
                    code:load_binary(hb_gateway_client, Filename, NewBinary);
                _Error -> ok
            end;
        error -> ok
    end.

get_module_forms(Module) ->
    case code:get_object_code(Module) of
        {Module, Beam, Filename} ->
            case beam_lib:chunks(Beam, [abstract_code]) of
                {ok, {Module,
                      [{abstract_code, {raw_abstract_v1, Forms}}]}} ->
                    {ok, Forms, Filename};
                _ ->
                    SrcDir = filename:join(
                        filename:dirname(filename:dirname(Filename)),
                        "src"),
                    SrcFile = filename:join(SrcDir,
                        atom_to_list(Module) ++ ".erl"),
                    IncDir = filename:join(
                        filename:dirname(filename:dirname(Filename)),
                        "include"),
                    case compile:file(SrcFile,
                            [debug_info, binary, return_errors,
                             {i, IncDir}]) of
                        {ok, Module, NewBeam} ->
                            extract_module_forms(Module, NewBeam, Filename);
                        {ok, Module, NewBeam, _} ->
                            extract_module_forms(Module, NewBeam, Filename);
                        _ -> error
                    end
            end;
        error -> error
    end.

extract_module_forms(Module, Beam, Filename) ->
    case beam_lib:chunks(Beam, [abstract_code]) of
        {ok, {Module,
              [{abstract_code, {raw_abstract_v1, Forms}}]}} ->
            {ok, Forms, Filename};
        _ -> error
    end.

patch_gateway_client_forms(Forms) ->
    lists:map(fun patch_gateway_client_form/1, Forms).

%% Wrap scheduler_location/2 body in try/catch to handle network errors
patch_gateway_client_form({function, Line, scheduler_location, 2, Clauses}) ->
    {function, Line, scheduler_location, 2,
        lists:map(fun wrap_clause_in_try/1, Clauses)};
%% Also wrap query/3 and query/5 which can throw on network errors
patch_gateway_client_form({function, Line, query, Arity, Clauses})
        when Arity =:= 3; Arity =:= 5 ->
    {function, Line, query, Arity,
        lists:map(fun wrap_clause_in_try/1, Clauses)};
patch_gateway_client_form(Other) -> Other.

%% Wrap a clause body in try/catch returning {error, Reason} on exception
wrap_clause_in_try({clause, CL, Args, Guards, Body}) ->
    {clause, CL, Args, Guards,
        [{'try', CL, Body, [],
            [{clause, CL,
                [{tuple, CL,
                    [{var, CL, '_'}, {var, CL, 'TryCatchReason'}, {var, CL, '_'}]}],
                [],
                [{tuple, CL,
                    [{atom, CL, error}, {var, CL, 'TryCatchReason'}]}]}],
            []}]};
wrap_clause_in_try(Other) -> Other.

%% Hot-patch dev_codec_json:to/3 to handle binary <<"true">> for bundle check.
%% When bundle=true comes from a URL query parameter, it arrives as a binary
%% string <<"true">> rather than the atom true, causing a case_clause crash.
patch_dev_codec_json_bundle() ->
    case get_module_forms(dev_codec_json) of
        {ok, Forms, Filename} ->
            PatchedForms = patch_json_bundle_forms(Forms),
            case compile:forms(PatchedForms, [return_errors]) of
                {ok, dev_codec_json, NewBinary} ->
                    code:load_binary(dev_codec_json, Filename, NewBinary);
                {ok, dev_codec_json, NewBinary, _Warnings} ->
                    code:load_binary(dev_codec_json, Filename, NewBinary);
                _Error -> ok
            end;
        error -> ok
    end.

patch_json_bundle_forms(Forms) ->
    lists:map(fun patch_json_bundle_form/1, Forms).

%% Find the to/3 function and patch the case expression for bundle
patch_json_bundle_form({function, Line, to, 3, Clauses}) ->
    {function, Line, to, 3,
        lists:map(fun patch_json_to_clause/1, Clauses)};
patch_json_bundle_form(Other) -> Other.

patch_json_to_clause({clause, CL, Args, Guards, Body}) ->
    {clause, CL, Args, Guards,
        [patch_json_bundle_case(E) || E <- Body]};
patch_json_to_clause(Other) -> Other.

%% Walk expressions to find the case on bundle and add <<"true">> clause
patch_json_bundle_case({'case', L, Scrutinee, Clauses}) ->
    %% Check if this is the bundle case by looking for true/false atoms
    HasTrue = lists:any(fun({clause, _, [{atom, _, true}], _, _}) -> true;
                           (_) -> false end, Clauses),
    HasFalse = lists:any(fun({clause, _, [{atom, _, false}], _, _}) -> true;
                            (_) -> false end, Clauses),
    case HasTrue andalso HasFalse of
        true ->
            %% Add <<"true">> clause that duplicates the true clause's body
            TrueBody = lists:foldl(
                fun({clause, _, [{atom, _, true}], _, B}, _) -> B;
                   (_, Acc) -> Acc
                end, [], Clauses),
            BinTrueClause = {clause, L,
                [{bin, L, [{bin_element, L,
                    {string, L, "true"}, default, default}]}],
                [], TrueBody},
            %% Add a catch-all clause for any other value
            CatchAllBody = lists:foldl(
                fun({clause, _, [{atom, _, false}], _, B}, _) -> B;
                   (_, Acc) -> Acc
                end, [], Clauses),
            CatchAll = {clause, L, [{var, L, '_'}], [], CatchAllBody},
            {'case', L, Scrutinee, Clauses ++ [BinTrueClause, CatchAll]};
        false ->
            {'case', L, Scrutinee,
                [patch_json_bundle_case_clause(C) || C <- Clauses]}
    end;
patch_json_bundle_case({match, L, Pat, Rhs}) ->
    {match, L, Pat, patch_json_bundle_case(Rhs)};
patch_json_bundle_case({call, L, Fun, Args}) ->
    {call, L, Fun, [patch_json_bundle_case(A) || A <- Args]};
patch_json_bundle_case(Other) -> Other.

patch_json_bundle_case_clause({clause, CL, Pats, Guards, Body}) ->
    {clause, CL, Pats, Guards,
        [patch_json_bundle_case(E) || E <- Body]};
patch_json_bundle_case_clause(Other) -> Other.

%% Hot-patch dev_codec_structured to add decode_value(binary, Value) clause.
%% This decodes RFC 8941 byte sequences (:base64data:) back to raw binary.
%% Used for string fields with non-printable characters (e.g., Lua code with newlines)
%% that are encoded as base64 by hbsig and annotated with ao-types: key="binary".
patch_codec_structured_binary() ->
    case get_module_forms(dev_codec_structured) of
        {ok, Forms, Filename} ->
            PatchedForms = patch_structured_decode_forms(Forms),
            case compile:forms(PatchedForms, [return_errors]) of
                {ok, dev_codec_structured, NewBinary} ->
                    io:format("~n=== HBSIG: Patching dev_codec_structured binary type (no warnings) ===~n"),
                    code:load_binary(dev_codec_structured, Filename, NewBinary);
                {ok, dev_codec_structured, NewBinary, Warnings} ->
                    io:format("~n=== HBSIG: Patching dev_codec_structured binary type (warnings: ~p) ===~n", [Warnings]),
                    code:load_binary(dev_codec_structured, Filename, NewBinary);
                CompileError ->
                    io:format("~n=== HBSIG: Failed to compile dev_codec_structured: ~p ===~n~n", [CompileError]),
                    ok
            end;
        error ->
            io:format("~n=== HBSIG: Could not get forms for dev_codec_structured ===~n"),
            ok
    end.

patch_structured_decode_forms(Forms) ->
    lists:map(fun patch_structured_decode_form/1, Forms).

%% Find decode_value/2 function and add binary clause before the catch-all
patch_structured_decode_form({function, Line, decode_value, 2, Clauses}) ->
    {function, Line, decode_value, 2, add_binary_clause(Clauses, Line)};
patch_structured_decode_form(Other) -> Other.

%% Add decode_value(binary, Value) clause before the OtherType catch-all.
%% The binary clause strips the :...: delimiters and base64-decodes the content.
add_binary_clause(Clauses, Line) ->
    %% Build: decode_value(binary, Value) ->
    %%     case Value of
    %%         <<":", Rest/binary>> ->
    %%             B64 = binary:part(Rest, 0, byte_size(Rest) - 1),
    %%             base64:decode(B64);
    %%         _ -> Value
    %%     end.
    CaseExpr = {'case', Line, {var, Line, 'Value'},
        [{clause, Line,
            [{bin, Line,
                [{bin_element, Line, {integer, Line, $:}, default, default},
                 {bin_element, Line, {var, Line, 'Rest'}, default, [binary]}]}],
            [],
            [{call, Line, {remote, Line, {atom, Line, base64}, {atom, Line, decode}},
                [{call, Line, {remote, Line, {atom, Line, binary}, {atom, Line, part}},
                    [{var, Line, 'Rest'},
                     {integer, Line, 0},
                     {op, Line, '-',
                        {call, Line, {atom, Line, byte_size}, [{var, Line, 'Rest'}]},
                        {integer, Line, 1}}]}]}]},
         {clause, Line,
            [{var, Line, '_'}],
            [],
            [{var, Line, 'Value'}]}]},
    BinaryClause = {clause, Line,
        [{atom, Line, binary}, {var, Line, 'Value'}],
        [],
        [CaseExpr]},
    %% Insert before the last two clauses (BinType catch-all and OtherType catch-all)
    insert_before_catchall(Clauses, BinaryClause).

insert_before_catchall(Clauses, NewClause) ->
    %% Find the position of the OtherType catch-all clause and insert before it
    %% The catch-all clauses are typically the last 2 (BinType->atom conversion, OtherType->throw)
    case length(Clauses) of
        N when N >= 2 ->
            {Front, [SecondLast, Last]} = lists:split(N - 2, Clauses),
            Front ++ [NewClause, SecondLast, Last];
        _ ->
            Clauses ++ [NewClause]
    end.

patch_hb_util_atom() ->
    case code:get_object_code(hb_util) of
        {hb_util, Beam, Filename} ->
            case beam_lib:chunks(Beam, [abstract_code]) of
                {ok, {hb_util, [{abstract_code, {raw_abstract_v1, Forms}}]}} ->
                    PatchedForms = patch_atom_clauses(Forms),
                    case compile:forms(PatchedForms, [return_errors]) of
                        {ok, hb_util, NewBinary} ->
                            code:load_binary(hb_util, Filename, NewBinary);
                        {ok, hb_util, NewBinary, _Warnings} ->
                            code:load_binary(hb_util, Filename, NewBinary);
                        _Error ->
                            ok
                    end;
                _ ->
                    ok
            end;
        error ->
            ok
    end.

%% Walk abstract forms and replace list_to_existing_atom calls in atom/1
%% with binary_to_atom/list_to_atom respectively.
patch_atom_clauses(Forms) ->
    lists:map(fun patch_form/1, Forms).

patch_form({function, Line, atom, 1, Clauses}) ->
    {function, Line, atom, 1, lists:map(fun patch_atom_clause/1, Clauses)};
patch_form(Other) ->
    Other.

patch_atom_clause({clause, Line, [{var, VLine, Var}], Guards, Body}) ->
    {clause, Line, [{var, VLine, Var}], Guards, patch_body(Body)};
patch_atom_clause(Other) ->
    Other.

patch_body(Body) ->
    lists:map(fun patch_expr/1, Body).

%% Replace list_to_existing_atom(X) with list_to_atom(X)
patch_expr({call, Line, {atom, FLine, list_to_existing_atom}, Args}) ->
    {call, Line, {atom, FLine, list_to_atom}, Args};
%% Recursively patch nested expressions
patch_expr({call, Line, Fun, Args}) ->
    {call, Line, patch_expr(Fun), lists:map(fun patch_expr/1, Args)};
patch_expr({op, Line, Op, Left, Right}) ->
    {op, Line, Op, patch_expr(Left), patch_expr(Right)};
patch_expr({match, Line, Left, Right}) ->
    {match, Line, patch_expr(Left), patch_expr(Right)};
patch_expr(Other) ->
    Other.

%% Parse a binary RFC 8941 structured field list string into a numbered map.
%% Example: <<"\"inc@1.0\", \"double@1.0\"">> => #{<<"1">> => <<"inc@1.0">>, <<"2">> => <<"double@1.0">>}
%% Non-binary values pass through unchanged.
parse_binary_stack(<<>>) -> #{};
parse_binary_stack(Bin) when is_binary(Bin) ->
    Items = binary:split(Bin, <<", ">>, [global]),
    {_, Map} = lists:foldl(
        fun(Item, {N, Acc}) ->
            Key = integer_to_binary(N),
            Val = unquote_sf(Item),
            {N + 1, maps:put(Key, Val, Acc)}
        end,
        {1, #{}},
        Items
    ),
    Map;
parse_binary_stack(Other) -> Other.

%% Remove surrounding quotes from an RFC 8941 string item.
unquote_sf(<<"\"", Rest/binary>>) ->
    Size = byte_size(Rest) - 1,
    case Rest of
        <<Val:Size/binary, "\"">> -> Val;
        _ -> <<"\"", Rest/binary>>
    end;
unquote_sf(Other) -> Other.

%% Hot-patch dev_stack:transform/3 to handle binary device-stack values.
%% When hbsig encodes arrays as RFC 8941 strings (to survive signature
%% verification), dev_stack receives a binary string instead of a map/list.
%% This patch wraps the hb_ao:get(<<"device-stack">>, ...) call with
%% dev_hbsig:parse_binary_stack/1 to convert binaries to numbered maps.
patch_dev_stack_transform() ->
    case get_dev_stack_forms() of
        {ok, Forms, Filename} ->
            PatchedForms = patch_stack_forms(Forms),
            case compile:forms(PatchedForms, [return_errors]) of
                {ok, dev_stack, NewBinary} ->
                    code:load_binary(dev_stack, Filename, NewBinary),
                    %% Write patched beam to disk for persistence
                    file:write_file(Filename, NewBinary);
                {ok, dev_stack, NewBinary, _Warnings} ->
                    code:load_binary(dev_stack, Filename, NewBinary),
                    file:write_file(Filename, NewBinary);
                _Error ->
                    ok
            end;
        error ->
            ok
    end.

%% Get abstract forms for dev_stack, compiling from source if beam lacks debug_info.
get_dev_stack_forms() ->
    case code:get_object_code(dev_stack) of
        {dev_stack, Beam, Filename} ->
            case beam_lib:chunks(Beam, [abstract_code]) of
                {ok, {dev_stack, [{abstract_code, {raw_abstract_v1, Forms}}]}} ->
                    {ok, Forms, Filename};
                _ ->
                    %% No abstract code in beam - compile from source
                    SrcDir = filename:join(
                        filename:dirname(filename:dirname(Filename)), "src"),
                    SrcFile = filename:join(SrcDir, "dev_stack.erl"),
                    IncDir = filename:join(
                        filename:dirname(filename:dirname(Filename)), "include"),
                    case compile:file(SrcFile,
                            [debug_info, binary, return_errors,
                             {i, IncDir}]) of
                        {ok, dev_stack, NewBeam} ->
                            case beam_lib:chunks(NewBeam, [abstract_code]) of
                                {ok, {dev_stack, [{abstract_code,
                                        {raw_abstract_v1, Forms2}}]}} ->
                                    {ok, Forms2, Filename};
                                _ -> error
                            end;
                        {ok, dev_stack, NewBeam, _Warnings} ->
                            case beam_lib:chunks(NewBeam, [abstract_code]) of
                                {ok, {dev_stack, [{abstract_code,
                                        {raw_abstract_v1, Forms2}}]}} ->
                                    {ok, Forms2, Filename};
                                _ -> error
                            end;
                        _ -> error
                    end
            end;
        error ->
            error
    end.

patch_stack_forms(Forms) ->
    lists:map(fun patch_stack_form/1, Forms).

patch_stack_form({function, Line, transform, 3, Clauses}) ->
    {function, Line, transform, 3,
        lists:map(fun(C) -> patch_stack_clause(C) end, Clauses)};
patch_stack_form({function, Line, resolve_map, 3, Clauses}) ->
    {function, Line, resolve_map, 3,
        lists:map(fun(C) -> patch_stack_clause(C) end, Clauses)};
patch_stack_form(Other) ->
    Other.

patch_stack_clause({clause, Line, Args, Guards, Body}) ->
    {clause, Line, Args, Guards, [wrap_device_stack_expr(E) || E <- Body]};
patch_stack_clause(Other) ->
    Other.

%% Walk expressions and wrap any hb_ao:get(<<"device-stack">>, ...) call
%% with dev_hbsig:parse_binary_stack/1.
wrap_device_stack_expr({call, _, _, _} = Expr) ->
    case is_device_stack_get(Expr) of
        true ->
            Line = element(2, Expr),
            {call, Line,
                {remote, Line,
                    {atom, Line, dev_hbsig},
                    {atom, Line, parse_binary_stack}},
                [Expr]};
        false ->
            recurse_wrap(Expr)
    end;
wrap_device_stack_expr(Expr) ->
    recurse_wrap(Expr).

%% Recurse into common expression types to find nested device-stack-get calls.
recurse_wrap({'case', L, Scrutinee, Clauses}) ->
    {'case', L, wrap_device_stack_expr(Scrutinee),
        [case C of
            {clause, CL, Pats, Guards, Body} ->
                {clause, CL, Pats, Guards, [wrap_device_stack_expr(E) || E <- Body]};
            Other -> Other
        end || C <- Clauses]};
recurse_wrap({match, L, Pattern, Rhs}) ->
    {match, L, Pattern, wrap_device_stack_expr(Rhs)};
recurse_wrap({call, L, Fun, Args}) ->
    {call, L, Fun, [wrap_device_stack_expr(A) || A <- Args]};
recurse_wrap({op, L, Op, Left, Right}) ->
    {op, L, Op, wrap_device_stack_expr(Left), wrap_device_stack_expr(Right)};
recurse_wrap({tuple, L, Elems}) ->
    {tuple, L, [wrap_device_stack_expr(E) || E <- Elems]};
recurse_wrap({block, L, Body}) ->
    {block, L, [wrap_device_stack_expr(E) || E <- Body]};
recurse_wrap(Other) ->
    Other.

%% Check if expression is hb_ao:get(<<"device-stack">>, ...)
is_device_stack_get({call, _, {remote, _, {atom, _, hb_ao}, {atom, _, get}},
        [FirstArg | _]}) ->
    is_device_stack_binary(FirstArg);
is_device_stack_get(_) ->
    false.

is_device_stack_binary({bin, _, [{bin_element, _, {string, _, "device-stack"}, _, _}]}) ->
    true;
is_device_stack_binary(_) ->
    false.

to_erl(Msg) ->
    Body = maps:get(<<"body">>, Msg),
    case Body of
        JSON when is_binary(JSON) ->
            % Body is a JSON string - decode it
            Decoded = json:decode(JSON),
            process_json_data(Decoded);
        AlreadyDecoded when is_map(AlreadyDecoded) ->
            % Body is already a parsed message (e.g., from multipart)
            AlreadyDecoded;
        Other ->
            Other
    end.

%% Return both raw term and formatted string representation
to_str(Obj) -> 
    % For raw, use our own format that preserves string/binary distinction
    RawRepr = iolist_to_binary(format_term_raw(Obj)),
    
    % Format the term for string representation (for display/logging)
    % This converts all binaries to byte format for UTF-8 safety
    FormattedRepr = iolist_to_binary(format_term_utf8_safe(Obj)),
    
    % Return a structured response with both representations
    iolist_to_binary([
        <<"#erl_response{raw=">>,
        RawRepr,
        <<",formatted=">>,
        FormattedRepr,
        <<"}">>
    ]).

%% Format term for raw output, preserving string literals
format_term_raw(Map) when is_map(Map) ->
    Items = maps:fold(fun(K, V, Acc) ->
        FormattedK = format_term_raw(K),
        FormattedV = format_term_raw(V),
        [[FormattedK, " => ", FormattedV] | Acc]
    end, [], Map),
    ["#{", lists:join(",", lists:reverse(Items)), "}"];
    
format_term_raw(List) when is_list(List) ->
    Items = [format_term_raw(Item) || Item <- List],
    ["[", lists:join(",", Items), "]"];
    
format_term_raw(Bin) when is_binary(Bin) ->
    % Always format as string literal for raw output
    % This preserves the information that it's meant to be a string
    ["<<\"", escape_binary_string(Bin), "\">>"];
    
format_term_raw(Atom) when is_atom(Atom) ->
    atom_to_list(Atom);
    
format_term_raw(Int) when is_integer(Int) ->
    integer_to_list(Int);
    
format_term_raw(Float) when is_float(Float) ->
    io_lib:format("~p", [Float]);
    
format_term_raw(Other) ->
    io_lib:format("~p", [Other]).

%% Escape binary content for string representation
escape_binary_string(Bin) ->
    escape_binary_string(Bin, []).

escape_binary_string(<<>>, Acc) ->
    lists:reverse(Acc);
escape_binary_string(<<$", Rest/binary>>, Acc) ->
    escape_binary_string(Rest, [$", $\\ | Acc]);
escape_binary_string(<<$\\, Rest/binary>>, Acc) ->
    escape_binary_string(Rest, [$\\, $\\ | Acc]);
escape_binary_string(<<$\n, Rest/binary>>, Acc) ->
    escape_binary_string(Rest, [$n, $\\ | Acc]);
escape_binary_string(<<$\r, Rest/binary>>, Acc) ->
    escape_binary_string(Rest, [$r, $\\ | Acc]);
escape_binary_string(<<$\t, Rest/binary>>, Acc) ->
    escape_binary_string(Rest, [$t, $\\ | Acc]);
escape_binary_string(<<C, Rest/binary>>, Acc) when C >= 32, C =< 126 ->
    escape_binary_string(Rest, [C | Acc]);
escape_binary_string(<<C, Rest/binary>>, Acc) ->
    % Non-printable character, use byte representation
    Escaped = io_lib:format("\\~3.8.0B", [C]),
    escape_binary_string(Rest, lists:reverse(Escaped) ++ Acc).

json_to_erl(Msg1, _Msg2, _Opts) ->
    Data = to_erl(Msg1),
    Result = to_str(Data),
    {ok, Result}.

%% Format term with UTF-8 safe binary representation
%% This is only used for the formatted output, not the raw output
format_term_utf8_safe(Map) when is_map(Map) ->
    Items = maps:fold(fun(K, V, Acc) ->
        FormattedK = format_term_utf8_safe(K),
        FormattedV = format_term_utf8_safe(V),
        [[FormattedK, " => ", FormattedV] | Acc]
    end, [], Map),
    ["#{", lists:join(",", lists:reverse(Items)), "}"];
    
format_term_utf8_safe(List) when is_list(List) ->
    Items = [format_term_utf8_safe(Item) || Item <- List],
    ["[", lists:join(",", Items), "]"];
    
format_term_utf8_safe(Bin) when is_binary(Bin) ->
    % Always use byte representation to avoid UTF-8 issues
    % This is only for the formatted output
    ByteList = binary_to_list(Bin),
    ["<<", lists:join(",", [integer_to_list(B) || B <- ByteList]), ">>"];
    
format_term_utf8_safe(Atom) when is_atom(Atom) ->
    atom_to_list(Atom);
    
format_term_utf8_safe(Int) when is_integer(Int) ->
    integer_to_list(Int);
    
format_term_utf8_safe(Float) when is_float(Float) ->
    io_lib:format("~p", [Float]);
    
format_term_utf8_safe(Other) ->
    io_lib:format("~p", [Other]).

%% Process JSON data - transform structured fields and $empty
process_json_data(Map) when is_map(Map) ->
    % Check for $empty annotation
    case maps:get(<<"$empty">>, Map, undefined) of
        <<"binary">> -> <<>>;
        <<"list">> -> [];
        <<"map">> -> #{};
        undefined ->
            maps:map(fun(_K, V) -> process_json_data(V) end, Map);
        _Other ->
            % For any other value of $empty, just process the map normally
            % This handles cases like "should not be special" or "test"
            maps:map(fun(_K, V) -> process_json_data(V) end, Map)
    end;
    
process_json_data(List) when is_list(List) ->
    [process_json_data(Item) || Item <- List];
    
process_json_data(Value) when is_binary(Value) ->
    % Check for structured field formats
    case Value of
        <<$:, Rest/binary>> when byte_size(Rest) > 0 ->
            case binary:last(Value) of
                $: ->
                    % It's a binary structured field, decode the base64
                    Base64Len = byte_size(Value) - 2,
                    <<$:, Base64:Base64Len/binary, $:>> = Value,
                    % Handle empty binary special case
                    case Base64 of
                        <<>> -> <<>>;
                        _ ->
                            try
                                base64:decode(Base64)
                            catch
                                _:_ -> Value  % If decode fails, return original
                            end
                    end;
                _ -> Value
            end;
        <<$%, Rest/binary>> when byte_size(Rest) > 0 ->
            case binary:last(Value) of
                $% ->
                    % It's a token structured field (for atoms)
                    TokenLen = byte_size(Value) - 2,
                    <<$%, Token:TokenLen/binary, $%>> = Value,
                    % Convert to atom
                    binary_to_atom(Token, utf8);
                _ -> Value
            end;
        _ -> 
            % Regular string, leave as-is (already a binary)
            Value
    end;
    
process_json_data(Other) -> 
    % Everything else passes through unchanged
    Other.

%% Check if binary contains only safe ASCII characters (32-126)
is_safe_ascii(Bin) ->
    lists:all(fun(B) -> B >= 32 andalso B =< 126 end, binary_to_list(Bin)).


structured_from(Msg1, _Msg2, _Opts) ->
    Data = to_erl(Msg1),
    {ok, OBJ} = dev_codec_structured:from(Data, #{<<"bundle">> => true}, #{}),
    Result = to_str(OBJ),
    {ok, Result}.

structured_to(Msg1, _Msg2, _Opts) ->
    Data = to_erl(Msg1),
    {ok, OBJ} = dev_codec_structured:to(Data, #{<<"bundle">> => true}, #{}),
    Result = to_str(OBJ),
    {ok, Result}.

httpsig_from(Msg1, _Msg2, _Opts) ->
    Data = to_erl(Msg1),
    {ok, OBJ} = dev_codec_httpsig:from(Data, #{<<"bundle">> => true}, #{}),
    Result = to_str(OBJ),
    {ok, Result}.

httpsig_to(Msg1, _Msg2, _Opts) ->
    Data = to_erl(Msg1),
    % Preprocess only unsupported types: boolean→atom, handle empty-* types
    PreparedData = preprocess_unsupported_types(Data),
    % Pre-create atoms from ao-types annotations so list_to_existing_atom won't crash
    % when dev_codec_httpsig_conv:to calls hb_cache:ensure_all_loaded
    ensure_atoms_from_ao_types(PreparedData),
    % Use bundle => true - Erlang does TABM → structured → TABM internally
    {ok, OBJ} = dev_codec_httpsig:to(PreparedData, #{<<"bundle">> => true}, #{}),
    Result = to_str(OBJ),
    {ok, Result}.

%% Preprocess ONLY unsupported types - minimal changes to not interfere with bundle round-trip
%% 1. Convert boolean types to atom types in ao-types
%% 2. Convert ?1/?0 boolean values to true/false strings
%% 3. Create empty values from empty-* types and remove from ao-types
preprocess_unsupported_types(Map) when is_map(Map) ->
    case maps:get(<<"ao-types">>, Map, undefined) of
        undefined ->
            % No ao-types, just recurse
            maps:map(fun(_K, V) -> preprocess_unsupported_types(V) end, Map);
        AoTypes when is_binary(AoTypes) ->
            % Only process if ao-types contains boolean or empty-* types
            HasBoolean = binary:match(AoTypes, <<"boolean">>) =/= nomatch,
            HasEmpty = binary:match(AoTypes, <<"empty-">>) =/= nomatch,
            case HasBoolean orelse HasEmpty of
                false ->
                    % No unsupported types, just recurse
                    maps:map(fun(_K, V) -> preprocess_unsupported_types(V) end, Map);
                true ->
                    {NewAoTypes, BoolKeys, EmptyEntries} = process_ao_types(AoTypes),
                    Map2 = convert_boolean_values(Map, BoolKeys),
                    Map3 = create_empty_values(Map2, EmptyEntries),
                    Map4 = case NewAoTypes of
                        <<>> -> maps:remove(<<"ao-types">>, Map3);
                        _ -> maps:put(<<"ao-types">>, NewAoTypes, Map3)
                    end,
                    maps:map(fun(_K, V) -> preprocess_unsupported_types(V) end, Map4)
            end;
        _ ->
            maps:map(fun(_K, V) -> preprocess_unsupported_types(V) end, Map)
    end;
preprocess_unsupported_types(Bin) when is_binary(Bin) ->
    % Convert inline boolean types in values to plain atom values
    case binary:match(Bin, <<"(ao-type-boolean)">>) of
        nomatch -> Bin;
        _ ->
            % Handle quoted inline annotations: "(ao-type-boolean) ?1" → true (atom)
            Bin2 = binary:replace(Bin, <<"\"(ao-type-boolean) ?1\"">>, <<"true">>, [global]),
            Bin3 = binary:replace(Bin2, <<"\"(ao-type-boolean) ?0\"">>, <<"false">>, [global]),
            % Handle unquoted inline annotations: (ao-type-boolean) ?1 → true (atom)
            Bin4 = binary:replace(Bin3, <<"(ao-type-boolean) ?1">>, <<"true">>, [global]),
            binary:replace(Bin4, <<"(ao-type-boolean) ?0">>, <<"false">>, [global])
    end;
preprocess_unsupported_types(List) when is_list(List) ->
    [preprocess_unsupported_types(Item) || Item <- List];
preprocess_unsupported_types(Other) ->
    Other.

%% Preprocess data to handle types not supported by structured codec
%% - Convert boolean types to atom types (SF format ?1/?0 → true/false)
%% - Create empty values from empty-* type annotations
%% - Remove empty-* types from ao-types (not supported by structured codec)
preprocess_types(Map) when is_map(Map) ->
    AoTypes = maps:get(<<"ao-types">>, Map, undefined),
    case AoTypes of
        undefined ->
            maps:map(fun(_K, V) -> preprocess_types(V) end, Map);
        _ ->
            {NewAoTypes, BoolKeys, EmptyEntries} = process_ao_types(AoTypes),
            Map2 = convert_boolean_values(Map, BoolKeys),
            Map3 = create_empty_values(Map2, EmptyEntries),
            Map4 = case NewAoTypes of
                <<>> -> maps:remove(<<"ao-types">>, Map3);
                _ -> maps:put(<<"ao-types">>, NewAoTypes, Map3)
            end,
            maps:map(fun(_K, V) -> preprocess_types(V) end, Map4)
    end;
preprocess_types(Bin) when is_binary(Bin) ->
    % Convert inline boolean types: "(ao-type-boolean) ?1" → "(ao-type-atom) true"
    Bin2 = binary:replace(Bin, <<"(ao-type-boolean) ?1">>, <<"(ao-type-atom) true">>, [global]),
    binary:replace(Bin2, <<"(ao-type-boolean) ?0">>, <<"(ao-type-atom) false">>, [global]);
preprocess_types(Other) ->
    Other.

%% Process ao-types: convert boolean→atom, extract empty-* entries, return cleaned ao-types
process_ao_types(AoTypes) when is_binary(AoTypes) ->
    Parts = binary:split(AoTypes, <<", ">>, [global]),
    {NewParts, BoolKeys, EmptyEntries} = lists:foldl(fun(Part, {PAcc, BAcc, EAcc}) ->
        case extract_type_annotation(Part) of
            {ok, Key, <<"boolean">>} ->
                NewPart = <<Key/binary, "=\"atom\"">>,
                {[NewPart | PAcc], [Key | BAcc], EAcc};
            {ok, Key, <<"empty-", _/binary>> = EmptyType} ->
                % Keep the original key (may be URL-encoded) to match JS behavior
                {PAcc, BAcc, [{Key, EmptyType} | EAcc]};
            _ ->
                {[Part | PAcc], BAcc, EAcc}
        end
    end, {[], [], []}, Parts),
    {iolist_to_binary(lists:join(<<", ">>, lists:reverse(NewParts))), BoolKeys, EmptyEntries};
process_ao_types(Other) ->
    {Other, [], []}.

%% Extract key and type from annotation like 'key="type"'
extract_type_annotation(Part) ->
    case binary:match(Part, <<"=\"">>) of
        {Pos, _} ->
            Key = binary:part(Part, 0, Pos),
            RestStart = Pos + 2,
            RestLen = byte_size(Part) - RestStart - 1,
            case RestLen > 0 of
                true ->
                    Type = binary:part(Part, RestStart, RestLen),
                    {ok, Key, Type};
                false ->
                    error
            end;
        nomatch ->
            error
    end.

%% URL decode (e.g., %2d → -)
url_decode(Bin) ->
    url_decode(Bin, <<>>).
url_decode(<<>>, Acc) ->
    Acc;
url_decode(<<$%, H1, H2, Rest/binary>>, Acc) ->
    Char = (hex_to_int(H1) bsl 4) bor hex_to_int(H2),
    url_decode(Rest, <<Acc/binary, Char>>);
url_decode(<<C, Rest/binary>>, Acc) ->
    url_decode(Rest, <<Acc/binary, C>>).

hex_to_int(C) when C >= $0, C =< $9 -> C - $0;
hex_to_int(C) when C >= $a, C =< $f -> C - $a + 10;
hex_to_int(C) when C >= $A, C =< $F -> C - $A + 10.

%% Convert boolean values from SF format (?1/?0) to atom format (true/false)
convert_boolean_values(Map, []) -> Map;
convert_boolean_values(Map, [Key | Rest]) ->
    LowerKey = list_to_binary(string:lowercase(binary_to_list(Key))),
    Map2 = case maps:get(LowerKey, Map, undefined) of
        <<"?1">> -> maps:put(LowerKey, <<"true">>, Map);
        <<"?0">> -> maps:put(LowerKey, <<"false">>, Map);
        _ ->
            case maps:get(Key, Map, undefined) of
                <<"?1">> -> maps:put(Key, <<"true">>, Map);
                <<"?0">> -> maps:put(Key, <<"false">>, Map);
                _ -> Map
            end
    end,
    convert_boolean_values(Map2, Rest).

%% Create native empty values from empty-* type entries
create_empty_values(Map, []) -> Map;
create_empty_values(Map, [{Key, EmptyType} | Rest]) ->
    LowerKey = list_to_binary(string:lowercase(binary_to_list(Key))),
    EmptyValue = case EmptyType of
        <<"empty-binary">> -> <<>>;
        <<"empty-list">> -> [];
        <<"empty-message">> -> #{}
    end,
    Map2 = case maps:is_key(LowerKey, Map) of
        true -> Map;
        false -> maps:put(LowerKey, EmptyValue, Map)
    end,
    create_empty_values(Map2, Rest).

%% Walk a data structure and pre-create atoms from ao-types annotations.
%% This ensures that list_to_existing_atom won't crash when
%% hb_cache:ensure_all_loaded encounters these atoms during link resolution.
ensure_atoms_from_ao_types(Map) when is_map(Map) ->
    case maps:get(<<"ao-types">>, Map, undefined) of
        AoTypes when is_binary(AoTypes) ->
            % Parse ao-types and pre-create atoms for "atom" type annotations
            Pairs = binary:split(AoTypes, <<", ">>, [global]),
            lists:foreach(fun(Pair) ->
                case extract_type_annotation(Pair) of
                    {ok, Key, <<"atom">>} ->
                        % Find the value for this key and create the atom
                        LowerKey = list_to_binary(
                            string:lowercase(binary_to_list(Key))),
                        Value = case maps:get(Key, Map, undefined) of
                            undefined -> maps:get(LowerKey, Map, undefined);
                            V -> V
                        end,
                        case Value of
                            V2 when is_binary(V2) ->
                                binary_to_atom(V2, utf8);
                            _ -> ok
                        end;
                    _ -> ok
                end
            end, Pairs);
        _ -> ok
    end,
    % Recurse into nested maps
    maps:foreach(fun(_K, V) -> ensure_atoms_from_ao_types(V) end, Map);
ensure_atoms_from_ao_types(List) when is_list(List) ->
    lists:foreach(fun(Item) -> ensure_atoms_from_ao_types(Item) end, List);
ensure_atoms_from_ao_types(_) ->
    ok.

flat_from(Msg1, _Msg2, _Opts) ->
    Data = to_erl(Msg1),
    PreparedData = prepare_for_flat(Data),
    {ok, OBJ} = dev_codec_flat:from(PreparedData, #{}, #{}),
    Result = to_str(OBJ),
    {ok, Result}.

%% Convert non-binary leaf values to binaries for dev_codec_flat compatibility
prepare_for_flat(Map) when is_map(Map) ->
    maps:map(fun(_K, V) -> prepare_for_flat(V) end, Map);
prepare_for_flat(List) when is_list(List) ->
    % Convert list to JSON-like binary representation
    iolist_to_binary(io_lib:format("~p", [List]));
prepare_for_flat(Bin) when is_binary(Bin) ->
    Bin;
prepare_for_flat(Int) when is_integer(Int) ->
    integer_to_binary(Int);
prepare_for_flat(Float) when is_float(Float) ->
    float_to_binary(Float, [{decimals, 10}, compact]);
prepare_for_flat(true) ->
    <<"true">>;
prepare_for_flat(false) ->
    <<"false">>;
prepare_for_flat(null) ->
    <<"null">>;
prepare_for_flat(Atom) when is_atom(Atom) ->
    atom_to_binary(Atom, utf8);
prepare_for_flat(Other) ->
    iolist_to_binary(io_lib:format("~p", [Other])).

flat_to(Msg1, _Msg2, _Opts) ->
    Data = to_erl(Msg1),
    {ok, OBJ} = dev_codec_flat:to(Data, #{}, #{}),
    Result = to_str(OBJ),
    {ok, Result}.

msg2(_Msg, Msg2, _Opts) ->
    Msg3 = process_ao_types_empty_values(Msg2, Msg2),
    Result = to_str(Msg3),
    {ok, Result}.

%% Process ao-types and add empty values for empty-* type annotations.
%% Also remove the default empty body if it's not in ao-types.
process_ao_types_empty_values(Msg, Msg2) ->
    AoTypes = maps:get(<<"ao-types">>, Msg, <<>>),
    case AoTypes of
        <<>> -> Msg2;
        _ ->
            % Parse ao-types to get empty type annotations
            EmptyKeys = parse_empty_types(AoTypes),
            % Add empty values for keys that have empty-* types
            Msg3 = lists:foldl(
                fun({Key, Type}, Acc) ->
                    case Type of
                        <<"empty-binary">> ->
                            maps:put(Key, <<>>, Acc);
                        <<"empty-list">> ->
                            maps:put(Key, [], Acc);
                        <<"empty-message">> ->
                            maps:put(Key, #{}, Acc);
                        _ ->
                            Acc
                    end
                end,
                Msg2,
                EmptyKeys
            ),
            % If body is empty and not in ao-types, remove it
            % (it's just a default from the HTTP layer)
            BodyInAoTypes = lists:any(
                fun({K, _}) -> K =:= <<"body">> end,
                EmptyKeys
            ),
            case maps:get(<<"body">>, Msg3, undefined) of
                <<>> when not BodyInAoTypes ->
                    maps:remove(<<"body">>, Msg3);
                _ ->
                    Msg3
            end
    end.

%% Parse ao-types string and return list of {Key, Type} for empty-* types
parse_empty_types(AoTypes) ->
    % Split by ", " and parse each key="type" pair
    Pairs = binary:split(AoTypes, <<", ">>, [global]),
    lists:filtermap(
        fun(Pair) ->
            case re:run(Pair, <<"^(.+?)=\"(empty-[^\"]+)\"$">>, [{capture, [1, 2], binary}]) of
                {match, [Key, Type]} ->
                    {true, {Key, Type}};
                _ ->
                    false
            end
        end,
        Pairs
    ).

