# HyperBEAM M4 Technical Specification
## Decentralized Schedulers, LiveNet Staking, Streaming Token Distributions & AO-Core 1.5

**Version**: 1.0.0
**Date**: January 24, 2026
**Status**: Pre-Release Analysis

---

# TL;DR

## What's Coming in M4

| Feature | What It Does | Key Innovation |
|---------|--------------|----------------|
| **Decentralized Schedulers** | Distributed message ordering across multiple nodes | Lookahead caching, nonce-based registration, ANS-104 wrapping |
| **LiveNet Staking** | Non-fungible stake vaults with FIFO unstaking | Cooldown exploit prevention, time-indexed auto-finalization |
| **Streaming Tokens** | Real-time on-demand minting (POT model) | Chi-proportional accumulation, zero-computation until withdrawal |
| **AO-Core 1.5** | Message type system with BEAM file parsing | Remote device loading, trust verification, type-aware routing |

## Key Numbers

- **72 device modules** in HyperBEAM core
- **100 transfers in 1.7 seconds** (token device benchmark)
- **10,000 recipients in 655ms** (batch distribution)
- **O(n²) → O(n)** optimization for stake removals
- **Chi formula**: `Balance = Existing + (CurrentChi - InitialChi) × Deposit`

## Architecture Summary

```
┌─────────────────────────────────────────────────────────────┐
│                    M4 APPLICATION LAYER                      │
│  LiveNet Staking │ POT Minting │ HyperTokens │ Subledgers   │
├─────────────────────────────────────────────────────────────┤
│                    CORE DEVICE LAYER                         │
│  process@1.0 │ scheduler@1.0 │ push@1.0 │ trie@1.0          │
├─────────────────────────────────────────────────────────────┤
│                    EXECUTION LAYER                           │
│  wasm@1.0 │ genesis-wasm@1.0 │ lua@5.3a │ stack@1.0         │
├─────────────────────────────────────────────────────────────┤
│                    SECURITY LAYER                            │
│  snp@1.0 (SEV-SNP) │ poda@1.0 │ dedup@1.0 │ security@1.0    │
├─────────────────────────────────────────────────────────────┤
│                    PAYMENT LAYER                             │
│  p4@1.0 │ simple-pay@1.0 │ hyper-token.lua                  │
└─────────────────────────────────────────────────────────────┘
```

---

# Part 1: DECENTRALIZED SCHEDULERS

## 1.1 Overview

Decentralized Schedulers enable distributed message ordering across multiple HyperBEAM nodes, eliminating single points of failure and enabling horizontal scaling.

**Branches**: `impr/scheduler-assignments`, `impr/scheduler-proxy`, `feat/aos2-scheduler-formats`

## 1.2 Scheduler Device API

### Exported Functions

```erlang
%% Module: dev_scheduler.erl
-export([
    info/0,           %% Device metadata and routing config
    schedule/3,       %% Route scheduling requests (POST/GET)
    router/4,         %% Default request handler
    location/3,       %% Scheduler location management
    slot/3,           %% Current slot for process
    status/3,         %% Wallet and registry status
    next/3,           %% Next assignment with lookahead
    parse_schedulers/1, %% Parse scheduler location strings
    start/0,          %% Initialize RocksDB and random seed
    checkpoint/1      %% State persistence
]).
```

### Schedule Operation

```erlang
schedule(Msg1, Msg2, Opts) ->
    case hb_ao:get(<<"method">>, Msg2, <<"GET">>, Opts) of
        <<"POST">> -> post_schedule(Msg1, Msg2, Opts);
        <<"GET">>  -> get_schedule(Msg1, Msg2, Opts)
    end.
```

**POST /schedule**: Adds message to process schedule
- Validates message signatures
- Assigns sequential slot number
- Stores in local cache + optional Arweave upload
- Returns assignment with slot number

**GET /schedule**: Retrieves schedule assignments
- Supports slot range queries
- Returns assignments with bodies

## 1.3 Slot Normalization (impr/scheduler-assignments)

The scheduler normalizes slot values across different assignment formats:

```erlang
%% Legacy format conversion (AO-TN.1)
normalize_assignment(Assignment, Opts) ->
    case hb_ao:get(<<"nonce">>, Assignment, Opts) of
        not_found -> Assignment;
        Nonce ->
            %% Convert legacy nonce to standard slot
            Assignment#{<<"slot">> => hb_util:int(Nonce)}
    end.

%% Slot validation
validate_next_slot(NextAssignment, LastSlot, Opts) ->
    NextSlot = hb_util:int(hb_ao:get(<<"slot">>, NextAssignment, Opts)),
    ExpectedSlot = LastSlot + 1,
    case NextSlot of
        ExpectedSlot -> {ok, NextAssignment};
        _ -> {error, {slot_mismatch, ExpectedSlot, NextSlot}}
    end.
```

## 1.4 ANS-104 Assignment Wrapping

For legacy scheduler compatibility:

```erlang
post_remote_schedule(Process, Msg, SchedulerURL, Opts) ->
    %% Generate ANS-104 commitment
    WithANS104 = hb_message:with_commitments(Msg, <<"ans104@1.0">>, Opts),

    %% Serialize as Arweave bundle item
    Item = ar_bundles:serialize(WithANS104),

    %% POST to legacy scheduler endpoint
    case hb_http:post(SchedulerURL, <<"/schedule">>, Item, Opts) of
        {ok, Response} ->
            normalize_assignment(Response, Opts);
        {error, 422} ->
            %% Scheduler requires ANS-104 signatures
            {error, missing_ans104_signature}
    end.
```

## 1.5 Lookahead Caching Mechanism

Predictive assignment prefetching for reduced latency:

```erlang
-define(LOOKAHEAD_TIMEOUT, 1500). %% 1.5 seconds

%% Spawn background worker for next slot
spawn_lookahead_worker(ProcID, TargetSlot, Opts) ->
    spawn(fun() ->
        NextSlot = TargetSlot + 1,
        Result = fetch_assignment(ProcID, NextSlot, Opts),
        cache_assignment(ProcID, NextSlot, Result)
    end).

%% Check lookahead cache before remote fetch
check_lookahead_and_local_cache(ProcID, Slot, Opts) ->
    case get_lookahead_result(ProcID, Slot, ?LOOKAHEAD_TIMEOUT) of
        {ok, Assignment} ->
            %% Spawn next lookahead worker
            case hb_opts:get(scheduler_lookahead, true, Opts) of
                true -> spawn_lookahead_worker(ProcID, Slot, Opts);
                false -> ok
            end,
            {ok, Assignment};
        timeout ->
            %% Fall back to synchronous fetch
            fetch_assignment_sync(ProcID, Slot, Opts)
    end.
```

