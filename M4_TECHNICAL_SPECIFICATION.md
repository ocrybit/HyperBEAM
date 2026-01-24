# HyperBEAM M4 Technical Specification
## Decentralized Schedulers, LiveNet Staking, Streaming Token Distributions & AO-Core 1.5

**Version**: 1.0.0
**Date**: January 24, 2026
**Status**: Pre-Release Analysis

---

# TL;DR

## M4 Feature Summary

| Feature | What It Does | Key Innovation |
|---------|--------------|----------------|
| **Decentralized Schedulers** | Distributed message ordering across multiple nodes | Lookahead caching, nonce-based registration, peer notification |
| **LiveNet Staking** | Non-fungible stake vaults with FIFO unstaking | Cooldown exploit prevention, O(n) time-indexed finalization |
| **Streaming Tokens** | Real-time on-demand minting (POT model) | Chi-proportional accumulation, zero computation until query |
| **AO-Core 1.5** | Message type system with BEAM file parsing | Remote device loading, trust verification, type-aware routing |

## Performance Benchmarks

| Metric | Value |
|--------|-------|
| Token transfers (sequential) | 100 in 1.7 seconds (17ms each) |
| Token transfers (batch) | 10,000 recipients in 655ms (0.065ms each) |
| Stake removal optimization | O(n²) → O(n) |
| Scheduler lookahead timeout | 1.5 seconds |

## Core Formulas

| Formula | Purpose |
|---------|---------|
| `M = R × (1 - (1-p)^t)` | Tokens minted over time period |
| `Δχ = M / TotalDeposits` | Chi increment per resource unit |
| `B = Existing + (χ_now - χ₀) × D` | User balance with accrued yield |

---

# Part 1: DECENTRALIZED SCHEDULERS

## 1.1 Overview

Decentralized Schedulers distribute message ordering across multiple HyperBEAM nodes, eliminating single points of failure. Each scheduler registers its location on Arweave and notifies peers, enabling automatic discovery and failover.

**Related Branches**: `impr/scheduler-assignments`, `impr/scheduler-proxy`, `feat/aos2-scheduler-formats`

## 1.2 Scheduler Device Interface

### Exported Functions

| Function | Purpose |
|----------|---------|
| `info/0` | Returns device metadata and routing configuration |
| `schedule/3` | Routes scheduling requests based on HTTP method (GET retrieves, POST adds) |
| `router/4` | Default request handler for unmatched routes |
| `location/3` | Manages scheduler location registration and queries |
| `slot/3` | Returns current slot number for a process |
| `status/3` | Returns scheduler wallet address and process registry status |
| `next/3` | Fetches next assignment with lookahead optimization |
| `parse_schedulers/1` | Parses comma-separated scheduler location strings |
| `start/0` | Initializes RocksDB storage and random seed |
| `checkpoint/1` | Persists scheduler state |

### Schedule Operation

The schedule function behaves differently based on HTTP method:
- **GET**: Retrieves existing assignments from the schedule, supports slot range queries
- **POST**: Validates message signatures, assigns sequential slot number, stores locally and optionally uploads to Arweave

## 1.3 Slot Normalization

### Problem
Legacy AO-TN.1 schedulers use a `nonce` field instead of `slot`, causing compatibility issues.

### Solution
The scheduler automatically detects and converts legacy format:
- Extracts `nonce` field from incoming assignments
- Converts to integer and stores as `slot`
- Wraps message bodies with ANS-104 commitments when required by legacy schedulers

### Validation
Each assignment's slot is validated against expected sequential progression. Mismatches return detailed error information including expected vs actual slot numbers.

## 1.4 Lookahead Caching Mechanism

### Purpose
Reduces latency by predictively fetching the next assignment before it's requested.

### How It Works

