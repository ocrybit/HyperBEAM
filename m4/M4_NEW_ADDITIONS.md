# HyperBEAM M4: NEW Additions Since v0.9-milestone-3-beta-3

**Base Release**: v0.9-milestone-3-beta-3 (October 2, 2025)
**Document Date**: January 24, 2026

---

# TL;DR

| New Component | Type | Branch | Purpose |
|---------------|------|--------|---------|
| `dev_pot.erl` | Device | expr/pot | Real-time on-demand minting via chi-proportional model |
| `dev_mint.erl` | Device | expr/pot | Cycle-based minting orchestration |
| `dev_token.erl` | Device | expr/pot | Fast AO token with trie-based balances |
| `dev_mint_math.erl` | Module | expr/pot | Precision-safe distribution mathematics |
| `dev_livenet.erl` | Device | feat/livenet | Scheduler staking and availability monitoring |
| `livenet.lua` | Script | feat/livenet | Non-fungible stake vaults with FIFO unstaking |
| `hyper-token.lua` | Script | ex/subledger-payments | Peer ledger and cross-ledger transfers |
| `scheduler location/3` | Function | impr/scheduler-proxy | Decentralized scheduler registration |

**Key Innovation**: Tokens minted on-demand (not pre-computed), reducing compute overhead to zero until withdrawal.

---

# Part 1: NEW ERLANG DEVICES

## 1.1 pot@1.0 - Proof of Token Device

**File**: `src/dev_pot.erl`
**Branch**: `expr/pot`

### Purpose
Implements real-time on-demand minting where tokens are only calculated when queried, eliminating continuous computation overhead.

### Exported Interface

| Function | Signature | Description |
|----------|-----------|-------------|
| `drip` | `drip(State, Req, Opts) → {ok, NewState}` | Calculates and applies pending token yield |

### State Schema

| Key | Type | Description |
|-----|------|-------------|
| `t` | integer | Current time (block height or timestamp) |
| `last-drip` | integer | Last time drip was calculated |
| `chi` | float | Cumulative yield per deposited unit |
| `mint-cap` | integer | Maximum total supply |
| `mint-prop` | float | Proportion minted per time-step (0.0001 = 0.01%) |
| `minted` | integer | Total tokens minted to date |
| `resources` | map | Resource pools with weights and deposits |
| `balances` | map | Credited balances by address |

### Mathematical Model

**Minting Formula**: `M = Remaining × (1 - (1-p)^steps)`
- `Remaining` = mint-cap - minted
- `p` = mint-prop (e.g., 0.0001)
- `steps` = time elapsed since last-drip

**Chi Accumulation**: `Δχ = TokensMinted / TotalDeposits`

**Balance Calculation**: `Balance = ExistingBalance + (χ_current - χ₀) × Deposit`
- `χ₀` = chi value when user deposited

### Behavior
1. When `drip/3` called, checks if time elapsed since `last-drip`
2. If no time elapsed, returns state unchanged (zero compute)
3. If time elapsed, calculates tokens to mint using exponential decay
4. Updates chi value proportionally to total deposits
5. User balances calculated on-demand using chi difference

---

## 1.2 mint@1.0 - Minting Orchestrator

**File**: `src/dev_mint.erl`
**Branch**: `expr/pot`

### Purpose
Orchestrates multi-cycle minting with security enforcement. Delegates to `dev_mint_math` for calculations.

### Exported Interface

| Function | Signature | Description |
|----------|-----------|-------------|
| `compute` | `compute(State, Req, Opts) → {ok, NewState}` | Execute minting cycles with security check |

### Behavior
1. Delegates to `security@1.0` device for authorization
2. Calls `dev_mint_math:should_mint/3` to check if cycle needed
3. If yes, calls `dev_mint_math:mint/3` to execute
4. Recursively checks for additional cycles until complete

### Related Module: dev_mint_math.erl

| Function | Description |
|----------|-------------|
| `should_mint/3` | Returns true if minting cycle should execute |
| `mint/3` | Executes one minting cycle, returns new state |

**Precision Protection**: All calculations use multiplication before division to prevent rounding to zero on small amounts.

---

## 1.3 token@1.0 - Fast AO Token

**File**: `src/dev_token.erl`
**Branch**: `expr/pot`

### Purpose
High-performance token implementation using trie-based balance storage. Benchmarked at 100 transfers/1.7s.

### Exported Interface

| Function | Signature | Description |
|----------|-----------|-------------|
| `compute` | `compute(State, Req, Opts) → {ok, NewState}` | Route to action handler |