## 1.6 Decentralized Scheduler Registration (impr/scheduler-proxy)

### Registration Flow

```erlang
post_location(Msg1, Msg2, Opts) ->
    %% 1. Validate nonce progression
    ExistingLocation = dev_scheduler_cache:read_location(SchedulerID, Opts),
    NewNonce = hb_ao:get(<<"nonce">>, Msg2, Opts),
    case validate_nonce(NewNonce, ExistingLocation) of
        {error, Reason} -> {error, Reason};
        ok ->
            %% 2. Construct location message
            LocationMsg = #{
                <<"type">> => <<"Scheduler-Location">>,
                <<"url">> => hb_ao:get(<<"url">>, Msg2, Opts),
                <<"ttl">> => hb_ao:get(<<"ttl">>, Msg2, 3600, Opts),
                <<"nonce">> => NewNonce,
                <<"codec-device">> => hb_ao:get(<<"codec-device">>, Msg2,
                    <<"httpsig@1.0">>, Opts),
                <<"timestamp">> => erlang:system_time(millisecond)
            },

            %% 3. Sign with node wallet
            SignedLocation = hb_message:commit(LocationMsg, Opts),

            %% 4. Store locally
            dev_scheduler_cache:write_location(SchedulerID, SignedLocation, Opts),

            %% 5. Upload to Arweave (async)
            spawn(fun() -> hb_client:upload(SignedLocation, Opts) end),

            %% 6. Notify peers
            Peers = hb_opts:get(scheduler_location_notify_peers, [], Opts),
            lists:foreach(fun(Peer) ->
                hb_http:post(Peer, <<"/~scheduler@1.0/location">>,
                    SignedLocation, Opts)
            end, Peers),

            {ok, SignedLocation}
    end.
```

### Codec Negotiation

```erlang
%% Accept-codec header support
resolve_codec(Request, Opts) ->
    hb_ao:get(<<"accept-codec">>, Request, <<"httpsig@1.0">>, Opts).

%% Codec conversion on schedule
schedule_with_codec(Msg, TargetCodec, Opts) ->
    CurrentCodec = detect_codec(Msg),
    case {CurrentCodec, TargetCodec} of
        {Same, Same} -> {ok, Msg};
        {<<"httpsig@1.0">>, <<"ans104@1.0">>} ->
            %% Downgrade: re-sign as ANS-104
            convert_to_ans104(Msg, Opts);
        {<<"ans104@1.0">>, <<"httpsig@1.0">>} ->
            %% Upgrade: wrap in HTTPSig
            convert_to_httpsig(Msg, Opts)
    end.
```

### Location Resolution

```erlang
find_remote_scheduler(ProcessID, Opts) ->
    %% 1. Check local cache
    case dev_scheduler_cache:read_location(ProcessID, Opts) of
        {ok, Location} -> {ok, Location};
        not_found ->
            %% 2. Query gateway
            case hb_gateway:get_scheduler_location(ProcessID, Opts) of
                {ok, Location} ->
                    dev_scheduler_cache:write_location(ProcessID, Location, Opts),
                    {ok, Location};
                not_found ->
                    %% 3. Check process hints
                    case get_scheduler_hint(ProcessID, Opts) of
                        {ok, Hint} -> resolve_hint(Hint, Opts);
                        not_found -> {error, no_scheduler_found}
                    end
            end
    end.
```

---

# Part 2: LIVENET STAKING MARKETPLACE

## 2.1 Overview

LiveNet Staking implements a non-fungible stake vault system where each stake is tracked separately, preventing cooldown exploits and enabling fair FIFO-based unstaking.

**Branches**: `feat/livenet`, `feat/native-tokens`, `feat/token-device`, `wip/lucifer_livenet`

## 2.2 Core Data Structures

### Stakes Registry

```lua
-- Each address maps to array of stake vaults
Stakes = {
    ["address1"] = {
        {
            id = "stake_001",
            amount = 1000,
            lock_duration = 86400000,  -- 24 hours in ms
            stake_timestamp = 1706054400000
        },
        {
            id = "stake_002",
            amount = 500,
            lock_duration = 172800000,  -- 48 hours in ms
            stake_timestamp = 1706140800000
        }
    }
}
```

### Unstaking Registry (Dual-Indexed)

```lua
-- Index 1: By user address
Unstaking = {
    ["address1"] = {
        {
            id = "unstake_001",
            amount = 500,
            release_time = 1706227200000
        }
    }
}

-- Index 2: By release time (for batch processing)
UnstakingByTime = {
    [1706227200000] = {
        { address = "address1", id = "unstake_001", amount = 500 }
    },
    [1706313600000] = {
        { address = "address2", id = "unstake_002", amount = 300 }
    }
}
```

## 2.3 Staking Functions

### Stake (via Credit-Notice)

```lua
Handlers.add("Credit-Notice",
    function(msg) return msg.Action == "Credit-Notice" end,
    function(msg)
        -- Validate source is authorized token process
        assert(msg.From == TokenProcess, "Unauthorized token source")

        local sender = msg.Tags.Sender
        local amount = tonumber(msg.Tags.Quantity)
        local lock_duration = tonumber(msg.Tags["Lock-Duration"]) or DEFAULT_LOCK

        -- Create new stake vault (non-fungible)
        local stake_id = generate_stake_id()
        local stake = {
            id = stake_id,
            amount = amount,
            lock_duration = lock_duration,
            stake_timestamp = msg.Timestamp
        }

        -- Initialize user's stake array if needed
        if not Stakes[sender] then
            Stakes[sender] = {}
        end

        -- Append new stake (preserves individual vault identity)
        table.insert(Stakes[sender], stake)

        -- Emit event
        ao.send({
            Target = sender,
            Action = "Stake-Confirmation",
            ["Stake-ID"] = stake_id,
            Amount = tostring(amount),
            ["Lock-Duration"] = tostring(lock_duration)
        })
    end
)
```

### Unstake (FIFO Order)