1. **Worker Spawning**: When an assignment is successfully fetched, a background Erlang process is spawned to fetch slot+1
2. **Caching**: The worker stores results in local cache upon completion
3. **Retrieval**: Next request checks for cached worker results first (1.5 second timeout)
4. **Fallback**: If timeout expires, falls back to synchronous fetch
5. **Continuation**: Successful cache hits trigger spawning of next worker, maintaining the pipeline

### Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `scheduler_lookahead` | boolean | true | Enable/disable prefetching |

## 1.5 Decentralized Location Registration

### Registration Flow

1. **Nonce Validation**: New nonce must exceed existing cached nonce (prevents replay attacks)
2. **Message Construction**: Creates Scheduler-Location message with URL, TTL, nonce, codec preference, and timestamp
3. **Signing**: Signs message with node's wallet
4. **Local Storage**: Stores in scheduler cache for immediate availability
5. **Arweave Upload**: Asynchronously uploads to permanent storage
6. **Peer Notification**: POSTs location to all configured peer URLs

### Location Message Fields

| Field | Type | Description |
|-------|------|-------------|
| `type` | string | Always "Scheduler-Location" |
| `url` | string | HTTP endpoint for this scheduler |
| `ttl` | integer | Time-to-live in seconds (default: 3600) |
| `nonce` | integer | Monotonically increasing counter |
| `codec-device` | string | Preferred codec (default: "httpsig@1.0") |
| `timestamp` | integer | Registration time in milliseconds |

### Codec Negotiation

Schedulers advertise their preferred message codec. When sending messages:
- Check target scheduler's `accept-codec` preference
- Convert message format if needed (e.g., HTTPSig → ANS-104)
- Re-sign with appropriate codec

### Location Resolution

When routing to a process's scheduler:
1. Check local cache for scheduler location
2. Query gateway if not cached
3. Extract hints from process's scheduler-location field
4. Follow hint URLs if `scheduler_follow_hints` enabled

---

# Part 2: LIVENET STAKING MARKETPLACE

## 2.1 Overview

LiveNet Staking implements a non-fungible stake vault system where each stake is tracked individually with its own lock duration. This prevents cooldown exploits where users could bypass waiting periods by rotating tokens.

**Related Branches**: `feat/livenet`, `feat/native-tokens`, `feat/token-device`, `wip/lucifer_livenet`

## 2.2 Erlang Device: livenet@1.0

### Exported Functions

| Function | Purpose |
|----------|---------|
| `info/1` | Returns device metadata listing exposed functions |
| `info/3` | Returns HTTP-formatted device description with parameter documentation |
| `join_network/3` | Registers a scheduler with staking parameters |
| `schedule/3` | Handles message scheduling with availability monitoring |

### join_network Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `scheduler-id` | binary | Unique identifier for this scheduler |
| `stake-amount` | integer | Number of AO tokens to stake |
| `lock-duration` | integer | Lock period in milliseconds |
| `max-penalties-per-epoch` | integer | Maximum slashing events before removal |
| `token-per-failed-request` | integer | Penalty amount per availability failure |
| `min-complainers` | integer | Minimum reports required for slashing consensus |

### Scheduler State

Each registered scheduler is stored with:
- Stake amount and lock duration
- Registration timestamp
- Current status (active/inactive/slashed)

## 2.3 Lua Script: livenet.lua

### Purpose
Manages the actual staking mechanics including vault creation, FIFO unstaking, and slashing.

### Data Structures

**Stakes Registry**: Maps addresses to arrays of stake vaults. Each vault contains:
- Unique identifier
- Staked amount
- Lock duration (milliseconds)
- Stake timestamp

**Unstaking Registry (Dual-Indexed)**:
- **By Address**: Quick lookup of user's pending unstakes
- **By Release Time**: Enables efficient batch processing of matured unstakes

### Handlers

| Handler | Trigger | Behavior |
|---------|---------|----------|
| `Credit-Notice` | Token deposit | Creates new vault with unique ID, records lock duration and timestamp |
| `Unstake` | User request | Processes oldest stakes first (FIFO), creates unstaking entries with release times |
| `Slash` | Admin action | Immediately removes stakes without cooldown (FIFO order) |

