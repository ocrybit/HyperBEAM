# HyperBEAM Post-Release Analysis Report
## v0.9-milestone-3-beta-3 → Future Releases

**Report Date**: January 24, 2026
**Analysis Period**: October 2, 2025 - January 24, 2026
**Base Release**: v0.9-milestone-3-beta-3 (commit d58f16b806f3e54e528624a3f6c0c81e34160ba6)

---

## Executive Summary

Since the v0.9-milestone-3-beta-3 release on October 2, 2025, HyperBEAM has undergone massive development:

- **290+ commits** on the edge branch
- **500+ commits** across all 198 branches
- **~117 PRs** created (PR #502 → #619)
- **198 total branches** with 73 feature/fix/improvement branches
- **7 open issues** tracking critical improvements
- **57 open PRs** with features awaiting merge

The development trajectory points toward **Milestone 4 (M4)** with fundamental protocol improvements.

---

## 🚀 OFFICIAL M4 ROADMAP (Announced Jan 22, 2026)

**Source**: [@aoTheComputer official announcement](https://twitter.com/aoTheComputer) - January 22, 2026

### Completed Milestones:
| Milestone | Name | Status |
|-----------|------|--------|
| ✅ M1 | AO Core | **Complete** |
| ✅ M2 | Native Execution & TEE Support | **Complete** |
| ✅ M3 | LegacyNet Migration (100x performance gains) | **Complete** |

### What's Next for M4:
| Feature | Description | Related Branches/PRs |
|---------|-------------|---------------------|
| **Decentralized Schedulers** | Distributed scheduling infrastructure | impr/scheduler-assignments, impr/scheduler-proxy, feat/aos2-scheduler-formats |
| **LiveNet Staking Marketplace** | Token staking and marketplace | **feat/livenet**, feat/native-tokens, feat/token-device, wip/lucifer_livenet |
| **Streaming Token Distributions** | Real-time token distribution system | **feat/mint**, **expr/pot**, feat/mint-indexes, ex/subledger-payments |

> *"The mainnet migration is complete. Now comes the real unlock 🔓"*
> — @aoTheComputer, January 22, 2026

---

## 🔥 CRITICAL M4 BRANCHES (Previously Missing)

### LiveNet Staking Infrastructure

#### feat/livenet (Lucifer0x17) - Nov 3, 2025
**Focus**: Core LiveNet staking implementation
| Date | Commit | Description |
|------|--------|-------------|
| Nov 2 | 0c52bb9 | chore: removed duplicated file |
| Oct 29 | 6cafa14 | **performance: optimize removal from O(n²) to O(n)** |
| Oct 29 | f7b9f32 | **performance: optimize auto_finalize with time-based index** |
| Oct 29 | 50b6579 | **security: implement non-fungible stake vaults to prevent cooldown exploit** |
| Oct 29 | abd7f59 | refactor: simplify livenet.lua to v0 core features |
| Oct 29 | fe2a1cd | wip: livenet process for hb |
| Oct 29 | dd46a99 | wip: livenet uncommit is added |
| Oct 29 | 709fe98 | **init: livenet** |

#### wip/lucifer_livenet (Lucifer0x17, parthks) - Jul 9, 2025
**Focus**: LiveNet device development
| Date | Commit | Description |
|------|--------|-------------|
| Jul 9 | f78e1a0 | chore: print a particular group from lua scripts |
| Jul 9 | 26de811 | wip: livenet process for hb |
| Jul 9 | eba870f | wip: dev_livenet test case |
| Jul 8 | d849f01 | wip: updated livenet lua script with fix |
| Jul 8 | beebf62 | init: test livenet device |

### Token Economy & Minting

#### feat/mint (samcamwilliams, Lucifer0x17) - Nov 4, 2025
**Focus**: Mint v3 implementation
| Date | Commit | Description |
|------|--------|-------------|
| Nov 4 | f9da505 | wip: token blueprint implementation as device |
| Nov 3 | d4ecfc8 | wip: impl mint with test suite |
| Nov 3 | e9892f0 | **fix: prevent precision loss in proportional token distribution** |
| Nov 2 | 4defa30 | wip: add multi-user mint test |
| Nov 1 | 379aaa2 | **feat: Minimum viable implementation of mint v3 flow** |
| Nov 1 | fe3b4d1 | feat: add `to` and `from` keys to `~trie@1.0` |
| Nov 1 | 7887125 | wip: HB-native mint impl. |

#### expr/pot (samcamwilliams) - Nov 5, 2025
**Focus**: DSR-like POT minter (Proof of Time/Token)
| Date | Commit | Description |
|------|--------|-------------|
| Nov 5 | 316b3d0 | chore: clarify math |
| Nov 5 | 861c646 | **wip: multi-asset support** |
| Nov 5 | da61ae4 | **feat: calculate tokens to mint between period in single operation** |
| Nov 5 | 56cf718 | **wip: add delegation support** |
| Nov 5 | 0e6dc00 | **feat: on-demand, real-time minting** |
| Nov 5 | e5759ff | wip: deposit and reward token model |
| Nov 4 | d9e86a8 | **feat: allow rate to change proportionate to total supply** |
| Nov 4 | d61f0c2 | **feat: add supply tracking** |
| Nov 4 | 53bfa4e | **expr: DSR-like pot minter implementation** |

#### feat/token-device (Lucifer0x17) - Nov 14, 2025
**Focus**: Token@1.0 device implementation
| Date | Commit | Description |
|------|--------|-------------|
| Nov 14 | - | test: add X- tag forwarding tests for transfer notices |
| Nov 11 | - | **feat: add input validation for security hardening** |
| Nov 6 | - | fix: action routing in dev_token (binary pattern matching) |
| Nov 5 | - | **fix: enabled benchmarks - 100 transfers in 1.7s, 10k recipients in 655ms** |
| Nov 5 | - | **feat: implement secure_set action with authority checking** |
| Nov 5 | - | **feat: implement mint functionality for token@1.0 device** |

### Payment & Subledger Infrastructure

#### ex/subledger-payments (samcamwilliams) - May 14, 2025
**Focus**: Subledger-to-subledger transfers and peer ledgers
| Date | Commit | Description |
|------|--------|-------------|
| May 14 | 5da725a | wip: modify `~p4@1.0` example to use subledger |
| May 14 | 48d6ce1 | impr: add subledger registration multischeduler testing |
| May 14 | 19d7f70 | **feat: support complex authority and scheduler matching in hyper-token** |
| May 14 | 056fb50 | **feat: hyper-token.lua supports validating multiple signers** |
| May 14 | f0ab0e1 | **feat: support multisignature requests for schedulers** |
| May 13 | ce97dcb | **feat: support multiple identities in hb_opts, scheduler, push** |
| May 13 | 5d0324a | **feat: peer ledgers, with passing tests** |
| May 13 | a8e125c | wip: subledger-to-subledger transfers |

#### impr/payments (samcamwilliams) - May 14, 2025
#### merge/payments - May 15, 2025
#### rc/tee-payments - May 16, 2025
**Focus**: TEE payment integration
#### feat/payment-processes (samcamwilliams) - May 6, 2025
**Focus**: Payment client and hooks API

### Scheduler Infrastructure

#### impr/scheduler-assignments (samuelmanzanera) - Aug 28, 2025
**Focus**: Scheduler assignment improvements
| Date | Commit | Description |
|------|--------|-------------|
| Aug 28 | ecdfc32 | impr: simplify slot normalization and wrap body assignments |
| Aug 27 | - | fixes to HTTP key access, apply API improvements |
| Aug 26 | - | timeout improvements for scheduler requests |

#### impr/scheduler-proxy (samcamwilliams) - Feb 24, 2025
**Focus**: Scheduler registration and mainnet onboarding
| Date | Commit | Description |
|------|--------|-------------|
| Feb 24 | 9340d28 | fix: convert ans-104 items if response in that format |
| Feb 24 | 771968a | wip: register scheduler location testing |
| Feb 24 | f71a4a8 | wip: scheduler register endpoint |
| Feb 24 | 7403dc7 | feat: add support for codec-device and accept-codec headers |
| Feb 23 | 27730ba | **chore: Audited by NCC, Dec'24-Jan'25** |
| Feb 23 | 17b277a | impr: mainnet options |

### Security & Invariant Testing

#### impr/pot-invariant-tests (noahlevenson) - Dec 15, 2025
#### impr/pot-invariant-tests-working (noahlevenson) - Jan 6, 2026
**Focus**: Property-based testing for POT token economics

#### feat/security (samcamwilliams) - Dec 8, 2025
**Focus**: Security device implementation

---

## Part 1: Complete Branch Analysis

### 1.1 Branch Statistics

| Category | Count | Examples |
|----------|-------|----------|
| Total Branches | 198 | - |
| Feature Branches (feat/*) | 35+ | feat/native-tokens, feat/bundler, feat/ecdsa_support |
| Fix Branches (fix/*) | 20+ | fix/paranoid, fix/ans104-nesting, fix/eth-signing |
| Improvement Branches (impr/*) | 18+ | impr/secure-actions, impr/ao-core, impr/cache-isolation |
| Experimental Branches (expr/*) | 5 | expr/1.5, expr/micro-ao, expr/micro-cache |
| Deploy Branches | 5 | deploy/edge_626, deploy/non-vol |
| Developer Branches | 15+ | NickJ202/*, VinceJuliano/*, speeddragon/* |

### 1.2 Active Development Branches with Ownership (Jan 2026)

| Branch | Owner | Last Updated | Commits | PR Status | Focus |
|--------|-------|--------------|---------|-----------|-------|
| expr/micro-cache | samcamwilliams | Jan 23, 2026 | 50+ | No PR | Micro-cache implementation |
| expr/micro-ao | samcamwilliams | Jan 23, 2026 | 45+ | No PR | Lightweight AO-Core resolver |
| feat/arweave-id-offset-indexing | JamesPiechota | Jan 23, 2026 | 30+ | **#616 Draft** | TX/DataItem indexing |
| use_store_routes | speeddragon | Jan 23, 2026 | 5+ | **#563 Open** | Store routing |
| impr/secure-actions | noahlevenson | Jan 22, 2026 | 40+ | No PR | Security invariant testing |
| expr/1.5 | samcamwilliams | Jan 20, 2026 | 60+ | **#618 Merged** | AO 1.5 type system |
| feat/preloaded-store | samcamwilliams | Jan 20, 2026 | 15+ | No PR | Device function store |
| fix/paranoid | speeddragon | Jan 16, 2026 | 5+ | **#613 Open** | Paranoid mode fixes |
| fix/path-id | JamesPiechota | Jan 16, 2026 | 5+ | **#612 Open** | Path segment handling |
| fix/multiple_reloaded_msg | speeddragon | Jan 16, 2026 | 3+ | **#611 Open** | Cache message fix |
| feat/native-tokens | samcamwilliams | Dec 17, 2025 | 45+ | No PR | Token economy |
| feat/mint-indexes | samcamwilliams | Dec 18, 2025 | 50+ | No PR | Mint subscription system |
| feat/ecdsa_support | speeddragon | Dec 18, 2025 | 35+ | **#574 Open** | ECDSA signatures |
| feat/c_snp | PeterFarber | Dec 18, 2025 | 35+ | No PR | AMD SEV-SNP attestation |

### 1.3 Complete Branch-to-PR Mapping

#### Open PRs (57 total)

| PR # | Branch | Author | Title | Status | Created |
|------|--------|--------|-------|--------|---------|
| #619 | - | Jonny-Ringo | Update link in base.html | Open | Jan 21, 2026 |
| #616 | feat/arweave-id-offset-indexing | JamesPiechota | Arweave ID offset indexing | **Draft** | Jan 19, 2026 |
| #614 | - | droter | content-digest preservation in JSON | Open | Jan 19, 2026 |
| #613 | fix/paranoid | speeddragon | Paranoid TX fetch fix | Open | Jan 16, 2026 |
| #612 | fix/path-id | JamesPiechota | Path segment ID handling | Open | Jan 16, 2026 |
| #611 | fix/multiple_reloaded_msg | speeddragon | Multiple cache loading fix | Open | Jan 13, 2026 |
| #603 | - | speeddragon | ans104_wasm_test fix | Open | Dec 31, 2025 |
| #602 | fix/parallel_requests | speeddragon | Parallel requests fix | Open | Dec 31, 2025 |
| #601 | - | speeddragon | Optional unbundle bundles | Open | Dec 23, 2025 |
| #598 | - | speeddragon | Invalid message handling | Open | Dec 19, 2025 |
| #596 | - | speeddragon | httpsig siginfo format | Open | Dec 17, 2025 |
| #592 | - | rythmn1111 | rustup for faster builds | Open | Dec 16, 2025 |
| #580 | - | jax-cn | Inference Device + SEV GPU | Open | Dec 8, 2025 |
| #574 | feat/ecdsa_support | speeddragon | Ed25519 support | Open | Nov 27, 2025 |
| #568 | - | JamesPiechota | Unsigned ans104 commitments | **Draft** | Nov 25, 2025 |
| #563 | use_store_routes | speeddragon | Load routes via store | Open | Nov 20, 2025 |
| #556 | - | PeterFarber | HTTP relay hardening | Open | Nov 17, 2025 |
| #552 | - | speeddragon | Multiple store read fix | Open | Nov 11, 2025 |
| #548 | - | jfrain99 | hb_ao:get_many optimization | Open | Nov 5, 2025 |
| #545 | - | speeddragon | erlang_ls.config formatting | Open | Nov 3, 2025 |
| #533 | - | speeddragon | Config documentation | Open | Oct 24, 2025 |
| #520 | - | speeddragon | S3 Store support | Open | Oct 16, 2025 |
| #500 | - | jfrain99 | rsa_pss optimization | **WIP** | Oct 2, 2025 |
| #484 | - | nikooo777 | HTTP Range requests | **Draft** | Sep 20, 2025 |
| #481 | - | PeterFarber | SSL Certificate Device | Open | Sep 18, 2025 |
| #479 | - | samuelmanzanera | Multi-commitment signatures | Open | Sep 12, 2025 |
| #477 | - | noahlevenson | HTTP client fix | Open | Sep 10, 2025 |
| #474 | - | ByteWanderer25 | dev_volume improvements | Open | Sep 4, 2025 |
| #472 | - | VinceJuliano | Remote cache failure handling | Open | Sep 2, 2025 |
| #452 | - | samuelmanzanera | Slot normalization | Open | Aug 22, 2025 |
| #443 | - | PeterFarber | OVMF firmware support | Open | Aug 15, 2025 |
| #433 | - | Jonny-Ringo | Online Ping Device | Open | Aug 8, 2025 |
| #408 | - | shyba | Tag limits enforcement | Open | Jul 25, 2025 |
| #401 | - | parthks | ETH address encoding | Open | Jul 18, 2025 |
| #399 | - | micovi | Cron list endpoint | Open | Jul 16, 2025 |
| #393 | - | Alex-wuhu | WASI-NN AI inference | Open | Jul 11, 2025 |
| #392 | - | JamesPiechota | ANS-104 tag clash | Open | Jul 10, 2025 |
| #390 | - | NickJ202 | hyperbuddy-ui upgrade | Open | Jul 8, 2025 |
| #386 | - | Alex-wuhu | GPU attestation device | Open | Jul 3, 2025 |
| #375 | - | samcamwilliams | Wallet management device | Open | Jun 20, 2025 |

#### Recently Merged PRs (Post-Release)

| PR # | Branch | Author | Title | Merged Date |
|------|--------|--------|-------|-------------|
| #618 | expr/1.5 | samcamwilliams | Type checking and varying | Jan 20, 2026 |
| #617 | - | samcamwilliams | Message extension | Jan 19, 2026 |
| #610 | - | samcamwilliams | content-type preservation | Jan 14, 2026 |
| #609 | - | samcamwilliams | Message integrity topics | Jan 7, 2026 |
| #608 | - | samcamwilliams | Commitment formatting | Jan 7, 2026 |
| #607 | - | Lucifer0x17 | Process timing improvements | Jan 7, 2026 |
| #606 | - | samcamwilliams | Process message integrity | Jan 7, 2026 |
| #604 | - | samcamwilliams | Message corruption tooling | Jan 6, 2026 |
| #600 | - | samcamwilliams | Event groups tidying | Jan 7, 2026 |
| #599 | - | samcamwilliams | Device inheritance | Dec 20, 2025 |
| #597 | - | samcamwilliams | Nearest hashpath salt | Dec 18, 2025 |
| #595 | - | samcamwilliams | Commitment-ids verification | Dec 17, 2025 |
| #594 | - | samcamwilliams | Nearest routing salt | Dec 17, 2025 |
| #593 | - | samcamwilliams | Assignment linking | Dec 16, 2025 |
| #591 | - | jfrain99 | Dedup trie overwrite | Dec 16, 2025 |
| #590 | - | samcamwilliams | Device key exports | Dec 14, 2025 |
| #589 | - | samcamwilliams | Invariant testing framework | Dec 14, 2025 |
| #588 | - | NickJ202 | Commitment spec uploads | Dec 12, 2025 |
| #587 | - | PeterFarber | Gateway sub-path fix | Dec 11, 2025 |
| #582 | - | speeddragon | Manifest redirect ID | Dec 10, 2025 |
| #578 | - | samcamwilliams | Manifest performance | Dec 6, 2025 |
| #575 | - | samcamwilliams | Data item/GraphQL tweaks | Nov 30, 2025 |
| #573 | - | jfrain99 | Dedup in genesis-wasm | Dec 1, 2025 |
| #572 | - | samcamwilliams | Downstream push routing | Nov 26, 2025 |
| #569 | - | samcamwilliams | ~process@1.0 library | Nov 24, 2025 |
| #567 | - | speeddragon | Gateway double read fix | Dec 10, 2025 |
| #565 | - | speeddragon | Default timeout values | Nov 23, 2025 |
| #564 | - | samcamwilliams | ANS-104 path key fix | Nov 21, 2025 |
| #562 | - | NickJ202 | Commitment spec in opts | Nov 20, 2025 |
| #561 | - | NickJ202 | Commitment spec choice | Nov 20, 2025 |
| #560 | - | NickJ202 | Scheduler assignment upload | Nov 20, 2025 |
| #558 | - | samcamwilliams | Hash-chain metadata | Nov 19, 2025 |
| #555 | - | Jonny-Ringo | Documentation patch | Nov 14, 2025 |
| #553 | - | speeddragon | URL/hash confusion | Nov 19, 2025 |
| #551 | - | NickJ202 | GraphQL parsing | Nov 11, 2025 |
| #550 | - | jfrain99 | Ordered routes | Nov 7, 2025 |
| #549 | - | speeddragon | Documentation typo | Nov 7, 2025 |
| #547 | - | jfrain99 | Commit with opts only | Dec 10, 2025 |
| #546 | - | jfrain99 | Lua ledger tests | Dec 10, 2025 |
| #544 | - | samcamwilliams | Multi-filter copycat | Nov 1, 2025 |
| #543 | - | jfrain99 | Load before scheduling | Nov 1, 2025 |
| #542 | - | samcamwilliams | Store start/greeter | Oct 31, 2025 |
| #540 | - | jfrain99 | Commitment normalization | Oct 30, 2025 |
| #539 | - | samcamwilliams | Execution efficiency | Oct 30, 2025 |
| #538 | - | jfrain99 | Read target commit | Oct 29, 2025 |
| #537 | - | samcamwilliams | Key normalization | Oct 29, 2025 |
| #536 | - | NickJ202 | Prometheus registry | Oct 30, 2025 |
| #535 | feat/bundler | JamesPiechota | HyperBEAM bundler | Nov 20, 2025 |
| #534 | - | jfrain99 | Trust WjnS checkpoints | Oct 31, 2025 |
| #532 | - | samcamwilliams | ID normalization perf | Oct 22, 2025 |
| #531 | - | jfrain99 | Route labels metrics | Oct 22, 2025 |
| #530 | - | noahlevenson | Greeter typo | Oct 22, 2025 |
| #529 | - | samcamwilliams | Lua normalization | Oct 21, 2025 |
| #527 | - | samcamwilliams | Message param naming | Oct 20, 2025 |
| #526 | - | jyeshe | Data size 404 fix | Oct 20, 2025 |
| #525 | - | jfrain99 | Route HTTP monitor | Oct 20, 2025 |
| #524 | - | samcamwilliams | Header ID normalization | Oct 20, 2025 |
| #523 | - | samcamwilliams | Erlang node naming | Oct 17, 2025 |
| #522 | - | samcamwilliams | Process cache scoping | Oct 17, 2025 |
| #521 | - | jfrain99 | Import legacy test | Oct 16, 2025 |
| #518 | - | jfrain99 | Int normalization | Oct 13, 2025 |
| #516 | - | samcamwilliams | AO-Core nomenclature | Oct 10, 2025 |
| #513 | - | samcamwilliams | JSON iface data fields | Oct 9, 2025 |
| #512 | - | jfrain99 | Public key to wasm | Oct 8, 2025 |
| #509 | - | noahlevenson | Radix trie device | Oct 16, 2025 |
| #508 | - | samcamwilliams | Hook resolution | Oct 7, 2025 |
| #507 | - | samcamwilliams | Cron cache fix | Oct 7, 2025 |
| #506 | - | samcamwilliams | Process cache perf | Oct 7, 2025 |
| #504 | - | noahlevenson | Trie 404 balance fix | Oct 4, 2025 |
| #485 | - | VanshSahay | httpsig_proxy fix | Oct 22, 2025 |

---

## Part 2: Detailed Commit Analysis by Branch

### 2.1 expr/1.5 Branch (AO 1.5 Core Development)

**Total Commits**: 60+
**Primary Contributors**: samcamwilliams, jfrain99, PeterFarber

#### Key Commits:
```
Jan 20 - feat: add basic message type parser from BEAM files
Jan 20 - wip: vary nested, check types, apply base/req schemas
Jan 20 - wip: `vary` implementation
Jan 19 - feat: implement `set` using only `...` message expansion
Jan 18 - feat: add support for 'extended' messages + filtering of keys
Jan 17 - impr: discard during `linkify` only in `id` calls, not `commit`
Dec 20 - impr: Recursive device inheritance
Dec 17 - fix: remove `commitment-ids` from recursive ID verification
Dec 16 - fix: link assignments to signed ID, not unsigned ID
```

#### Features Being Developed:
1. **Message Type System**: Parse types from BEAM files, validate schemas
2. **Message Varying**: Nested variation, base/req schema application
3. **Extended Messages**: Key filtering to signed subset
4. **Recursive Set**: New implementation using message expansion

### 2.2 expr/micro-ao Branch (Lightweight AO-Core)

**Total Commits**: 45+
**Primary Contributors**: samcamwilliams, jfrain99

#### Key Commits:
```
Jan 23 - impr: add precedence correctness tests
Jan 22 - wip: hb_types vary by base, req ids
Jan 21 - wip: all hb_ao_micro tests working
Jan 21 - wip: `hb_types` lazy load implementation
Jan 21 - feat: a simple AO-Core 1.5 resolver spec implementation
Jan 20 - wip: draft AO-Core 1.5 micro resolver
```

#### Features Being Developed:
1. **Micro Resolver**: Lightweight AO-Core 1.5 spec implementation
2. **hb_types**: Lazy loading of types with base/req ID variation
3. **Test Suite**: Basic AO 1.5 test vectors for validation

### 2.3 expr/micro-cache Branch (Cache Optimization)

**Total Commits**: 50+
**Primary Contributors**: samcamwilliams

#### Key Commits:
```
Jan 23 - wip: support loaded `Req` messages
Jan 23 - impr: tidy path resolution
Jan 23 - impr: more minimization
Jan 23 - impr: simplify cache operations
Jan 23 - expr: alternate key resolution in `hb_ao_[micro|cache]`
Jan 23 - wip: modify `hb_types` to use `hb_cache_micro`
Jan 23 - wip: add micro-cache implementation
```

#### Features Being Developed:
1. **hb_cache_micro**: Minimalist cache implementation
2. **Path Resolution**: Simplified and tidied
3. **Key Resolution**: Alternate resolution in micro modules

### 2.4 feat/native-tokens Branch (Token Economy)

**Total Commits**: 45+
**Primary Contributors**: samcamwilliams, Lucifer0x17

#### Key Commits:
```
Dec 17 - feat: inter-process subscription framework
Dec 17 - feat: `~security@1.0`, an enforcer of commitment requirements
Dec 16 - fix: derive process ID correctly in `dev_token:push`
Dec 16 - fix: sign `POST /push` body, not wrapper
Dec 15 - wip: subscription management
Dec 15 - fix: `t` sourcing in `~pot@1.0`; `.../balance` testing
Dec 14 - fix: pot token process tests
Dec 13 - feat: subscription topic for process
```

#### Features Being Developed:
1. **Inter-Process Subscriptions**: Framework for process-to-process messaging
2. **Security Device**: `~security@1.0` for commitment requirement enforcement
3. **Token Push**: Correct signing and process ID derivation
4. **Balance Management**: Testing and fixes for balance updates

### 2.5 feat/mint-indexes Branch (Minting System)

**Total Commits**: 50+
**Primary Contributors**: samcamwilliams, Lucifer0x17

#### Key Commits:
```
Dec 18 - wip: forward keys to subscribers with `x-`
Dec 17 - wip: mint index device
Dec 17 - feat: inter-process subscription framework
Dec 17 - feat: `~security@1.0`, an enforcer of commitment requirements
Dec 16 - impr: commitment formatting options
Dec 16 - feat: add message verification mode to `hb_format`
Dec 15 - wip: add subscription management system
Dec 15 - impr: test to fix balance updation without calling mint
```

#### Features Being Developed:
1. **Mint Index Device**: Tracking and indexing mints
2. **Subscriber Forwarding**: Keys forwarded with `x-` prefix
3. **Commitment Formatting**: Improved verification and metadata

### 2.6 feat/c_snp Branch (AMD SEV-SNP Attestation)

**Total Commits**: 35
**Primary Contributors**: PeterFarber

#### Key Commits:
```
Dec 18 - fix: measurement invalid 30 (final iteration)
Dec 18 - fix: measurement invalid 1-29 (debugging series)
Dec 12 - fix: stack smashing
Dec 12 - fix: buffer size and ovmf
Dec 12 - chore: compute digest
```

#### Features Being Developed:
1. **SEV-SNP Integration**: AMD Secure Encrypted Virtualization
2. **Measurement Validation**: 30 iterations of fixes for correct attestation
3. **OVMF Integration**: Open Virtual Machine Firmware support

### 2.7 feat/ecdsa_support Branch (ECDSA Signatures)

**Total Commits**: 35
**Primary Contributors**: speeddragon

#### Key Commits:
```
Dec 18 - fix: Add ECDSA signature string
Dec 17 - wip: Verify always false, to be fixed
Dec 17 - fix: Test and address encoding
Dec 17 - test: Add ed25519 real data item
Dec 17 - fix: Add opts to deep_get call
Dec 17 - fix: Ignore digest type on ed25519
Dec 17 - fix: ed25519 sign and verify
Dec 16 - wip: Add ed25519 signature validation
```

#### Features Being Developed:
1. **ECDSA Support**: Full signing and verification
2. **Ed25519 Integration**: Building on PR #574 work
3. **Real Data Testing**: Tests with actual blockchain data items

### 2.8 feat/bundler Branch (Data Item Batching)

**Total Commits**: 30+
**Primary Contributors**: JamesPiechota

#### Key Commits:
```
Nov 19 - wip: add tests to validate HB-generated dataitems
Nov 13 - wip: clear cache before running bundler tests
Nov 13 - wip: more tests for the bundler recovery from cache
Nov 12 - wip: introduce dev_bundler_cache to cache bundler state
Nov 11 - wip: add jitter to bundler retry timeout
Nov 11 - wip: implement bundler retry exponential backoff
Nov 11 - wip: add bundler retry logic and dispatch workers
Nov 07 - wip: move dispatcher to its own process
Nov 06 - wip: script to stress test bundler
Nov 04 - wip: handle price or anchor error when bundling
```

#### Features Being Developed:
1. **dev_bundler**: Main bundler module for batching data items
2. **dev_bundler_dispatch**: Worker process management
3. **dev_bundler_cache**: State persistence across restarts
4. **Retry Logic**: Exponential backoff with jitter
5. **Stress Testing**: Scripts for load testing

### 2.9 impr/secure-actions Branch (Security Testing)

**Total Commits**: 40+
**Primary Contributors**: noahlevenson

#### Key Commits:
```
Jan 22 - wip: make hb_invariant log a message demarcating runs
Jan 22 - wip: implement hb_invariant basic request observability
Jan 16 - wip: use zeroed out accumulators in initial state
Jan 15 - wip: make initial values less likely to test corner cases
Jan 13 - wip: make public API functions drip over actual delta-t
Jan 09 - wip: verify delegation/undelegation invariants
Jan 07 - wip: delegation invariant verification
Jan 06 - wip: fix verify_withdraw_liquidation
```

#### Features Being Developed:
1. **hb_invariant**: Property-based testing framework
2. **Delegation Testing**: Verify delegation/undelegation invariants
3. **Liquidation Testing**: Withdrawal and liquidation verification
4. **Request Observability**: Logging and demarcation of test runs

### 2.10 Historical Experimental Branches

#### expr/httpsig-reorg (20+ commits)
```
- chore: temporarily disable ANS-104 codec bundling
- fix: pass `Opts` in `~json-iface` map resolution
- fix: `lru` uses `hb_store` not `hb_cache` to write
- feat: `ans104@1.0` honors `accept-bundle` headers
- feat: `ans-104` hyperstate bundling support
```

#### expr/lmdb-async-put (20+ commits)
```
- impr: increase message read speed from cache by ~534x
- impr: implement new `fold_after` API for LMDB async_put
- wip: experiment using `elmdb` async API
- impr: list keys with guaranteed presence without flushing
```

#### expr/lazy-loading (20+ commits)
```
- expr: partial draft impl of lazy loading from HB stores
- feat: if gen-wasm-server is already running locally, use it
- feat: use ans-104 original tags in json-iface serialization
```

---

## Part 3: Edge Branch Commit Analysis

### 3.1 January 2026 Commits (25+)

| Date | Hash | Author | Message |
|------|------|--------|---------|
| Jan 14 | 4d657e4 | PeterFarber | Merge PR #610: content-type preservation |
| Jan 13 | dec0933 | samcamwilliams | fix: preserve content-type in httpsig bundled messages |
| Jan 07 | 2cb0d77 | samcamwilliams | Merge PR #609: message integrity topics |
| Jan 07 | 21abdf7 | samcamwilliams | impr: subsection message integrity checks |
| Jan 07 | cf57344 | samcamwilliams | Merge PR #608: commitment event logs |
| Jan 07 | e80f051 | samcamwilliams | impr: label device/path keys when committed |
| Jan 07 | a2b2844 | samcamwilliams | Merge PR #600: tidy event groups |
| Jan 07 | d28acf3 | Lucifer0x17 | impr: timing for ~process@1.0 |
| Jan 07 | 29634f5 | samcamwilliams | Merge PR #606: process message integrity |
| Jan 06 | 6c4a268 | samcamwilliams | wip: cache inconsistency debugging |
| Jan 06 | 35704b2 | samcamwilliams | fix: commitments key in message response |
| Jan 05 | 8aea3a7 | samcamwilliams | feat: message corruption tooling |

### 3.2 December 2025 Commits (60+)

| Date | Hash | Author | Message |
|------|------|--------|---------|
| Dec 21 | f427225 | samcamwilliams | feat: add `top` command |
| Dec 21 | ab35acf | samcamwilliams | impr: tidy event groups, prometheus |
| Dec 20 | 184a8ae | samcamwilliams | Merge PR #599: device inheritance |
| Dec 20 | 469adc0 | samcamwilliams | impr: recursive device inheritance |
| Dec 18 | bcce0b3 | samcamwilliams | Merge PR #597: nearest distribution |
| Dec 17 | f5fec7a | samcamwilliams | Merge PR #595: single-ID verification |
| Dec 17 | 2fbe137 | samcamwilliams | impr: user-defined salt for Nearest |
| Dec 16 | f160e1e | samcamwilliams | Merge PR #593: assignment linking |
| Dec 14 | 05615b5 | samcamwilliams | Merge PR #590: device key exports |
| Dec 14 | ec538bf | samcamwilliams | Merge PR #589: invariant testing |
| Dec 10 | 8acdf68 | samcamwilliams | Merge PR #567: gateway double read |
| Dec 10 | f938962 | samcamwilliams | Merge PR #582: manifest redirect ID |
| Dec 06 | b72e58e | samcamwilliams | Merge PR #578: manifest performance |
| Dec 01 | 5464135 | samcamwilliams | Merge PR #573: dedup in genesis-wasm |

### 3.3 November 2025 Commits (70+)

| Date | Hash | Author | Message |
|------|------|--------|---------|
| Nov 30 | 62d1645 | samcamwilliams | Merge PR #575: data item/GraphQL tweaks |
| Nov 28 | 5b1d547 | samcamwilliams | impr: use trie for duplicate IDs |
| Nov 26 | 54687d2 | samcamwilliams | Merge PR #572: downstream push routing |
| Nov 20 | b8f8e92 | samcamwilliams | Merge PR #535: HyperBEAM bundler |
| Nov 20 | e4c8f45 | samcamwilliams | Merge PR #561: commitment spec choice |
| Nov 19 | 6db7f43 | samcamwilliams | Merge PR #558: hash-chain metadata |
| Nov 19 | a6f7e53 | samcamwilliams | Merge PR #553: URL/hash confusion |
| Nov 14 | c8a9f42 | samcamwilliams | Merge PR #555: documentation patch |
| Nov 11 | 20748de | samcamwilliams | Merge PR #551: GraphQL parsing |
| Nov 07 | c747f61 | samcamwilliams | Merge PR #550: ordered routes |
| Nov 04 | 39cea51 | JamesPiechota | bundler dead code removal |
| Nov 01 | 1867398 | samcamwilliams | Merge PR #544: multi-filter copycat |

### 3.4 October 2025 Commits (85+)

| Date | Hash | Author | Message |
|------|------|--------|---------|
| Oct 31 | 6a04d47 | samcamwilliams | Merge PR #542: store start/greeter |
| Oct 30 | 7c8b3e9 | samcamwilliams | Merge PR #539: execution efficiency |
| Oct 29 | 8e72a9b | samcamwilliams | Merge PR #537: key normalization |
| Oct 27 | be9adfb | jfrain99 | feat: read only target commitment |
| Oct 24 | f5235f9 | JamesPiechota | chore: testing cleanup |
| Oct 22 | 2e85bbc | samcamwilliams | Merge PR #485: httpsig_proxy fix |
| Oct 22 | 5a92764 | samcamwilliams | Merge PR #532: ID normalization perf |
| Oct 21 | 585bcb9 | samcamwilliams | Merge PR #529: lua normalization |
| Oct 20 | b8a390c | samcamwilliams | Merge PR #527: message param naming |
| Oct 17 | a05d35b | samcamwilliams | Merge PR #523: Erlang node naming |
| Oct 16 | 3e9a7c4 | noahlevenson | feat: radix trie (24 commits) |
| Oct 13 | 4b8d7e3 | samcamwilliams | Merge PR #518: int normalization |
| Oct 10 | 9c7e5d2 | samcamwilliams | Merge PR #516: AO-Core nomenclature |
| Oct 08 | 7f3a2b1 | samcamwilliams | Merge PR #512: public key to wasm |
| Oct 07 | 5d2e8c9 | samcamwilliams | Merge PR #507: cron cache fix |
| Oct 03 | 3a1b9c8 | samcamwilliams | wip: cache write optimization |

---

## Part 4: PR Discussion Highlights

### 4.1 PR #616: Arweave ID Offset Indexing (Draft)

**Author**: JamesPiechota
**Status**: Draft
**Changes**: +1,264 / -125 across 19 files

**Technical Details**:
- Implements TX-bundle writing/reading to `hb_store_arweave`
- Adds `~arweave@2.9-pre/chunk` endpoints for data segments
- Introduces "IsTX" boolean to distinguish L1 transactions from L2 DataItems
- Supports `exclude-data` argument for header-only queries

**Open Questions**:
1. API naming: `hb_ao:resolve` vs `hb_ao:get`
2. Configuration convention: atom keys vs binary strings
3. Error handling for non-RSA signatures (will throw errors)

### 4.2 PR #574: Ed25519 Support (Open)

**Author**: speeddragon
**Status**: Open, 17 commits

**Technical Details**:
- Ed25519 signing/verification in `ar_wallet` and `ar_bundles`
- L2 transaction bundle support
- Address generation from Ed25519 public keys

**Review Discussion**:
- JamesPiechota: Must test with real blockchain Ed25519 data items
- samcamwilliams: Always pass `Opts` to maintain data validity context
- Limitation: GraphQL lacks anchor info for some Ed25519 verification

### 4.3 PR #580: Inference Device (Open)

**Author**: jax-cn
**Status**: Open, 41 commits

**Components**:
- `dev_inference.erl`: OpenAI-compatible API for local LLM
- `dev_sev_gpu`: NVIDIA SEV-SNP attestation via C++/NIF
- Python-based deterministic inference server
- SSE streaming support added to `hb_http.erl`

**Endpoints**:
- `/~inference@1.0/health` - Health check
- `/v1/chat/completions` - Chat API (supports streaming)

### 4.4 PR #520: S3 Store Support (Open)

**Author**: speeddragon
**Status**: Open

**Performance**:
- ~8 messages/sec writes
- ~5 messages/sec reads
- "Storing a message in S3 using one file per message attributes is quite slow"

**Configuration**:
- Required: bucket, access_key_id, secret_access_key
- Optional: region, endpoint, force_path_style, retry settings

**Dependencies**: erlcloud_s3, meck, MinIO for testing

### 4.5 PR #535: HyperBEAM Bundler (Merged)

**Author**: JamesPiechota
**Merged**: November 20, 2025

**Architecture**:
```
Client POST → dev_bundler → Batch Creation → dev_bundler_dispatch → Arweave
                    ↓
            dev_bundler_cache (persistence)
```

**Features**:
- Timeout-based bundling (size limit or idle timeout)
- Exponential backoff retry with jitter
- State caching across restarts
- Mock server for testing

---

## Part 5: Future Release Predictions

### 5.1 Milestone 4 (M4) - OFFICIAL ROADMAP

Based on the **official @aoTheComputer announcement (Jan 22, 2026)**, M4 will focus on:

#### 🎯 M4 Core Features (Confirmed)

| Feature | Description | Branch/PR Evidence | Readiness |
|---------|-------------|-------------------|-----------|
| **Decentralized Schedulers** | Distributed scheduling across nodes | impr/scheduler-assignments, PR #561 | 70% |
| **LiveNet Staking Marketplace** | Token staking infrastructure | feat/native-tokens, feat/mint-indexes | 60% |
| **Streaming Token Distributions** | Real-time token streaming | feat/mint-indexes, ~security@1.0 | 50% |

#### M4 Supporting Infrastructure (From Branch Analysis)

| Feature | Source | Status | Commits |
|---------|--------|--------|---------|
| Message integrity tooling | PR #604 | ✅ Merged | 5+ |
| Paranoid mode topics | PR #609 | ✅ Merged | 3+ |
| Device inheritance | PR #599 | ✅ Merged | 2+ |
| HyperBEAM bundler | PR #535 | ✅ Merged | 30+ |
| Invariant testing | PR #589 | ✅ Merged | 40+ |
| Inter-process subscriptions | feat/mint-indexes | In Progress | 50+ |
| Security device (~security@1.0) | feat/native-tokens | In Progress | 45+ |

#### PRs Likely to Merge for M4:
| PR # | Title | Author | Priority |
|------|-------|--------|----------|
| #614 | content-digest preservation | droter | High |
| #612 | path-id handling | JamesPiechota | High |
| #611 | cache loading fix | speeddragon | High |
| #613 | paranoid TX fetch | speeddragon | High |
| #556 | HTTP relay hardening | PeterFarber | Medium |
| #574 | Ed25519 support | speeddragon | Medium |

### 5.2 AO 1.5 / Post-M4 (Expected: Q2-Q3 2026)

**Based on Active Experimental Branches**:

| Feature | Branch | Owner | Commits | Readiness |
|---------|--------|-------|---------|-----------|
| Type system | expr/1.5 | samcamwilliams | 60+ | 70% |
| Micro-AO resolver | expr/micro-ao | samcamwilliams | 45+ | 60% |
| Micro-cache | expr/micro-cache | samcamwilliams | 50+ | 50% |
| Ed25519 | PR #574 | speeddragon | 17 | 80% |
| ECDSA | feat/ecdsa_support | speeddragon | 35 | 60% |
| Inference device | PR #580 | jax-cn | 41 | 70% |
| S3 store | PR #520 | speeddragon | 20+ | 90% |

**AO 1.5 Detailed Features**:

1. **Message Type System** (from expr/1.5):
   - BEAM file type parsing
   - Schema validation
   - Message varying/extension
   - **Owner**: samcamwilliams

2. **Enhanced Cryptography**:
   - Ed25519 signatures (PR #574) - **Owner**: speeddragon
   - ECDSA support (feat/ecdsa_support) - **Owner**: speeddragon
   - Improved commitment handling

3. **AI/ML Integration** (PR #580):
   - OpenAI-compatible inference API
   - SEV GPU attestation
   - Streaming SSE responses
   - **Owner**: jax-cn

4. **Storage Options**:
   - S3 store (PR #520) - **Owner**: speeddragon
   - Micro-cache optimization - **Owner**: samcamwilliams

### 5.3 Long-term Roadmap (v1.5+)

**Based on Feature Branches and Issues**:

| Feature | Source | Owner | Status |
|---------|--------|-------|--------|
| Native tokens | feat/native-tokens | samcamwilliams | Development |
| Mint system | feat/mint-indexes | samcamwilliams | Development |
| Inter-process subscriptions | feat/mint-indexes | samcamwilliams | Development |
| Security enforcement | ~security@1.0 | samcamwilliams | Development |
| SNP attestation | feat/c_snp | PeterFarber | Development |
| WebSocket device | Issue #317 | - | Planned |
| HTTP/3 support | Issue #327 | - | In Progress |
| Docker publishing | Issue #169 | - | Planned |

---

## Part 6: Technical Decisions Analysis

### 6.1 Architecture Decisions

| Decision | Rationale | Commits | Impact |
|----------|-----------|---------|--------|
| Radix trie for dedup | ~50% message reduction | 24 | High |
| Device inheritance | OOP-style defaulting | 5 | High |
| Micro-AO resolver | Lightweight spec impl | 45+ | High |
| Message type system | Type safety at runtime | 60+ | Critical |
| hb_invariant testing | Property-based testing | 40+ | Medium |

### 6.2 Protocol Evolution

**AO-Core 1.0 → 1.5 Changes**:
```
1.0: Msg1, Msg2, Msg3
1.5: Base, Req, Response (with schema validation)

1.0: Static message structure
1.5: Message extension/varying with `...` expansion

1.0: Runtime type checking
1.5: BEAM file type parsing + schema validation
```

### 6.3 Storage Strategy

| Store | Performance | Use Case |
|-------|-------------|----------|
| LMDB | 534x faster reads | Primary production store |
| LRU | Fast in-memory | Cache layer |
| S3 | ~5-8 msg/sec | Large-scale persistence |
| Gateway | Variable | Remote data access |

---

## Part 7: Contributor Analysis

### 7.1 Commit Activity by Contributor

| Contributor | Total Commits | Primary Branches | Focus Areas |
|-------------|---------------|------------------|-------------|
| samcamwilliams | 200+ | edge, expr/1.5, feat/native-tokens | Core protocol, architecture |
| jfrain99 | 40+ | edge, expr/micro-ao | Scheduling, optimization |
| JamesPiechota | 50+ | feat/bundler, feat/arweave-id-offset | Bundler, codecs, indexing |
| speeddragon | 35+ | feat/ecdsa_support, fix/* | Signatures, bug fixes |
| PeterFarber | 45+ | feat/c_snp, edge | Attestation, gateway |
| noahlevenson | 65+ | impr/secure-actions, edge | Testing, trie device |
| Lucifer0x17 | 15+ | feat/native-tokens, edge | Logging, token process |
| NickJ202 | 20+ | edge | Scheduler, dashboard |

### 7.2 Code Ownership

| Module | Primary Owner | Backup |
|--------|---------------|--------|
| hb_ao.erl | samcamwilliams | jfrain99 |
| dev_bundler.erl | JamesPiechota | - |
| dev_trie.erl | noahlevenson | samcamwilliams |
| hb_invariant.erl | noahlevenson | - |
| dev_sev_gpu | PeterFarber | - |
| ar_bundles.erl | speeddragon | JamesPiechota |

---

## Part 8: Risk Analysis

### 8.1 Technical Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Message type system complexity | High | Incremental rollout |
| S3 performance bottleneck | Medium | LMDB caching layer |
| Cryptographic compatibility | Medium | Extensive real-data testing |
| Process hang (#436) | High | Debugging in progress |

### 8.2 Dependency Risks

| Dependency | Issue | Branches Affected |
|------------|-------|-------------------|
| erlcloud_s3 | External | feat/s3-store |
| elmdb | Performance critical | All stores |
| Python inference | TEE environment | feat/inference |

---

## Conclusion

HyperBEAM is undergoing a **fundamental evolution** from v0.9-milestone-3-beta-3 toward **Milestone 4 (M4)**. Analysis of 500+ commits across 198 branches, combined with the **official @aoTheComputer announcement (Jan 22, 2026)**, reveals:

### ✅ Completed (M1-M3)
- **M1**: AO Core foundation
- **M2**: Native Execution & TEE Support
- **M3**: LegacyNet Migration (100x performance gains)

### 🎯 M4 Focus (Current)
Per official announcement:
- **Decentralized Schedulers** - Distributed scheduling infrastructure
- **LiveNet Staking Marketplace** - Token staking and marketplace
- **Streaming Token Distributions** - Real-time token streaming

### 📊 Branch Activity Supporting M4
| Owner | Active Branches | Focus |
|-------|----------------|-------|
| samcamwilliams | expr/1.5, expr/micro-ao, feat/native-tokens | Core protocol, tokens |
| speeddragon | feat/ecdsa_support, fix/* branches | Cryptography, fixes |
| JamesPiechota | feat/arweave-id-offset-indexing | Indexing, bundler |
| noahlevenson | impr/secure-actions | Security testing |
| PeterFarber | feat/c_snp | TEE attestation |

### 🔮 Post-M4 Vision (AO 1.5+)
- Message type system (expr/1.5 - 60+ commits)
- Multi-signature support (Ed25519, ECDSA)
- AI inference integration (PR #580)
- Micro-cache optimization
- Full TEE attestation suite

> *"The mainnet migration is complete. Now comes the real unlock 🔓"*
> — @aoTheComputer, January 22, 2026

The experimental branches (expr/1.5, expr/micro-ao, expr/micro-cache) show active research defining the next protocol version, while the official M4 roadmap confirms focus on **decentralized schedulers, staking marketplace, and streaming token distributions**.

---

## Part 9: COMPREHENSIVE TECHNICAL ANALYSIS - New Devices & Protocols

### 9.1 Device Architecture Overview

HyperBEAM implements a **device-oriented architecture** where each device is an Erlang module (`dev_*.erl`) that implements the AO-Core protocol. There are **72 device files** in the codebase:

| Category | Devices | Purpose |
|----------|---------|---------|
| **Core Process** | `dev_process`, `dev_scheduler`, `dev_push` | Process execution, scheduling, message routing |
| **Execution** | `dev_wasm`, `dev_genesis_wasm`, `dev_lua` | WASM/Lua runtime execution |
| **Payment** | `dev_p4`, `dev_simple_pay` | Payment ledger and pricing |
| **Data Structures** | `dev_trie`, `dev_dedup` | Radix trie, deduplication |
| **Security/TEE** | `dev_snp`, `dev_poda` | SEV-SNP attestation, proof-of-authority |
| **Codec** | `dev_codec_*` (14 modules) | Message encoding (ANS-104, HTTPSig, JSON) |
| **Infrastructure** | `dev_stack`, `dev_multipass`, `dev_hook` | Device composition, multi-pass execution |

### 9.2 Core Device: process@1.0 (`dev_process.erl`)

The **process device** is the central coordinator for AO processes:

```erlang
%% External API
GET /ID/Schedule        → Returns messages in the schedule
POST /ID/Schedule       → Adds a message to the schedule
GET /ID/Compute/[Slot]  → Returns state after applying a message
GET /ID/Now             → Returns latest computed results
```

**Key Mechanisms:**

1. **Device Delegation**: Routes requests to specialized devices (scheduler, execution, push)
2. **State Caching**: Configurable snapshot frequency via `Cache-Frequency`
3. **Execution Stack**: Customizable via `Execution-Stack` key

**Example Process Definition:**
```
Device: Process/1.0
Scheduler-Device: Scheduler/1.0
Execution-Device: Stack/1.0
Execution-Stack: "Scheduler/1.0", "Cron/1.0", "WASM/1.0", "PoDA/1.0"
```

**Process State Flow:**
```
init() → [load snapshot or init devices]
       ↓
compute_to_slot() → [iteratively apply assignments until target slot]
       ↓
store_result() → [cache with optional snapshot at configured intervals]
```

### 9.3 Scheduler Device: scheduler@1.0 (`dev_scheduler.erl`)

**Decentralized Scheduling** is a core M4 feature. The scheduler manages:

```erlang
%% Exported Functions
slot/3      → Returns current slot for a process
next/3      → Gets next assignment from schedule
schedule/3  → Schedules new messages
location/3  → Scheduler location registration
```

**Lookahead Worker Pattern:**
- Spawns background workers to pre-fetch next assignments
- Reduces latency through speculative caching
- Configurable via `scheduler_lookahead` option

**Assignment Caching:**
```erlang
find_next_assignment(Msg1, Msg2, Schedule, LastSlot, Opts) ->
    %% 1. Check message cache (in-memory)
    %% 2. Check local cache (disk)
    %% 3. Fetch from SU (remote)
```

**Scheduler Location Registration** (for decentralization):
```erlang
post_location/3 →
    %% 1. Generate scheduler location message
    %% 2. Sign with node's wallet
    %% 3. Upload to Arweave
    %% 4. Notify configured peers
```

### 9.4 Stack Device: stack@1.0 (`dev_stack.erl`)

Manages **device composition** with two execution modes:

| Mode | Behavior |
|------|----------|
| **Fold** (default) | Sequential execution, passing state forward |
| **Map** | Parallel execution, combining results |

**Special Status Handling:**
- `skip` → Skips remaining devices for current pass
- `pass` → Re-executes stack from first device (multi-pass)

**Prefix System:**
- `Input-Prefix` → Where device reads input
- `Output-Prefix` → Where device writes output
- Enables isolated I/O namespaces per device

### 9.5 WASM Execution: wasm@1.0 (`dev_wasm.erl`)

**Memory-64 WebAssembly execution** using WAMR (WebAssembly Micro Runtime):

```erlang
init/3      → Boots WASM image, creates executor instance
compute/3   → Calls WASM function with parameters
snapshot/3  → Serializes WASM memory state
normalize/3 → Restores from snapshot if no instance
terminate/3 → Tears down WASM executor
```

**Key Features:**
- AOT (Ahead-of-Time) compilation support (configurable)
- Import resolver for external function calls
- State serialization/deserialization for checkpoints

### 9.6 Genesis WASM: genesis-wasm@1.0 (`dev_genesis_wasm.erl`)

**LegacyNet compatibility layer** - enables existing AO processes to run on HyperBEAM:

```erlang
%% Delegates to external genesis-wasm-server (Node.js)
compute(Msg, Msg2, Opts) ->
    {ok, Msg3} = delegated_compute(Msg, Msg2, Opts),
    %% Apply patch@1.0 for outbox processing
    patch_result(Msg3, <<"/results/outbox">>)
```

**Architecture:**
- Spawns Node.js-based genesis-wasm-server
- Communicates via HTTP at configurable port (default: 6363)
- Uses RocksDB for state persistence

### 9.7 Payment System: p4@1.0 (`dev_p4.erl`)

**Core Payment Ledger** with pluggable pricing and ledger devices:

```erlang
%% Configuration
p4_pricing-device: Device that estimates request costs
p4_ledger-device:  Device that manages payment ledger

%% Pricing Device API
GET /estimate?type=pre|post&body=[...]&request=Req
GET /price?type=pre|post&body=[...]&request=Req

%% Ledger Device API
POST /credit?message=PaymentMsg&request=Req
POST /charge?amount=Price&request=Req
GET /balance?request=Req
```

**Request Flow:**
```
1. request/3 → Estimate cost, check balance
2. [Execute actual request]
3. response/3 → Calculate final price, charge account
```

**Non-Chargeable Routes:**
```erlang
-define(DEFAULT_NON_CHARGABLE_ROUTES, [
    #{ <<"template">> => <<"/~p4@1.0/balance">> },
    #{ <<"template">> => <<"/~p4@1.0/topup">> },
    #{ <<"template">> => <<"/~meta@1.0/*">> }
]).
```

### 9.8 Simple Pay: simple-pay@1.0 (`dev_simple_pay.erl`)

**Per-request pricing** with operator controls:

```erlang
%% Pricing Rules (in order)
1. Operator requests → cost = 0
2. Matched route with explicit price → use route price
3. Default → (message_count × simple_pay_price) + apply_subrequest_cost
```

**Ledger Operations:**
- `estimate/3` → Calculate request cost
- `charge/3` → Debit account balance
- `balance/3` → Query account balance
- `topup/3` → Credit account (operator only)

---

## Part 10: M4-SPECIFIC DEVICES & PROTOCOLS

### 10.1 POT Device: pot@1.0 (expr/pot branch)

**Proof-of-Token** - Experimental real-time on-demand minting:

**Chi-Proportional Accumulation Model:**
```erlang
%% Core Formula
units_minted_between(Remaining, Proportion, Steps) ->
    Remaining * (1 - pow(1 - Proportion, Steps))

%% Per-Unit Reward Distribution
reward_per_resource_unit(TotalMinted, DepositQuantity, TotalDeposits) ->
    (TotalMinted * DepositQuantity) div TotalDeposits
```

**Key State Variables:**
| Key | Purpose |
|-----|---------|
| `minted` | Total units minted to date |
| `mint-cap` | Maximum mintable supply |
| `mint-prop` | Proportion per time-step |
| `last-drip` | Timestamp of last calculation |
| `chi` | Cumulative yield per resource unit |

**Balance Calculation:**
```erlang
Balance = ExistingBalance + (CurrentChi - InitialChi) * DepositAmount
```

### 10.2 Token Device: token@1.0 (expr/pot branch)

**Fast AO Token Specification** with trie-based storage:

```erlang
%% Transfer Flow
transfer(State, Req, Opts) ->
    From = extract_from(Req),
    Recipient = extract_recipient(Req),
    Quantity = extract_quantity(Req),

    %% Validation
    assert(Quantity >= 0),
    assert(get_balance(From) >= Quantity),

    %% Update balances via trie
    NewState = update_trie(State, From, -Quantity),
    FinalState = update_trie(NewState, Recipient, +Quantity),

    %% Send notices
    send_credit_notice(From),
    send_debit_notice(Recipient),

    {ok, FinalState}
```

**Mint Authority Checking:**
```erlang
enforce_mint_authority(Req, State, Opts) ->
    Requester = get_signer(Req),
    Authority = get_key(<<"mint-authority">>, State),
    case Requester == Authority of
        true  -> {ok, authorized};
        false -> {error, <<"Mint authority mismatch">>}
    end
```

**Benchmarks** (feat/token-device):
- 100 transfers: **1.7 seconds**
- 10,000 recipients: **655 milliseconds**

### 10.3 Mint Math: dev_mint_math.erl (expr/pot branch)

**Precision-safe distribution mathematics** using Erlang bignums:

**Core Formulas:**
```erlang
%% Distribution per holder (multiplication before division)
Units = (UnitsForResource * Quantity) div TotalQuantity

%% Supply per cycle
CycleSupply = (Remaining * CycleProportionNumerator) div CycleProportionDenominator

%% Resource weighting
UnitsPerResource = (TotalToDistribute * Weight) div TotalWeights
```

**Precision Loss Prevention:**
- All operations use native bignum (no float conversion)
- Multiplication BEFORE division to prevent rounding to zero
- Dust tracking: Unallocated units carried forward

### 10.4 Radix Trie: trie@1.0 (feat/livenet branch)

**Efficient balance storage** with radix-256 implementation:

**Architecture:**
```erlang
%% Radix-256: Each node has up to 256 children
-define(RADIX, 256).

%% Implicit leaf optimization: Collapses leaf nodes into parents
%% "car" stored as: <<"car">> => Value (no intermediate nodes)
```

**Operations:**
| Function | Complexity | Description |
|----------|------------|-------------|
| `insert/4` | O(key length) | Add/update key-value |
| `retrieve/3` | O(key length) | Get value by key |
| `keys/2` | O(n) | List all keys |

**Match Types:**
1. **No Match** → Create implicit leaf
2. **Full Match** → Recurse or transform leaf to internal
3. **Partial Match** → Split and reattach subtries

### 10.5 LiveNet Device (feat/livenet branch)

**Staking marketplace infrastructure** (specification stage):

**Configuration Parameters:**
```erlang
%% join_network parameters
<<"stake-amount">>           → AO token commitment
<<"lock-duration">>          → Lock period (milliseconds)
<<"max-penalties-per-epoch">> → Slashing threshold
<<"token-per-failed-request">> → Penalty amount
<<"min-complainers">>        → Consensus for slashing
```

**Security Features (planned):**
- **Non-fungible stake vaults** → Prevents cooldown exploit
- **Time-based indexing** → Optimizes auto_finalize
- **O(n²) to O(n) optimization** → Performance improvement for removals

---

## Part 11: SECURITY & TEE INTEGRATION

### 11.1 SEV-SNP Attestation: snp@1.0 (`dev_snp.erl`)

**AMD SEV-SNP hardware attestation** for confidential computing:

```erlang
%% Verification Steps
verify(M1, M2, Opts) ->
    1. verify_nonce()              → Nonce matches address + node ID
    2. verify_signature_and_address() → Valid signature from expected address
    3. verify_debug_disabled()     → Production mode enforced
    4. verify_trusted_software()   → Firmware/kernel match whitelist
    5. verify_measurement()        → Launch digest matches
    6. verify_report_integrity()   → Hardware root of trust
```

**Committed Parameters:**
```erlang
-define(COMMITTED_PARAMETERS, [
    vcpus, vcpu_type, vmm_type, guest_features,
    firmware, kernel, initrd, append
]).
```

**Report Generation:**
```erlang
generate(_M1, _M2, Opts) ->
    Address = get_wallet_address(Opts),
    NodeMsgID = compute_node_message_id(Opts),
    ReportData = generate_nonce(Address, NodeMsgID),
    {ok, ReportJSON} = dev_snp_nif:generate_attestation_report(ReportData),
    {ok, #{
        <<"local-hashes">> => TrustedConfig,
        <<"nonce">> => encode(ReportData),
        <<"address">> => Address,
        <<"report">> => ReportJSON
    }}
```

### 11.2 Proof of Delegated Authority: poda@1.0 (`dev_poda.erl`)

**Decentralized consensus** for AO processes:

**Two-Flow Architecture:**
1. **Execution Flow**: Initialize → Validate incoming messages
2. **Commitment Flow**: Add commitments to results

**Validation Stages:**
```erlang
validate_stage(1) → Check required PoDA messages present
validate_stage(2) → Verify all commitment signatures
validate_stage(3) → Check quorum of valid authorities reached
```

**Commitment Aggregation:**
```erlang
add_commitments(NewMsg, S, Opts) ->
    %% Get trusted authorities from process
    Authorities = extract_authorities(Process),
    Quorum = extract_quorum(Process),

    %% Gather commitments from peer compute nodes (parallel)
    Commitments = pfiltermap(
        fun(Authority) ->
            {ok, CU} = find_compute_node(Authority),
            request_commitment(CU, MsgID)
        end,
        Authorities
    ),

    %% Bundle commitments with local signature
    create_commitment_bundle(Commitments, LocalCommitment)
```

### 11.3 Deduplication: dedup@1.0 (`dev_dedup.erl`)

**Message deduplication** for idempotent execution:

```erlang
%% Deduplication Logic
handle(Key, M1, M2, Opts) ->
    Subject = get_subject(M1, M2, Opts),
    SubjectID = compute_id(Subject),
    DedupList = get_seen_list(M1),

    case lists:member(SubjectID, DedupList) of
        true  -> {skip, M1};              %% Already processed
        false -> {ok, add_to_seen(M1, SubjectID)}
    end
```

**Multipass Compatibility:**
- Only runs on first pass (`pass == 1`)
- Allows `multipass@1.0` to re-execute without interference

---

## Part 12: MESSAGE ROUTING & PUSH MECHANISM

### 12.1 Push Device: push@1.0 (`dev_push.erl`)

**Recursive message propagation** across processes:

```erlang
%% Push Flow
push(Base, Req, Opts) ->
    1. schedule_initial_message()  → Schedule message on process
    2. compute_outbox()            → Execute and get outbox
    3. for each outbox message:
       a. resolve_target_process()
       b. apply_security_policy()
       c. schedule_result()
       d. recurse: push()
```

**Security Policy Application:**
```erlang
apply_security(Msg, TargetProcess, Codec, Opts) ->
    1. Check process `policy` key → Custom accept-committers
    2. Check process `authority` key → Sign with matching local keys
    3. Default → Sign with node's default wallet
```

**Redirect Handling:**
- Status 307 → Follow redirect to new scheduler
- Codec downgrade: HTTPSig → ANS-104 if needed

### 12.2 Multipass: multipass@1.0 (`dev_multipass.erl`)

**Multi-pass execution** trigger:

```erlang
handle(_Key, M1, _M2, Opts) ->
    Passes = get(<<"passes">>, M1, 1),
    Pass = get(<<"pass">>, M1, 1),
    case Pass < Passes of
        true  -> {pass, M1};   %% Request another pass
        false -> {ok, M1}      %% Complete
    end
```

**Usage in Stack:**
```
Device-Stack: ["wasm@1.0", "patch@1.0", "multipass@1.0"]
passes: 2
```

---

## Part 13: CODEC SYSTEM

HyperBEAM supports multiple message encoding formats via **14 codec devices**:

| Codec | Device | Purpose |
|-------|--------|---------|
| ANS-104 | `dev_codec_ans104` | Arweave bundle format |
| HTTPSig | `dev_codec_httpsig` | HTTP Signature signing |
| JSON | `dev_codec_json` | JSON serialization |
| Flat | `dev_codec_flat` | Simplified encoding |
| Cookie | `dev_codec_cookie` | Session management |
| Structured | `dev_codec_structured` | Structured field format |

**Codec Conversion Flow:**
```
HTTPSig message → [verify signature] → Internal format → [re-sign] → ANS-104
```

---

## Part 14: PROTOCOL EVOLUTION - AO 1.5 (expr/1.5 branch)

The **expr/1.5 branch** (60+ commits) introduces a **message type system**:

**Type System Components:**
- BEAM file parsing for type extraction
- Message classification and validation
- Type-aware routing and execution

**Integration Points:**
- Scheduler: Type-based assignment filtering
- Execution: Type-validated compute calls
- Push: Type-aware message propagation

---

## Summary: Technical Stack

```
┌─────────────────────────────────────────────────────────────────┐
│                        APPLICATION LAYER                         │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐            │
│  │ token@  │  │  pot@   │  │livenet@ │  │ mint@   │            │
│  │  1.0    │  │  1.0    │  │  1.0    │  │  1.0    │            │
│  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘            │
└───────┼────────────┼────────────┼────────────┼──────────────────┘
        │            │            │            │
┌───────┼────────────┼────────────┼────────────┼──────────────────┐
│       │         CORE DEVICES                 │                   │
│  ┌────┴────┐  ┌────┴────┐  ┌────┴────┐  ┌────┴────┐            │
│  │process@ │  │scheduler│  │  push@  │  │  trie@  │            │
│  │  1.0    │  │  @1.0   │  │  1.0    │  │  1.0    │            │
│  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘            │
└───────┼────────────┼────────────┼────────────┼──────────────────┘
        │            │            │            │
┌───────┼────────────┼────────────┼────────────┼──────────────────┐
│       │       EXECUTION LAYER                │                   │
│  ┌────┴────┐  ┌────┴────┐  ┌────┴────┐  ┌────┴────┐            │
│  │ stack@  │  │ wasm@   │  │genesis- │  │  lua@   │            │
│  │  1.0    │  │  1.0    │  │ wasm@   │  │  5.3a   │            │
│  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘            │
└───────┼────────────┼────────────┼────────────┼──────────────────┘
        │            │            │            │
┌───────┼────────────┼────────────┼────────────┼──────────────────┐
│       │       SECURITY LAYER                 │                   │
│  ┌────┴────┐  ┌────┴────┐  ┌────┴────┐  ┌────┴────┐            │
│  │  snp@   │  │ poda@   │  │ dedup@  │  │security@│            │
│  │  1.0    │  │  1.0    │  │  1.0    │  │  1.0    │            │
│  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘            │
└───────┼────────────┼────────────┼────────────┼──────────────────┘
        │            │            │            │
┌───────┼────────────┼────────────┼────────────┼──────────────────┐
│       │        PAYMENT LAYER                 │                   │
│  ┌────┴────┐  ┌────┴────┐                                       │
│  │  p4@    │  │simple-  │                                       │
│  │  1.0    │  │ pay@1.0 │                                       │
│  └─────────┘  └─────────┘                                       │
└─────────────────────────────────────────────────────────────────┘
```

**Key Technical Achievements for M4:**
1. **72 devices** forming a composable execution framework
2. **Chi-proportional minting** with precision-safe bignum math
3. **Radix-256 trie** for efficient balance storage
4. **Hardware-backed attestation** via AMD SEV-SNP
5. **Decentralized scheduler** registration and lookahead caching
6. **Multi-pass device stacks** for complex execution flows
7. **100x performance gains** through native WASM execution