```lua
Handlers.add("Unstake",
    function(msg) return msg.Action == "Unstake" end,
    function(msg)
        local sender = msg.From
        local requested_amount = tonumber(msg.Tags.Quantity)

        assert(Stakes[sender], "No stakes found")

        local remaining = requested_amount
        local unstake_entries = {}

        -- FIFO: Process oldest stakes first
        while remaining > 0 and #Stakes[sender] > 0 do
            local oldest_stake = Stakes[sender][1]

            if oldest_stake.amount <= remaining then
                -- Fully unstake this vault
                remaining = remaining - oldest_stake.amount
                table.insert(unstake_entries, {
                    id = oldest_stake.id,
                    amount = oldest_stake.amount,
                    release_time = msg.Timestamp + oldest_stake.lock_duration
                })
                table.remove(Stakes[sender], 1)  -- O(n) but necessary for FIFO
            else
                -- Partially unstake this vault
                oldest_stake.amount = oldest_stake.amount - remaining
                table.insert(unstake_entries, {
                    id = oldest_stake.id .. "_partial",
                    amount = remaining,
                    release_time = msg.Timestamp + oldest_stake.lock_duration
                })
                remaining = 0
            end
        end

        assert(remaining == 0, "Insufficient staked balance")

        -- Add to unstaking registries
        for _, entry in ipairs(unstake_entries) do
            -- Index by user
            if not Unstaking[sender] then
                Unstaking[sender] = {}
            end
            table.insert(Unstaking[sender], entry)

            -- Index by time (for auto_finalize optimization)
            if not UnstakingByTime[entry.release_time] then
                UnstakingByTime[entry.release_time] = {}
            end
            table.insert(UnstakingByTime[entry.release_time], {
                address = sender,
                id = entry.id,
                amount = entry.amount
            })
        end
    end
)
```

## 2.4 Security: Non-Fungible Stake Vaults

### Problem: Cooldown Exploit

With fungible staking, attackers can:
1. Stake 1000 tokens at T=0
2. At T=23h, request unstake of 1000 tokens (starts 24h cooldown)
3. At T=23h, stake another 1000 tokens
4. At T=47h, withdraw first 1000 (cooldown complete)
5. Repeat - effectively bypassing cooldown by rotating tokens

### Solution: Non-Fungible Vaults

```lua
-- Each stake is tracked individually with its own lock_duration
-- Unstaking follows FIFO order from OLDEST stakes
-- Cannot "jump the queue" with new stakes

-- Commit: 50b6579 (Oct 29, 2025)
-- "security: implement non-fungible stake vaults to prevent cooldown exploit"
```

## 2.5 Auto-Finalization (Time-Indexed Optimization)

### O(n²) → O(n) Optimization

```lua
-- OLD: Check every unstaking entry against current time
function auto_finalize_old(current_time)
    for address, entries in pairs(Unstaking) do
        for i, entry in ipairs(entries) do
            if entry.release_time <= current_time then
                -- Process withdrawal
            end
        end
    end
end
-- Complexity: O(users × entries_per_user)

-- NEW: Use time-indexed registry
function auto_finalize(current_time)
    -- Get all timestamps up to current time
    local ready_times = {}
    for timestamp, _ in pairs(UnstakingByTime) do
        if timestamp <= current_time then
            table.insert(ready_times, timestamp)
        end
    end

    -- Sort and process in order
    table.sort(ready_times)

    for _, timestamp in ipairs(ready_times) do
        local entries = UnstakingByTime[timestamp]

        -- Batch transfer to token process
        local batch = {}
        for _, entry in ipairs(entries) do
            table.insert(batch, {
                Recipient = entry.address,
                Quantity = tostring(entry.amount)
            })

            -- Remove from user's unstaking list
            remove_unstaking_entry(entry.address, entry.id)
        end

        -- Single batched transfer message
        ao.send({
            Target = TokenProcess,
            Action = "Batch-Transfer",
            Transfers = json.encode(batch)
        })

        -- Remove processed timestamp
        UnstakingByTime[timestamp] = nil
    end
end
-- Complexity: O(ready_entries) - only processes matured entries

-- Commit: f7b9f32 (Oct 29, 2025)
-- "performance: optimize auto_finalize with time-based index"
```

## 2.6 Slashing Mechanism

```lua
Handlers.add("Slash",
    function(msg) return msg.Action == "Slash" end,
    function(msg)
        -- Admin-only operation
        assert(msg.From == Admin, "Unauthorized: Admin only")

        local target = msg.Tags.Target
        local slash_amount = tonumber(msg.Tags.Quantity)

        assert(Stakes[target], "Target has no stakes")

        -- Calculate total staked
        local total_staked = 0
        for _, stake in ipairs(Stakes[target]) do
            total_staked = total_staked + stake.amount
        end

        assert(slash_amount <= total_staked, "Slash exceeds staked amount")

        -- Remove stakes FIFO (same as unstake but no cooldown)
        local remaining = slash_amount
        while remaining > 0 do
            local oldest = Stakes[target][1]
            if oldest.amount <= remaining then
                remaining = remaining - oldest.amount
                table.remove(Stakes[target], 1)
            else
                oldest.amount = oldest.amount - remaining
                remaining = 0
            end
        end

        -- Emit slash event
        ao.send({
            Target = target,
            Action = "Slashed",
            Quantity = tostring(slash_amount),
            Reason = msg.Tags.Reason or "Violation"
        })
    end
)
```

---

# Part 3: STREAMING TOKEN DISTRIBUTIONS

## 3.1 Overview

Streaming Token Distributions enable real-time, on-demand minting using the POT (Proof of Token) model - tokens are only minted when queried, eliminating computational overhead.

**Branches**: `feat/mint`, `expr/pot`, `feat/mint-indexes`, `ex/subledger-payments`

## 3.2 POT Device: Chi-Proportional Accumulation

### Core Mathematical Model

```
Let:
  χ (chi)     = cumulative yield per resource unit
  χ₀          = chi value at time of deposit
  D           = deposit amount
  B           = current balance
  M           = minted tokens
  S           = total supply
  R           = remaining mintable (cap - minted)
  p           = mint proportion per time-step
  t           = time steps elapsed

Formulas:
  1. Units minted in period:
     M = R × (1 - (1-p)^t)

  2. Yield per resource unit:
     Δχ = M / TotalDeposits

  3. User balance at time T:
     B = ExistingBalance + (χ_current - χ₀) × D
```