### FIFO Unstaking Process

When a user requests unstake of X tokens:
1. Start with oldest stake vault
2. If vault amount ≤ remaining request: fully unstake vault, continue to next
3. If vault amount > remaining: partially unstake, reduce vault amount
4. Create unstaking entries with release_time = now + vault's lock_duration
5. Add entries to both address-indexed and time-indexed registries

### Auto-Finalization Optimization

**Problem**: Naive approach checks every unstaking entry against current time = O(users × entries)

**Solution**: Time-indexed registry enables O(ready_entries) processing:
1. Collect all timestamps ≤ current time
2. Sort timestamps
3. For each timestamp batch, create single transfer message
4. Remove processed entries from both registries

This optimization is documented in commit f7b9f32 (Oct 29, 2025).

## 2.4 Security: Cooldown Exploit Prevention

### The Attack Vector

With fungible staking:
1. User stakes 1000 tokens at T=0
2. At T=23h, user requests unstake (starts 24h cooldown)
3. At T=23h, user stakes another 1000 tokens
4. At T=47h, first 1000 is released
5. User repeats indefinitely, always having liquid tokens despite "locking"

### The Defense

Non-fungible vaults with FIFO ordering:
- Each stake is a separate vault with its own lock duration
- Unstaking always processes oldest vaults first
- New stakes go to the end of the queue
- Cannot "jump ahead" with fresh tokens

This security measure is documented in commit 50b6579 (Oct 29, 2025).

---

# Part 3: STREAMING TOKEN DISTRIBUTIONS

## 3.1 Overview

Streaming Token Distributions enable real-time, on-demand minting using the POT (Proof of Token) model. Instead of continuously computing token distributions, the system calculates yields only when queried, reducing computational overhead to zero between queries.

**Related Branches**: `feat/mint`, `expr/pot`, `feat/mint-indexes`, `ex/subledger-payments`

## 3.2 POT Device: pot@1.0

### Purpose
Implements chi-proportional accumulation minting where a global "chi" value tracks cumulative yield per deposited unit.

### Exported Interface

| Function | Signature | Description |
|----------|-----------|-------------|
| `drip` | `drip(State, Req, Opts) → {ok, NewState}` | Calculates and applies pending yield |

### State Schema

| Key | Type | Description |
|-----|------|-------------|
| `t` | integer | Current time (block height or timestamp) |
| `last-drip` | integer | Time of last calculation |
| `chi` | float | Cumulative yield per deposited unit |
| `mint-cap` | integer | Maximum total supply |
| `mint-prop` | float | Proportion minted per time-step (e.g., 0.0001 = 0.01%) |
| `minted` | integer | Total tokens minted to date |
| `resources` | map | Resource pools with weights, deposits, and per-resource chi |
| `balances` | map | Credited (realized) balances by address |

### Mathematical Model

**Exponential Decay Minting**

The minting formula creates diminishing returns over time:

`TokensMinted = Remaining × (1 - (1-Proportion)^Steps)`

Where:
- `Remaining` = mint-cap minus already minted
- `Proportion` = mint-prop (e.g., 0.0001)
- `Steps` = time elapsed since last drip

**Chi Accumulation**

When tokens are minted, chi increases proportionally:

`ΔChi = TokensMinted / TotalDeposits`

This means each deposited unit "earns" an equal share of newly minted tokens.

**Balance Calculation**

User balance combines credited balance with unrealized yield:

`Balance = CreditedBalance + (CurrentChi - Chi0) × DepositAmount`

Where Chi0 is the chi value when the user made their deposit.

### Drip Behavior

1. Check if time has elapsed since `last-drip`
2. If no time elapsed, return state unchanged (zero computation)
3. Calculate tokens to mint using exponential decay formula
4. Compute chi increment based on total deposits
5. Update state with new chi, minted total, and last-drip timestamp
6. User balances are NOT updated - they're calculated on-demand