### Actions (via `action` key)

| Action | Parameters | Description |
|--------|------------|-------------|
| `Transfer` | `recipient`, `quantity` | Transfer tokens between addresses |
| `Mint` | `recipient`, `quantity` OR `quantities` (map) | Mint new tokens (authority required) |
| `Balance` | `target` | Query single balance |
| `Balances` | - | Query all balances |

### State Schema

| Key | Type | Description |
|-----|------|-------------|
| `balances` | trie | Address → balance mapping (via trie@1.0) |
| `mint-authority` | address | Only this address can mint |
| `total-supply` | integer | Current total supply |

### Outputs
- `Credit-Notice` sent to recipient on transfer
- `Debit-Notice` sent to sender on transfer

### Performance
- Sequential: 17ms per transfer
- Batch: 0.0655ms per recipient (15x improvement)

---

## 1.4 livenet@1.0 - Scheduler Staking

**File**: `src/dev_livenet.erl`
**Branch**: `feat/livenet`

### Purpose
Manages scheduler registration with staking requirements and availability monitoring.

### Exported Interface

| Function | Signature | Description |
|----------|-----------|-------------|
| `info` | `info(Msg1) → map()` | Device metadata |
| `info` | `info(State, Req, Opts) → {ok, InfoMap}` | HTTP info response |
| `join_network` | `join_network(State, Req, Opts) → {ok, NewState}` | Register scheduler with stake |
| `schedule` | `schedule(State, Req, Opts) → {ok, Assignment}` | Schedule with monitoring |

### join_network Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `scheduler-id` | binary | Unique scheduler identifier |
| `stake-amount` | integer | AO tokens to stake |
| `lock-duration` | integer | Lock period in milliseconds |
| `max-penalties-per-epoch` | integer | Slashing threshold |
| `token-per-failed-request` | integer | Penalty amount per failure |
| `min-complainers` | integer | Minimum reports for slashing |

### State Schema

| Key | Type | Description |
|-----|------|-------------|
| `schedulers` | map | Registered schedulers with stake info |

---

# Part 2: NEW LUA SCRIPTS

## 2.1 livenet.lua - Stake Vault System

**Branch**: `feat/livenet`

### Purpose
Non-fungible stake management preventing cooldown exploits through individual vault tracking.

### Handlers

| Handler | Trigger | Description |
|---------|---------|-------------|
| `Credit-Notice` | Incoming stake | Creates new stake vault with unique ID |
| `Unstake` | User request | FIFO removal from oldest stakes |
| `Slash` | Admin action | Immediate removal without cooldown |

### Data Structures

**Stakes** (by address):
```
address → [ {id, amount, lock_duration, stake_timestamp}, ... ]
```

**Unstaking** (dual-indexed):
```
By Address: address → [ {id, amount, release_time}, ... ]
By Time: timestamp → [ {address, id, amount}, ... ]
```

### Key Features

| Feature | Description |
|---------|-------------|
| Non-fungible vaults | Each stake tracked separately, prevents cooldown gaming |
| FIFO unstaking | Oldest stakes processed first |
| Time-indexed registry | O(n) auto_finalize vs O(n²) naive approach |
| Batch finalization | Single message for all matured unstakes |

### Security: Cooldown Exploit Prevention

**Problem**: With fungible staking, users can stake new tokens and unstake old ones to bypass cooldown.

**Solution**: Each stake is a separate vault with its own lock_duration. Unstaking processes oldest-first, so new stakes cannot "jump the queue."

---

## 2.2 hyper-token.lua - Peer Ledger System

**Branch**: `ex/subledger-payments`

### Purpose
Enables cross-ledger transfers and peer-to-peer token routing.

### NEW Handlers

| Handler | Trigger | Description |
|---------|---------|-------------|
| `Register` | Peer request | Establish bidirectional peer relationship |
| `Register-Remote` | Response | Complete peer registration |
| `Transfer` | User request | Transfer with optional routing |
| `Credit-Notice` | Peer transfer | Receive cross-ledger credit |

### Peer Registration Flow

1. Ledger A sends `Register` to Ledger B with security parameters
2. Ledger B stores A's parameters and sends `Register-Remote` back
3. Both ledgers can now validate transfers from each other

### Transfer Modes

| Mode | Condition | Behavior |
|------|-----------|----------|
| Same-ledger | Recipient is local | Direct balance update |
| Peer transfer | Recipient is registered peer | Send Credit-Notice with security fields |
| Routed transfer | `route` parameter provided | Multi-hop through peer chain |