### Implementation

```erlang
%% Module: dev_pot.erl
-export([drip/3]).

%% Core drip function - calculates yield on-demand
drip(State, Req, Opts) ->
    %% Get timing parameters
    LastDrip = hb_ao:get(<<"last-drip">>, State, 0, Opts),
    CurrentTime = hb_ao:get(<<"timestamp">>, Req, erlang:system_time(millisecond), Opts),
    TimeSteps = (CurrentTime - LastDrip) div StepDuration,

    case TimeSteps > 0 of
        false -> {ok, State};  %% No time elapsed
        true ->
            %% Calculate minting
            Remaining = MintCap - hb_ao:get(<<"minted">>, State, 0, Opts),
            Proportion = hb_ao:get(<<"mint-prop">>, State, Opts),

            UnitsMinted = units_minted_between(Remaining, Proportion, TimeSteps),

            %% Update chi
            TotalDeposits = calculate_total_deposits(State, Opts),
            ChiDelta = case TotalDeposits of
                0 -> 0;
                _ -> UnitsMinted div TotalDeposits
            end,

            CurrentChi = hb_ao:get(<<"chi">>, State, 0, Opts),
            NewChi = CurrentChi + ChiDelta,

            %% Update state
            NewState = State#{
                <<"chi">> => NewChi,
                <<"minted">> => hb_ao:get(<<"minted">>, State, 0, Opts) + UnitsMinted,
                <<"last-drip">> => CurrentTime
            },

            {ok, NewState}
    end.

%% Exponential decay minting formula
units_minted_between(Remaining, Proportion, Steps) ->
    %% M = R × (1 - (1-p)^t)
    %% Using integer arithmetic for precision
    Factor = math:pow(1 - Proportion, Steps),
    Minted = Remaining * (1 - Factor),
    trunc(Minted).
```

### Balance Calculation

```erlang
%% Get user balance with accrued yield
get_balance(Address, State, Opts) ->
    Deposit = hb_ao:get([<<"deposits">>, Address], State, #{}, Opts),

    case Deposit of
        #{} -> 0;  %% No deposit
        #{<<"amount">> := Amount, <<"chi0">> := Chi0} ->
            ExistingBalance = hb_ao:get([<<"balances">>, Address], State, 0, Opts),
            CurrentChi = hb_ao:get(<<"chi">>, State, 0, Opts),

            %% B = Existing + (χ_current - χ₀) × D
            AccruedYield = (CurrentChi - Chi0) * Amount,
            ExistingBalance + AccruedYield
    end.
```

### Deposit Management

```erlang
%% Modify deposit with yield accrual
modify_deposit(Address, DeltaAmount, State, Req, Opts) ->
    %% 1. First accrue any pending yield
    {ok, StateAfterDrip} = drip(State, Req, Opts),

    %% 2. Get current deposit
    CurrentDeposit = hb_ao:get([<<"deposits">>, Address], StateAfterDrip,
        #{<<"amount">> => 0, <<"chi0">> => 0}, Opts),

    CurrentAmount = maps:get(<<"amount">>, CurrentDeposit),
    CurrentChi0 = maps:get(<<"chi0">>, CurrentDeposit),

    %% 3. Calculate and credit accrued yield
    CurrentChi = hb_ao:get(<<"chi">>, StateAfterDrip, 0, Opts),
    AccruedYield = (CurrentChi - CurrentChi0) * CurrentAmount,

    ExistingBalance = hb_ao:get([<<"balances">>, Address], StateAfterDrip, 0, Opts),
    NewBalance = ExistingBalance + AccruedYield,

    %% 4. Update deposit with new chi0
    NewAmount = CurrentAmount + DeltaAmount,
    NewDeposit = #{
        <<"amount">> => NewAmount,
        <<"chi0">> => CurrentChi  %% Reset chi0 to current
    },

    %% 5. Update state
    NewState = StateAfterDrip#{
        <<"deposits">> => maps:put(Address, NewDeposit,
            hb_ao:get(<<"deposits">>, StateAfterDrip, #{}, Opts)),
        <<"balances">> => maps:put(Address, NewBalance,
            hb_ao:get(<<"balances">>, StateAfterDrip, #{}, Opts))
    },

    {ok, NewState}.
```

## 3.3 Mint v3 Flow (feat/mint)

### Precision-Safe Distribution Mathematics

```erlang
%% Module: dev_mint_math.erl

%% CRITICAL: Multiplication BEFORE division to prevent precision loss
distribute_to_holder(TotalUnits, HolderQuantity, TotalQuantity) ->
    %% WRONG: (TotalUnits div TotalQuantity) * HolderQuantity
    %%        Could round to 0 if TotalUnits < TotalQuantity

    %% CORRECT: Multiply first, then divide
    (TotalUnits * HolderQuantity) div TotalQuantity.

%% Commit: e9892f0 (Nov 3, 2025)
%% "fix: prevent precision loss in proportional token distribution"
```

### Multi-Resource Weighted Distribution

```erlang
%% Distribute across multiple resource types with weights
distribute_cycle(State, CycleSupply, Opts) ->
    Resources = hb_ao:get(<<"resources">>, State, Opts),
    TotalWeight = lists:foldl(fun(R, Acc) ->
        Acc + hb_ao:get(<<"weight">>, R, 1, Opts)
    end, 0, Resources),

    %% Allocate to each resource proportionally
    lists:foldl(fun(Resource, AccState) ->
        Weight = hb_ao:get(<<"weight">>, Resource, 1, Opts),
        ResourceID = hb_ao:get(<<"id">>, Resource, Opts),

        %% Units for this resource (multiplication first!)
        UnitsForResource = (CycleSupply * Weight) div TotalWeight,

        %% Distribute to holders of this resource
        distribute_to_resource_holders(ResourceID, UnitsForResource, AccState, Opts)
    end, State, Resources).
```

### Dust Tracking

```erlang
%% Track unallocated units due to rounding
track_dust(Allocated, Total, State, Opts) ->
    Dust = Total - Allocated,
    CurrentDust = hb_ao:get(<<"dust">>, State, 0, Opts),
    State#{<<"dust">> => CurrentDust + Dust}.

%% Periodically redistribute dust
redistribute_dust(State, Opts) ->
    Dust = hb_ao:get(<<"dust">>, State, 0, Opts),
    case Dust > MinDustThreshold of
        true ->
            %% Add dust to next cycle's supply
            State#{
                <<"dust">> => 0,
                <<"pending-supply">> => Dust
            };
        false ->
            State
    end.
```