### Deposit Modification

When a user changes their deposit:
1. First execute drip to capture pending yield
2. Calculate user's current balance (including unrealized yield)
3. Credit the yield to user's balance
4. Update deposit amount
5. Reset user's chi0 to current chi (fresh accrual starting point)

## 3.3 Mint Device: mint@1.0

### Purpose
Orchestrates cycle-based minting with security enforcement.

### Exported Interface

| Function | Signature | Description |
|----------|-----------|-------------|
| `compute` | `compute(State, Req, Opts) → {ok, NewState}` | Execute minting with security |

### Behavior

1. Delegates to `security@1.0` device for authorization check
2. Queries `dev_mint_math:should_mint/3` to determine if cycle needed
3. If yes, executes `dev_mint_math:mint/3`
4. Recursively checks for additional cycles until stable

### Related Module: dev_mint_math.erl

| Function | Description |
|----------|-------------|
| `should_mint/3` | Returns boolean indicating if minting cycle should execute |
| `mint/3` | Executes one minting cycle, distributes to holders |

### Precision Protection

All calculations use multiplication before division to prevent precision loss:
- **Wrong**: `(Total / Count) × Share` - may round to zero
- **Correct**: `(Total × Share) / Count` - preserves precision

This fix is documented in commit e9892f0 (Nov 3, 2025).

## 3.4 Token Device: token@1.0

### Purpose
High-performance token implementation using trie-based balance storage.

### Exported Interface

| Function | Signature | Description |
|----------|-----------|-------------|
| `compute` | `compute(State, Req, Opts) → {ok, NewState}` | Route to action handler |

### Actions

| Action | Parameters | Description |
|--------|------------|-------------|
| `Transfer` | recipient, quantity | Move tokens between addresses |
| `Mint` | recipient, quantity (or quantities map) | Create new tokens (authority required) |
| `Balance` | target | Query single address balance |
| `Balances` | (none) | Query all balances |

### State Schema

| Key | Type | Description |
|-----|------|-------------|
| `balances` | trie | Address-to-balance mapping via trie@1.0 |
| `mint-authority` | address | Only this address can mint |
| `total-supply` | integer | Current circulating supply |

### Transfer Flow

1. Extract sender (from message signer), recipient, and quantity
2. Retrieve both balances from trie
3. Validate: balances are integers, quantity ≥ 0, sender has sufficient balance
4. Update both balances in trie
5. Generate Credit-Notice (to recipient) and Debit-Notice (to sender) in outbox

### Mint Flow

1. Verify requester is the mint-authority
2. For single mint: update recipient balance and total supply
3. For batch mint: iterate quantities map, update each recipient

### Performance

Benchmarked November 5, 2025:
- Sequential transfers: 17ms average
- Batch distribution: 0.065ms per recipient
- 15x improvement for batch vs sequential operations

## 3.5 HyperTokens: Peer Ledger System

### Purpose
Enables cross-ledger transfers between related token processes.

**Branch**: `ex/subledger-payments`

### Architecture

**Root Ledger**: No parent token reference, authoritative source of truth, rejects Credit-Notice messages.

**Sub-Ledgers**: Reference a parent token, accept Credit-Notice from registered peers, can transfer to other sub-ledgers.

### New Handlers

| Handler | Trigger | Description |
|---------|---------|-------------|
| `Register` | Peer request | Stores peer's security parameters, sends reciprocal registration |
| `Register-Remote` | Response | Completes bidirectional peer relationship |
| `Transfer` | User request | Handles same-ledger, peer, and routed transfers |
| `Credit-Notice` | Peer transfer | Validates peer and credits recipient (sub-ledgers only) |

### Peer Registration