### Security Fields

| Field | Purpose |
|-------|---------|
| `From-Base` | Source ledger's process ID |
| `From-Authority` | Source's signing authority |
| `From-Scheduler` | Source's scheduler(s) |

### Validation Tiers

| Tier | What's Checked |
|------|----------------|
| 1. Assignment | Message scheduler matches process scheduler |
| 2. Authority | Message authority matches process authority |
| 3. Peer | Credit-Notice sender is registered peer with matching security |

### Multisig Support
Scheduler and authority fields can be comma-separated lists. Any match satisfies the constraint.

---

# Part 3: NEW FUNCTIONS IN EXISTING DEVICES

## 3.1 scheduler@1.0 - Location Registration

**Branch**: `impr/scheduler-proxy`

### NEW Exported Functions

| Function | Signature | Description |
|----------|-----------|-------------|
| `location` | `location(Msg1, Msg2, Opts) → {ok, Location}` | GET/POST scheduler location |

### POST /location Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `url` | binary | required | Scheduler HTTP endpoint |
| `ttl` | integer | 3600 | Time-to-live in seconds |
| `nonce` | integer | required | Monotonic counter (replay prevention) |
| `codec-device` | binary | `httpsig@1.0` | Preferred message codec |

### Registration Flow

1. Validate nonce > existing nonce (prevent replay)
2. Construct location message with timestamp
3. Sign with node wallet
4. Store in local cache
5. Upload to Arweave (async)
6. Notify configured peers

### Configuration

| Option | Type | Description |
|--------|------|-------------|
| `scheduler_location_notify_peers` | list | Peer URLs to notify on registration |
| `scheduler_follow_hints` | boolean | Extract scheduler URL from process hints |

---

## 3.2 scheduler@1.0 - Slot Normalization

**Branch**: `impr/scheduler-assignments`

### Purpose
Standardizes assignment formats between legacy (AO-TN.1) and current protocol.

### Changes

| Change | Description |
|--------|-------------|
| Nonce → Slot | Converts legacy `nonce` field to standard `slot` |
| ANS-104 wrapping | Wraps message bodies for legacy scheduler compatibility |

---

## 3.3 scheduler@1.0 - Lookahead Caching

**Branch**: Various

### Purpose
Predictive prefetching of next assignments to reduce latency.

### Mechanism

| Step | Description |
|------|-------------|
| 1 | On successful fetch, spawn worker for slot+1 |
| 2 | Worker fetches and caches next assignment |
| 3 | On next request, check worker result first (1.5s timeout) |
| 4 | If timeout, fall back to synchronous fetch |

### Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `scheduler_lookahead` | boolean | true | Enable prefetching |

---

# Part 4: SUMMARY TABLE

## New Devices

| Device | Exported Functions | State Keys |
|--------|-------------------|------------|
| `pot@1.0` | `drip/3` | t, chi, mint-cap, mint-prop, minted, resources, balances |
| `mint@1.0` | `compute/3` | Delegates to mint_math |
| `token@1.0` | `compute/3` | balances (trie), mint-authority, total-supply |
| `livenet@1.0` | `info/1`, `info/3`, `join_network/3`, `schedule/3` | schedulers |

## New Lua Handlers

| Script | New Handlers |
|--------|--------------|
| `livenet.lua` | Credit-Notice (stake), Unstake (FIFO), Slash |
| `hyper-token.lua` | Register, Register-Remote, Credit-Notice (peer) |

## New Scheduler Functions

| Function | Purpose |
|----------|---------|
| `location/3` | Decentralized scheduler registration |
| Slot normalization | Legacy format compatibility |
| Lookahead caching | Latency reduction via prefetching |

---

# Appendix: Key Commits

| Feature | Commit | Date |
|---------|--------|------|
| Non-fungible stake vaults | 50b6579 | Oct 29, 2025 |
| O(n) auto_finalize | f7b9f32 | Oct 29, 2025 |
| Mint v3 flow | 379aaa2 | Nov 1, 2025 |
| Precision loss fix | e9892f0 | Nov 3, 2025 |
| POT real-time minting | 0e6dc00 | Nov 5, 2025 |
| Peer ledgers | 5d0324a | May 13, 2025 |
| Multisig schedulers | f0ab0e1 | May 14, 2025 |
| Slot normalization | ecdfc32 | Aug 28, 2025 |