## 3.4 Token Device (feat/token-device)

### Fast Transfer Implementation

```erlang
%% Module: dev_token.erl
-export([transfer/3, mint/3, balance/3, info/3]).

transfer(State, Req, Opts) ->
    %% Extract parameters
    From = extract_sender(Req, Opts),
    Recipient = hb_ao:get(<<"recipient">>, Req, Opts),
    Quantity = hb_util:int(hb_ao:get(<<"quantity">>, Req, Opts)),

    %% Validation
    case Quantity >= 0 of
        false -> {error, <<"Invalid quantity">>};
        true ->
            FromBalance = get_balance(From, State, Opts),
            case FromBalance >= Quantity of
                false ->
                    {error, #{
                        <<"reason">> => <<"Insufficient balance">>,
                        <<"balance">> => FromBalance,
                        <<"requested">> => Quantity
                    }};
                true ->
                    %% Update balances via trie
                    State1 = update_balance(From, -Quantity, State, Opts),
                    State2 = update_balance(Recipient, Quantity, State1, Opts),

                    %% Generate notices
                    Notices = [
                        #{
                            <<"target">> => From,
                            <<"action">> => <<"Debit-Notice">>,
                            <<"quantity">> => Quantity,
                            <<"recipient">> => Recipient
                        },
                        #{
                            <<"target">> => Recipient,
                            <<"action">> => <<"Credit-Notice">>,
                            <<"quantity">> => Quantity,
                            <<"sender">> => From
                        }
                    ],

                    {ok, State2#{<<"outbox">> => Notices}}
            end
    end.
```

### Mint with Authority Checking

```erlang
mint(State, Req, Opts) ->
    %% Enforce mint authority
    Requester = hb_message:signers(Req, Opts),
    Authority = hb_ao:get(<<"mint-authority">>, State, Opts),

    case lists:member(Authority, Requester) of
        false ->
            {error, <<"Mint authority mismatch">>};
        true ->
            Recipient = hb_ao:get(<<"recipient">>, Req, Opts),
            Quantity = hb_util:int(hb_ao:get(<<"quantity">>, Req, Opts)),

            %% Update balance and total supply
            State1 = update_balance(Recipient, Quantity, State, Opts),
            CurrentSupply = hb_ao:get(<<"total-supply">>, State, 0, Opts),
            State2 = State1#{<<"total-supply">> => CurrentSupply + Quantity},

            {ok, State2}
    end.

%% Commit: Nov 5, 2025
%% "feat: implement secure_set action with authority checking"
```

### Benchmarks

```
%% Performance Results (Nov 5, 2025):
%% - 100 sequential transfers: 1.7 seconds
%% - 10,000 recipient batch distribution: 655 milliseconds
%% - Average: 17ms per transfer, 0.0655ms per recipient in batch

%% Commit: "fix: enabled benchmarks - 100 transfers in 1.7s, 10k recipients in 655ms"
```

## 3.5 HyperTokens: Peer Ledger System (ex/subledger-payments)

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    ROOT TOKEN LEDGER                     │
│  - No parent token reference                            │
│  - Authoritative source of truth                        │
│  - Rejects Credit-Notice (receives only via Transfer)   │
└─────────────────────────┬───────────────────────────────┘
                          │
        ┌─────────────────┼─────────────────┐
        ▼                 ▼                 ▼
┌───────────────┐ ┌───────────────┐ ┌───────────────┐
│  SUB-LEDGER A │ │  SUB-LEDGER B │ │  SUB-LEDGER C │
│  token = ROOT │ │  token = ROOT │ │  token = ROOT │
│  Accepts      │ │  Accepts      │ │  Accepts      │
│  Credit-Notice│ │  Credit-Notice│ │  Credit-Notice│
└───────────────┘ └───────────────┘ └───────────────┘
```

### Peer Registration

```lua
-- Bidirectional peer registration
Handlers.add("Register",
    function(msg) return msg.Action == "Register" end,
    function(msg)
        local peer_id = msg.From
        local peer_base = msg.Tags["From-Base"]
        local peer_authority = msg.Tags["From-Authority"]
        local peer_scheduler = msg.Tags["From-Scheduler"]

        -- Store peer information for validation
        Peers[peer_id] = {
            base = peer_base,
            authority = peer_authority,
            scheduler = peer_scheduler,
            registered_at = msg.Timestamp
        }

        -- Send reciprocal registration
        ao.send({
            Target = peer_id,
            Action = "Register-Remote",
            ["From-Base"] = ao.env.Process.Id,
            ["From-Authority"] = Authority,
            ["From-Scheduler"] = Scheduler
        })
    end
)
```

### Cross-Ledger Transfer

```lua
Handlers.add("Transfer",
    function(msg) return msg.Action == "Transfer" end,
    function(msg)
        local sender = msg.From
        local recipient = msg.Tags.Recipient
        local quantity = normalize_int(msg.Tags.Quantity)
        local route = msg.Tags.Route  -- Optional routing path

        -- Validate balance
        assert(Balances[sender] >= quantity, "Insufficient balance")

        if route then
            -- Routed transfer through peer ledgers
            local next_hop = parse_next_hop(route)
            assert(Peers[next_hop], "Unknown peer in route")

            -- Debit sender
            Balances[sender] = Balances[sender] - quantity

            -- Send to next hop with remaining route
            ao.send({
                Target = next_hop,
                Action = "Credit-Notice",
                Sender = sender,
                Quantity = tostring(quantity),
                Recipient = recipient,
                Route = remaining_route(route),
                -- Security fields for validation
                ["From-Base"] = ao.env.Process.Id,
                ["From-Authority"] = Authority,
                ["From-Scheduler"] = Scheduler
            })
        else
            -- Direct transfer (same ledger or to registered peer)
            if is_local_address(recipient) then
                -- Same ledger transfer
                Balances[sender] = Balances[sender] - quantity
                Balances[recipient] = (Balances[recipient] or 0) + quantity
            else
                -- Transfer to peer ledger
                assert(Peers[recipient], "Recipient not a registered peer")
                Balances[sender] = Balances[sender] - quantity
                ao.send({
                    Target = recipient,
                    Action = "Credit-Notice",
                    Sender = sender,
                    Quantity = tostring(quantity),
                    ["From-Base"] = ao.env.Process.Id,
                    ["From-Authority"] = Authority,
                    ["From-Scheduler"] = Scheduler
                })
            end
        end
    end
)
```

### Security Validation

```lua
-- Three-tier validation for incoming messages
function validate_message(msg)
    -- Tier 1: Assignment validation
    local assignment_valid = (
        msg.Tags["From-Scheduler"] == nil or
        satisfies_list_constraints(msg.Tags["From-Scheduler"],
            ao.env.Process.Tags["Scheduler"])
    )

    -- Tier 2: Request authorization
    local authority_valid = (
        msg.Tags["From-Authority"] == nil or
        satisfies_list_constraints(msg.Tags["From-Authority"],
            ao.env.Process.Tags["Authority"])
    )

    -- Tier 3: Peer ledger validation (for Credit-Notice)
    local peer_valid = true
    if msg.Action == "Credit-Notice" then
        peer_valid = is_from_trusted_peer(msg)
    end

    return assignment_valid and authority_valid and peer_valid
