# Fix issues #144, #28, #56, #27

## Summary

- closes #144 — Add testnet market bootstrap workflow
- closes #28  — Implement global withdrawal list support
- closes #56  — Add order lifecycle tests for limit swap
- closes #27  — Implement global deposit list support

---

## Issue rgb(7, 31, 31) — Testnet market bootstrap workflow

**Files changed:** `scripts/bootstrap.sh` (new), `mx/deploy.mk`, `mx/tokens.mk`, `scripts/deploy.sh`, `README.md`

Adds a repeatable, end-to-end testnet bootstrap path so a fresh deployment needs no private context beyond the Stellar key names.

`scripts/bootstrap.sh` runs four steps after `deploy-all`:
1. Grants `MARKET_KEEPER`, `ORDER_KEEPER`, `LIQUIDATION_KEEPER`, `ADL_KEEPER`, and `FEE_KEEPER` roles to the configured keeper account.
2. Calls `market_factory.create_market()` and appends `MARKET_TOKEN` to the deploy env file.
3. Writes per-market config keys (`max_pool_amount`, `min_collateral_factor`, `max_leverage`, fee/borrowing/funding factors) to `data_store`.
4. Prints manual seeding instructions (oracle must be live before `execute_deposit`).

`mx/deploy.mk` gains three new targets:
- `make bootstrap` — full post-deploy bootstrap
- `make market-init` — market creation + config only (skips role grants and seed)
- `make seed-liquidity` — prints deposit_handler invocation for seeding the pool

`mx/tokens.mk` gains:
- `make market-tokens` — creates both `TWBTC` and `TUSDC` test tokens in one step

`scripts/deploy.sh` now prints the four next-step commands at the end of a successful deployment so operators know what to run immediately after.

`README.md` gains a **Testnet Market Bootstrap** section with a quick-start checklist, a target reference table, and `SKIP_*` flag documentation for idempotent re-runs.

---

## Issue #28 — Global withdrawal list support

**Files changed:** `contracts/withdrawal_handler/src/lib.rs`

The implementation (key insertion in `create_withdrawal`, key removal in `remove_withdrawal`, reader views `get_withdrawal_count` / `get_withdrawal_keys` / `get_account_withdrawal_*`) already existed. This PR adds `withdrawal_list_reflects_full_lifecycle`, a dedicated integration test that:

- Creates three withdrawals for three distinct users.
- Verifies all three keys appear in both the global list and the per-account lists.
- Cancels the first → asserts key removed from global and account list (count drops to 2).
- Executes the second → asserts key removed from global and account list (count drops to 1).
- Asserts the third withdrawal is still present in the global list and in local storage.

This covers the done-criterion: *"Withdrawal lists remain correct after create, cancel, and execute in tests."*

---

## Issue #56 — Order lifecycle tests for limit swap

**Files changed:** `contracts/order_handler/src/lib.rs`

**Behaviour change:** `execute_order` now checks the trigger price condition for `LimitSwap` orders. When `trigger_price > 0` and `index_price.min > trigger_price`, the execution reverts with `UnsatisfiedTrigger`. When `trigger_price == 0`, there is no price gate (the existing `min_output_amount` check is the only guard, mirroring `MarketSwap`).

**New tests** (`// ── Issue #56`):
| Test | Verifies |
|---|---|
| `limit_swap_above_trigger_price_reverts` | Stale/unfavorable price (index > trigger) → reverts |
| `limit_swap_at_trigger_price_executes` | Price == trigger → executes, user receives `long_tk` |
| `limit_swap_below_trigger_price_executes` | Price < trigger (favorable) → executes |
| `limit_swap_no_trigger_always_executes` | `trigger_price = 0` → always executes |
| `limit_swap_min_output_not_met_reverts` | `min_output_amount = i128::MAX` → reverts |
| `limit_swap_min_output_met_succeeds` | Achievable `min_output_amount` → executes, output ≥ min |

---

## Issue #27 — Global deposit list support

**Files changed:** `contracts/reader/src/lib.rs`, `contracts/deposit_handler/src/lib.rs`

**`reader.rs`** — adds four deposit list query functions symmetric to the existing withdrawal list functions:
- `get_deposit_count(env, data_store) -> u32`
- `get_deposit_keys(env, data_store, start, end) -> Vec<BytesN<32>>`
- `get_account_deposit_count(env, data_store, account) -> u32`
- `get_account_deposit_keys(env, data_store, account, start, end) -> Vec<BytesN<32>>`

Also adds `deposit_list_key` and `account_deposit_list_key` to the `gmx_keys` import.

**`deposit_handler.rs`** — adds `deposit_list_reflects_full_lifecycle`, a multi-user integration test that:
- Creates three deposits for three distinct users.
- Verifies the global count is 3 and all keys appear in global and per-account lists.
- Cancels the first → global count drops to 2, key absent.
- Executes the second → global count drops to 1, key absent.
- Asserts the third deposit key is the only entry in a paginated list query.

This covers the done-criterion: *"Create, cancel, and execute each update list membership correctly. A list query after all three operations returns only the expected keys."*