When Ledger A wants to establish trust with Ledger B:
1. A sends Register to B with From-Base, From-Authority, From-Scheduler
2. B stores A's parameters and sends Register-Remote back
3. A stores B's parameters
4. Both can now validate transfers from each other

### Transfer Modes

| Mode | Condition | Behavior |
|------|-----------|----------|
| Same-ledger | Recipient is local address | Direct balance update |
| Peer transfer | Recipient is registered peer | Send Credit-Notice with security fields |
| Routed transfer | Route parameter provided | Multi-hop through peer chain |

### Security Validation (Three Tiers)

| Tier | What's Validated |
|------|------------------|
| Assignment | Message's scheduler matches process's scheduler constraint |
| Authority | Message's authority matches process's authority constraint |
| Peer | Credit-Notice sender is registered peer with matching security parameters |

### Multisig Support

Scheduler and authority fields can contain comma-separated lists. Validation succeeds if any provided value matches any required value.

Documented in commit f0ab0e1 (May 14, 2025).

---

# Part 4: AO-CORE 1.5 TYPE SYSTEM

## 4.1 Overview

AO-Core 1.5 introduces a message type system enabling type-aware routing, validation, and remote device loading with cryptographic trust verification.

**Branch**: `expr/1.5`

## 4.2 Message-to-Function Resolution

### Resolution Hierarchy

When resolving a key to a function, the system checks in order:
1. Device specification or default device selection
2. Handler functions with override capability
3. Direct function exports from module
4. Default handlers defined by device
5. Fallback device references
6. Global defaults

### Device Loading

The system supports three device input types:
- **Maps**: Returned directly as device definitions
- **Atoms**: Validated via module_info, must be loaded module
- **Binary IDs**: Trigger remote loading with trust verification

## 4.3 Remote Device Loading

### Requirements

Remote device loading requires:
- `load_remote_devices: true` in options
- Device message has `application/beam` content-type
- At least one signer is in `trusted_device_signers` list
- Device passes compatibility verification

### Trust Verification

1. Fetch device message from cache/network
2. Extract message signers
3. Check if any signer is in trusted list
4. If trusted, proceed to compatibility check
5. If untrusted, return error with signer details

### Compatibility Verification

Device metadata can specify requirements using `requires-*` prefixes:
- `requires-otp-version`: Minimum OTP release
- `requires-erts-version`: Minimum ERTS version
- `requires-hb-version`: Minimum HyperBEAM version

System compares requirements against `erlang:system_info/1` values, returning detailed mismatch information on failure.

## 4.4 BEAM File Parsing

### Purpose
Extracts type specifications from compiled BEAM files for runtime validation.

### Extracted Information

| Data | Source |
|------|--------|
| Module name | BEAM header |
| Type specifications | abstract_code chunk (-spec declarations) |
| Exported functions | exports chunk |
| Custom attributes | attributes chunk |

### Type Specification Format

Each -spec declaration is parsed into:
- Function name
- Arity
- Type specifications (argument types, return type)

## 4.5 Export Control

### Mechanism

Devices control which functions are externally accessible through info/0 metadata:

| Field | Type | Description |
|-------|------|-------------|
| `exports` | list or `all` | Whitelist of allowed functions |
| `excludes` | list | Blacklist of forbidden functions |

### Rules

1. The `info` function is always exported if it exists
2. Excludes list takes precedence over exports
3. If exports is `all`, everything except excludes is allowed
4. If exports is a list, only those functions are allowed

## 4.6 Type-Aware Routing

### Mechanism

Messages can specify a `type` field. The process state can contain `type-handlers` mapping types to handler devices.

### Flow

1. Extract message type (default: "Message")
2. Look up type-specific handler in state
3. If no handler, use default routing
4. If handler exists, validate message against type schema
5. Route to type-specific handler if valid

### Schema Validation

Type schemas can specify:
- Required fields that must be present
- Field types that must match
- Custom validation rules

---

# Part 5: CONFIGURATION REFERENCE