end

function is_from_trusted_peer(msg)
    local peer = Peers[msg.From]
    if not peer then return false end

    return (
        msg.Tags["From-Base"] == peer.base and
        msg.Tags["From-Authority"] == peer.authority and
        msg.Tags["From-Scheduler"] == peer.scheduler
    )
end

-- Commit: 19d7f70 (May 14, 2025)
-- "feat: support complex authority and scheduler matching in hyper-token"
```

### Multisig Scheduler Support

```lua
-- Support multiple scheduler signatures
function satisfies_list_constraints(provided, required)
    if type(required) == "string" then
        required = split_by_comma(required)
    end
    if type(provided) == "string" then
        provided = split_by_comma(provided)
    end

    -- Check if any provided value matches any required value
    for _, p in ipairs(provided) do
        for _, r in ipairs(required) do
            if p == r then return true end
        end
    end
    return false
end

-- Commit: f0ab0e1 (May 14, 2025)
-- "feat: support multisignature requests for schedulers"
```

---

# Part 4: AO-CORE 1.5 TYPE SYSTEM

## 4.1 Overview

AO-Core 1.5 introduces a message type system with BEAM file parsing, enabling type-aware routing, validation, and remote device loading with trust verification.

**Branch**: `expr/1.5`

## 4.2 Message-to-Function Resolution

```erlang
%% Module: hb_ao_device.erl

%% Hierarchical function lookup
message_to_fun(Key, Device, Opts) ->
    %% Resolution order:
    %% 1. Device specification or default device
    %% 2. Handler functions with override capability
    %% 3. Direct function exports
    %% 4. Default handlers
    %% 5. Fallback device references
    %% 6. Global defaults

    case find_handler(Key, Device, Opts) of
        {ok, Handler} -> {ok, Handler};
        not_found ->
            case find_exported_function(Key, Device, Opts) of
                {ok, Fun} -> {ok, Fun};
                not_found ->
                    case find_default_handler(Key, Device, Opts) of
                        {ok, Default} -> {ok, Default};
                        not_found ->
                            case find_fallback_device(Device, Opts) of
                                {ok, Fallback} ->
                                    message_to_fun(Key, Fallback, Opts);
                                not_found ->
                                    {error, {no_handler, Key, Device}}
                            end
                    end
            end
    end.
```

## 4.3 Remote Device Loading

```erlang
%% Load device from message ID with trust verification
load(DeviceID, Opts) when is_binary(DeviceID) ->
    %% Check if remote loading is enabled
    case hb_opts:get(load_remote_devices, false, Opts) of
        false ->
            {error, remote_device_loading_disabled};
        true ->
            %% Fetch device from cache/network
            case hb_cache:read(DeviceID, Opts) of
                {ok, DeviceMsg} ->
                    %% Verify content type
                    case hb_ao:get(<<"content-type">>, DeviceMsg, Opts) of
                        <<"application/beam">> ->
                            %% Verify trust
                            verify_and_load_beam(DeviceMsg, Opts);
                        Other ->
                            {error, {invalid_content_type, Other}}
                    end;
                not_found ->
                    {error, {device_not_found, DeviceID}}
            end
    end.

%% Trust verification
verify_and_load_beam(DeviceMsg, Opts) ->
    Signers = hb_message:signers(DeviceMsg, Opts),
    TrustedSigners = hb_opts:get(trusted_device_signers, [], Opts),

    %% Check if any signer is trusted
    Trusted = lists:any(fun(Signer) ->
        lists:member(Signer, TrustedSigners)
    end, Signers),

    case Trusted of
        false ->
            {error, {untrusted_device_signer, Signers}};
        true ->
            %% Verify compatibility
            case verify_compatibility(DeviceMsg, Opts) of
                ok ->
                    %% Load BEAM binary
                    BeamBinary = hb_ao:get(<<"body">>, DeviceMsg, Opts),
                    load_beam_binary(BeamBinary, Opts);
                {error, Reason} ->
                    {error, {incompatible_device, Reason}}
            end
    end.
```

## 4.4 BEAM File Parsing

```erlang
%% Parse BEAM file for type information
parse_beam_types(BeamBinary) ->
    %% Extract chunks from BEAM file
    {ok, {Module, Chunks}} = beam_lib:chunks(BeamBinary, [
        abstract_code,
        attributes,
        exports
    ]),

    %% Extract type specifications
    Types = case proplists:get_value(abstract_code, Chunks) of
        {raw_abstract_v1, Forms} ->
            extract_type_specs(Forms);
        no_abstract_code ->
            []
    end,

    %% Extract exported functions
    Exports = proplists:get_value(exports, Chunks, []),

    %% Extract custom attributes
    Attributes = proplists:get_value(attributes, Chunks, []),

    #{
        module => Module,
        types => Types,
        exports => Exports,
        attributes => Attributes
    }.

%% Extract -spec declarations
extract_type_specs(Forms) ->
    lists:filtermap(fun
        ({attribute, _, spec, {{Name, Arity}, TypeSpecs}}) ->
            {true, {Name, Arity, TypeSpecs}};
        (_) ->
            false
    end, Forms).
