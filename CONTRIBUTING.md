# Contributing

SO4.market contracts are deployed as a connected protocol graph. Treat
`.deployed/<network>.env` as the source of truth for a network's current
deployment.

## Deployment Rules

- Use `make deploy-all NETWORK=testnet SOURCE=<key>` only for the first full
  deployment of a network.
- If `.deployed/<network>.env` already exists, do not redeploy the protocol graph
  just to test code changes. Use an upgrade command.
- Use `make deploy-force NETWORK=<network> SOURCE=<key>` only when you
  intentionally want a brand-new protocol deployment with new addresses.
- Use `make deploy-contract CONTRACT=<name> NETWORK=<network> SOURCE=<key>` only
  for standalone debugging. It does not update `.deployed/<network>.env`, does
  not initialize dependencies, and does not wire the contract into the protocol.

## Upgrade Rules

- Use `make upgrade-contract CONTRACT=<name> NETWORK=<network> SOURCE=<key>` for
  normal in-place contract changes.
- Use `make upgrade-all NETWORK=<network> SOURCE=<key>` only when every contract
  listed in `UPGRADE_CONTRACTS` exposes the required upgrade entrypoint.
- Upgradeable contracts must implement an admin-gated function equivalent to:

```rust
pub fn upgrade(env: Env, new_wasm_hash: BytesN<32>) {
    let admin: Address = env.storage().instance().get(&InstanceKey::Admin).unwrap();
    admin.require_auth();
    env.deployer().update_current_contract_wasm(new_wasm_hash);
}
```

- Do not change storage keys, enum variant order, or stored value types in an
  upgrade unless you also write and test an explicit migration path.
- Keep initialization separate from upgrades. `initialize` should run once;
  `upgrade` should preserve existing instance and persistent storage.

## Address Files

Full deployments write:

```sh
.deployed/testnet.env
.deployed/mainnet.env
.deployed/local.env
```

Test token setup writes:

```sh
.deployed/tokens-testnet.env
```

Use `make addresses NETWORK=<network>` to inspect the active deployment before
running any upgrade.