## 5.1 POT Device Configuration

| Key | Type | Example | Description |
|-----|------|---------|-------------|
| `mint-cap` | integer | 1000000000 | Maximum total supply |
| `mint-prop` | float | 0.0001 | Proportion per time-step (0.01%) |
| `chi` | float | 0 | Initial cumulative yield |
| `minted` | integer | 0 | Initial minted amount |
| `last-drip` | integer | 0 | Initial timestamp |

## 5.2 LiveNet Configuration

| Key | Type | Example | Description |
|-----|------|---------|-------------|
| `TokenProcess` | address | "abc123..." | Token contract for stake transfers |
| `Admin` | address | "def456..." | Administrator wallet |
| `DEFAULT_LOCK` | integer | 86400000 | Default lock duration (24h in ms) |

## 5.3 Scheduler Configuration

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `scheduler_lookahead` | boolean | true | Enable prefetch workers |
| `scheduler_location_notify_peers` | list | [] | Peer URLs for registration notification |
| `scheduler_follow_hints` | boolean | false | Extract scheduler URL from process hints |

## 5.4 Peer Ledger Configuration

| Key | Type | Description |
|-----|------|-------------|
| `Token` | address or nil | Parent token (nil for root ledger) |
| `Authority` | address | Message signing authority |
| `Scheduler` | address or list | Accepted scheduler(s) |
| `Peers` | map | Registered peer ledgers |

---

# Appendix A: Commit Reference

| Feature | Commit | Date | Author |
|---------|--------|------|--------|
| Non-fungible stake vaults | 50b6579 | Oct 29, 2025 | Lucifer0x17 |
| O(n²) → O(n) removal optimization | 6cafa14 | Oct 29, 2025 | Lucifer0x17 |
| Time-indexed auto_finalize | f7b9f32 | Oct 29, 2025 | Lucifer0x17 |
| Mint v3 minimum viable flow | 379aaa2 | Nov 1, 2025 | samcamwilliams |
| Precision loss prevention | e9892f0 | Nov 3, 2025 | samcamwilliams |
| POT real-time minting | 0e6dc00 | Nov 5, 2025 | samcamwilliams |
| Multi-asset POT support | 861c646 | Nov 5, 2025 | samcamwilliams |
| Token device benchmarks | - | Nov 5, 2025 | Lucifer0x17 |
| Peer ledgers with tests | 5d0324a | May 13, 2025 | samcamwilliams |
| Multisig scheduler support | f0ab0e1 | May 14, 2025 | samcamwilliams |
| Slot normalization | ecdfc32 | Aug 28, 2025 | samuelmanzanera |
| NCC Audit notation | 27730ba | Feb 23, 2025 | samcamwilliams |

---

# Appendix B: Branch Index

| Branch | Owner | Focus Area |
|--------|-------|------------|
| impr/scheduler-assignments | samuelmanzanera | Slot normalization, ANS-104 wrapping |
| impr/scheduler-proxy | samcamwilliams | Registration, codec negotiation |
| feat/aos2-scheduler-formats | - | AOS2 format compatibility |
| feat/livenet | Lucifer0x17 | Core staking implementation |
| feat/native-tokens | samcamwilliams | Token economy infrastructure |
| feat/token-device | Lucifer0x17 | Token@1.0 device implementation |
| wip/lucifer_livenet | Lucifer0x17, parthks | LiveNet device testing |
| feat/mint | samcamwilliams, Lucifer0x17 | Mint v3 implementation |
| expr/pot | samcamwilliams | POT minting model |
| feat/mint-indexes | samcamwilliams | Mint subscription system |
| ex/subledger-payments | samcamwilliams | Peer ledgers, multisig support |
| expr/1.5 | samcamwilliams | AO-Core 1.5 type system |

---

**Document Version**: 1.0.0
**Generated**: January 24, 2026
**Source**: HyperBEAM repository analysis