```

## 4.5 Compatibility Verification

```erlang
%% Verify device compatibility with system
verify_compatibility(DeviceMsg, Opts) ->
    %% Extract requirements from device metadata
    Info = hb_ao:get(<<"info">>, DeviceMsg, #{}, Opts),
    Requirements = maps:filter(fun(Key, _) ->
        binary:match(Key, <<"requires-">>) =/= nomatch
    end, Info),

    %% Check each requirement
    Results = maps:map(fun(Key, Required) ->
        %% Extract property name (remove "requires-" prefix)
        PropName = binary:replace(Key, <<"requires-">>, <<>>),

        %% Get system value
        SystemValue = case PropName of
            <<"otp-version">> ->
                list_to_binary(erlang:system_info(otp_release));
            <<"erts-version">> ->
                list_to_binary(erlang:system_info(version));
            <<"hb-version">> ->
                hb:version();
            Other ->
                erlang:system_info(binary_to_atom(Other))
        end,

        %% Compare
        case SystemValue of
            Required -> ok;
            _ -> {mismatch, Required, SystemValue}
        end
    end, Requirements),

    %% Check for any mismatches
    Failures = maps:filter(fun(_, V) -> V =/= ok end, Results),
    case maps:size(Failures) of
        0 -> ok;
        _ -> {error, {requirements_not_met, Failures}}
    end.
```

## 4.6 Export Control

```erlang
%% Check if function is exported by device
is_exported(Key, Device, Opts) ->
    is_exported(Key, Device, default, Opts).

is_exported(Key, Device, Arity, Opts) ->
    %% info function is always exported if it exists
    case Key of
        <<"info">> -> true;
        _ ->
            Info = device_info(Device, Opts),
            Excludes = maps:get(excludes, Info, []),
            Exports = maps:get(exports, Info, all),

            %% Check excludes list first
            case lists:member(Key, Excludes) of
                true -> false;
                false ->
                    %% Check exports list
                    case Exports of
                        all -> true;
                        List when is_list(List) ->
                            lists:member(Key, List) orelse
                            lists:member({Key, Arity}, List)
                    end
            end
    end.
```

## 4.7 Type-Aware Routing

```erlang
%% Route message based on type
route_by_type(Msg, State, Opts) ->
    %% Extract message type
    MsgType = hb_ao:get(<<"type">>, Msg, <<"Message">>, Opts),

    %% Get type handlers from state
    TypeHandlers = hb_ao:get(<<"type-handlers">>, State, #{}, Opts),

    case maps:get(MsgType, TypeHandlers, undefined) of
        undefined ->
            %% No specific handler, use default
            route_default(Msg, State, Opts);
        Handler ->
            %% Validate message against type schema
            case validate_type(Msg, MsgType, Opts) of
                ok ->
                    %% Route to type-specific handler
                    hb_ao:resolve(Handler, Msg, Opts);
                {error, ValidationErrors} ->
                    {error, #{
                        <<"reason">> => <<"Type validation failed">>,
                        <<"type">> => MsgType,
                        <<"errors">> => ValidationErrors
                    }}
            end
    end.

%% Validate message against type schema
validate_type(Msg, TypeName, Opts) ->
    %% Get type schema
    Schema = get_type_schema(TypeName, Opts),

    %% Check required fields
    RequiredFields = maps:get(required, Schema, []),
    MissingFields = lists:filter(fun(Field) ->
        hb_ao:get(Field, Msg, not_found, Opts) =:= not_found
    end, RequiredFields),

    case MissingFields of
        [] ->
            %% Check field types
            validate_field_types(Msg, Schema, Opts);
        _ ->
            {error, {missing_fields, MissingFields}}
    end.
```

---

# Part 5: COMPLETE DEVICE API REFERENCE

## 5.1 Process Device (dev_process.erl)

```erlang
%% Exported Functions
-export([
    info/1,              %% Device metadata
    as/3,                %% Device swapping for delegation
    compute/3,           %% State computation
    schedule/3,          %% Message scheduling
    slot/3,              %% Current slot query
    now/3,               %% Latest results
    push/3,              %% Message push
    snapshot/3,          %% State snapshot
    ensure_process_key/2,%% Process key normalization
    as_process/2,        %% Convert to process format
    process_id/3         %% Get process ID
]).

%% info/1 - Returns device metadata
info(_Msg1) ->
    #{
        worker => fun dev_process_worker:server/3,
        grouper => fun dev_process_worker:group/3,
        await => fun dev_process_worker:await/5,
        excludes => [<<"test">>, <<"init">>, ...]
    }.

%% as/3 - Swap device for delegation
as(RawMsg1, Msg2, Opts) ->
    Key = get_as_key(Msg2, Opts),  %% "scheduler", "execution", etc.
    Device = get_device_for_key(Key, Msg1, Opts),
    {ok, Msg1#{<<"device">> => Device, <<"input-prefix">> => <<"process">>}}.

%% compute/3 - Execute computation
compute(Msg1, Msg2, Opts) ->
    case get_target_slot(Msg2, Opts) of
        not_found -> now(Msg1, Msg2, Opts);
        Slot -> compute_to_slot(ProcID, Msg1, Msg2, Slot, Opts)
    end.
```

## 5.2 Scheduler Device (dev_scheduler.erl)

```erlang
-export([
    info/0,              %% Device metadata
    schedule/3,          %% Route scheduling (GET/POST)
    router/4,            %% Default handler
    location/3,          %% Location management
    slot/3,              %% Current slot
    status/3,            %% Status query
    next/3,              %% Next assignment
    parse_schedulers/1,  %% Parse location strings
    start/0,             %% Initialize
    checkpoint/1         %% Persistence
]).
```

## 5.3 Push Device (dev_push.erl)

```erlang
-export([push/3]).

%% push/3 - Recursive message propagation
push(Base, Req, Opts) ->
    Process = as_process(Base, Opts),
    case get_slot(Req, Opts) of
        no_slot ->
            %% Schedule and push initial message
            {ok, Assignment} = schedule_initial_message(Process, Req, Opts),
            push_with_mode(Process, Assignment, Opts);
        Slot ->
            %% Push existing slot
            push_with_mode(Process, Req, Opts)
    end.
```

## 5.4 Trie Device (dev_trie.erl)

```erlang
-export([
    insert/4,    %% Insert key-value
    retrieve/3,  %% Get value by key
    keys/2,      %% List all keys
    remove/3,    %% Delete key
    update/4     %% Batch update
]).

%% Radix-256 trie operations
-define(RADIX, 256).
```

## 5.5 Payment Device (dev_p4.erl)

```erlang
-export([
    request/3,   %% Pre-execution validation
    response/3,  %% Post-execution charging
    balance/3    %% Balance query
]).
```

## 5.6 Simple Pay Device (dev_simple_pay.erl)

```erlang
-export([
    estimate/3,  %% Cost estimation
    price/3,     %% Final pricing
    charge/3,    %% Account debit
    balance/3,   %% Balance query
    topup/3      %% Account credit (operator only)
]).
```

## 5.7 SNP Device (dev_snp.erl)

```erlang
-export([
    generate/3,  %% Generate attestation report
    verify/3     %% Verify attestation report
]).

%% Verification steps:
%% 1. verify_nonce/4
%% 2. verify_signature_and_address/3
%% 3. verify_debug_disabled/1
%% 4. verify_trusted_software/3
%% 5. verify_measurement/3
%% 6. verify_report_integrity/1
```

## 5.8 PoDA Device (dev_poda.erl)

```erlang
-export([
    init/3,           %% Initialize
    validate/3,       %% Validate incoming message
    add_commitments/3 %% Add peer commitments
]).
```

## 5.9 Dedup Device (dev_dedup.erl)

```erlang
-export([info/1]).

%% Deduplication via seen-list
handle(Key, M1, M2, Opts) ->
    SubjectID = compute_subject_id(M1, M2, Opts),
    case is_seen(SubjectID, M1) of
        true  -> {skip, M1};
        false -> {ok, add_to_seen(M1, SubjectID)}
    end.
```

## 5.10 Stack Device (dev_stack.erl)

```erlang
-export([
    info/1,
    init/3,
    compute/3,
    snapshot/3,
    normalize/3
]).

%% Execution modes: fold (sequential) or map (parallel)
%% Special returns: skip, pass
```

## 5.11 WASM Device (dev_wasm.erl)

```erlang
-export([
    info/1,
    init/3,       %% Boot WASM image
    compute/3,    %% Call WASM function
    snapshot/3,   %% Serialize memory
    normalize/3,  %% Restore from snapshot
    terminate/3   %% Teardown
]).
```

## 5.12 Codec Devices (14 modules)

```erlang
%% dev_codec_ans104.erl - Arweave bundle format
%% dev_codec_httpsig.erl - HTTP Signature
%% dev_codec_json.erl - JSON serialization
%% dev_codec_flat.erl - Simplified encoding
%% dev_codec_cookie.erl - Session management
%% dev_codec_structured.erl - Structured fields
%% ... and 8 more
```

---

# Part 6: CONFIGURATION REFERENCE

## 6.1 Process Configuration

```
Device: Process/1.0
Scheduler-Device: Scheduler/1.0
Execution-Device: Stack/1.0
Execution-Stack: "Scheduler/1.0", "Cron/1.0", "WASM/1.0", "PoDA/1.0"
Cache-Frequency: 10
Cache-Keys: ["results", "state"]
```

## 6.2 Scheduler Configuration

```erlang
#{
    scheduler_lookahead => true,
    scheduler_location_notify_peers => ["http://peer1:8080", "http://peer2:8080"],
    scheduler_follow_hints => true
}
```

## 6.3 Payment Configuration

```erlang
#{
    p4_pricing_device => <<"simple-pay@1.0">>,
    p4_ledger_device => <<"lua@5.3a">>,
    p4_non_chargable_routes => [
        #{<<"template">> => <<"/~p4@1.0/balance">>},
        #{<<"template">> => <<"/~meta@1.0/*">>}
    ],
    p4_recipient => OperatorAddress
}
```

## 6.4 LiveNet Configuration

```lua
TokenProcess = "..."      -- Token contract address
Admin = "..."             -- Admin wallet address
DEFAULT_LOCK = 86400000   -- 24 hours in milliseconds
```

## 6.5 POT Configuration

```erlang
#{
    <<"mint-cap">> => 1000000000,     %% Total mintable tokens
    <<"mint-prop">> => 0.0001,        %% Proportion per time-step
    <<"step-duration">> => 60000,     %% 1 minute per step
    <<"chi">> => 0,                   %% Initial chi value
    <<"minted">> => 0,                %% Initial minted amount
    <<"last-drip">> => 0              %% Initial timestamp
}
```

---

# Appendix A: Commit References

| Feature | Key Commits |
|---------|-------------|
| Non-fungible stake vaults | 50b6579 (Oct 29, 2025) |
| O(n²) → O(n) optimization | 6cafa14 (Oct 29, 2025) |
| Time-indexed auto_finalize | f7b9f32 (Oct 29, 2025) |
| Precision loss prevention | e9892f0 (Nov 3, 2025) |
| Mint v3 flow | 379aaa2 (Nov 1, 2025) |
| POT real-time minting | 0e6dc00 (Nov 5, 2025) |
| Multi-asset POT | 861c646 (Nov 5, 2025) |
| Token benchmarks | Nov 5, 2025 |
| Multisig schedulers | f0ab0e1 (May 14, 2025) |
| Peer ledgers | 5d0324a (May 13, 2025) |
| NCC Audit | 27730ba (Feb 23, 2025) |
| Slot normalization | ecdfc32 (Aug 28, 2025) |

---

# Appendix B: Branch Index

| Branch | Owner | Focus |
|--------|-------|-------|
| impr/scheduler-assignments | samuelmanzanera | Slot normalization, ANS-104 wrapping |
| impr/scheduler-proxy | samcamwilliams | Registration, codec support |
| feat/aos2-scheduler-formats | - | AOS2 format compatibility |
| feat/livenet | Lucifer0x17 | Core staking implementation |
| feat/native-tokens | samcamwilliams | Token economy |
| feat/token-device | Lucifer0x17 | Token@1.0 device |
| wip/lucifer_livenet | Lucifer0x17, parthks | LiveNet device testing |
| feat/mint | samcamwilliams, Lucifer0x17 | Mint v3 implementation |
| expr/pot | samcamwilliams | POT minting model |
| feat/mint-indexes | samcamwilliams | Mint subscription |
| ex/subledger-payments | samcamwilliams | Peer ledgers, multisig |
| expr/1.5 | samcamwilliams | AO-Core 1.5 type system |

---

**Document Version**: 1.0.0
**Generated**: January 24, 2026
**Source**: HyperBEAM repository analysis (198 branches, 500+ commits)
