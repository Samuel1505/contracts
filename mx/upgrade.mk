# Upgrade workflows.
#
# Contract upgrades require the deployed contract to expose:
#   pub fn upgrade(env: Env, new_wasm_hash: BytesN<32>)
# where the function authenticates the stored admin and calls:
#   env.deployer().update_current_contract_wasm(new_wasm_hash)

UPGRADE_CONTRACTS ?= \
	role_store \
	data_store \
	oracle \
	market_factory \
	deposit_vault \
	deposit_handler \
	withdrawal_vault \
	withdrawal_handler \
	order_vault \
	order_handler \
	liquidation_handler \
	adl_handler \
	fee_handler \
	referral_storage \
	reader \
	exchange_router

.PHONY: upload upgrade upgrade-contract upgrade-all upgrade-with-hash

upload: preflight build
	@test -n "$(CONTRACT)" || { printf '%s\n' 'Usage: make upload CONTRACT=deposit_handler'; exit 1; }
	@test -f "$(WASM_DIR)/$(CONTRACT).wasm" || { printf 'Missing wasm: %s/%s.wasm\n' "$(WASM_DIR)" "$(CONTRACT)"; exit 1; }
	stellar contract upload \
		--wasm "$(WASM_DIR)/$(CONTRACT).wasm" \
		--source "$(SOURCE)" \
		--network "$(NETWORK)"

upgrade: upgrade-contract

upgrade-contract: preflight build
	@test -n "$(CONTRACT)" || { printf '%s\n' 'Usage: make upgrade-contract CONTRACT=deposit_handler'; exit 1; }
	@test -f "$(DEPLOY_ENV)" || { printf 'Missing %s. Run make deploy-all first or pass CONTRACT_ID=...\n' "$(DEPLOY_ENV)"; exit 1; }
	source "$(DEPLOY_ENV)"
	contract_key="$$(printf '%s' "$(CONTRACT)" | tr '[:lower:]-' '[:upper:]_')"
	contract_id="$${CONTRACT_ID:-$${!contract_key:-}}"
	test -n "$$contract_id" || { printf 'No address found for %s in %s. Pass CONTRACT_ID=...\n' "$$contract_key" "$(DEPLOY_ENV)"; exit 1; }
	wasm_hash="$$(stellar contract upload --wasm "$(WASM_DIR)/$(CONTRACT).wasm" --source "$(SOURCE)" --network "$(NETWORK)")"
	printf 'Uploaded %s -> %s\n' "$(CONTRACT)" "$$wasm_hash"
	stellar contract invoke \
		--id "$$contract_id" \
		--source "$(SOURCE)" \
		--network "$(NETWORK)" \
		-- upgrade --new_wasm_hash "$$wasm_hash"
	printf 'Upgraded %s at %s\n' "$(CONTRACT)" "$$contract_id"

upgrade-all: preflight build
	@test -f "$(DEPLOY_ENV)" || { printf 'Missing %s. Run deploy-all first.\n' "$(DEPLOY_ENV)"; exit 1; }
	source "$(DEPLOY_ENV)"
	for contract in $(UPGRADE_CONTRACTS); do
		contract_key="$$(printf '%s' "$$contract" | tr '[:lower:]-' '[:upper:]_')"
		contract_id="$${!contract_key:-}"
		test -n "$$contract_id" || { printf 'No address found for %s in %s\n' "$$contract_key" "$(DEPLOY_ENV)"; exit 1; }
		test -f "$(WASM_DIR)/$$contract.wasm" || { printf 'Missing wasm: %s/%s.wasm\n' "$(WASM_DIR)" "$$contract"; exit 1; }
		printf 'Upgrading %s at %s\n' "$$contract" "$$contract_id"
		wasm_hash="$$(stellar contract upload --wasm "$(WASM_DIR)/$$contract.wasm" --source "$(SOURCE)" --network "$(NETWORK)")"
		stellar contract invoke \
			--id "$$contract_id" \
			--source "$(SOURCE)" \
			--network "$(NETWORK)" \
			-- upgrade --new_wasm_hash "$$wasm_hash"
	done
	printf 'Upgraded all configured contracts on %s\n' "$(NETWORK)"

upgrade-with-hash: preflight
	@test -n "$(CONTRACT_ID)" || { printf '%s\n' 'Usage: make upgrade-with-hash CONTRACT_ID=C... WASM_HASH=...'; exit 1; }
	@test -n "$(WASM_HASH)" || { printf '%s\n' 'Usage: make upgrade-with-hash CONTRACT_ID=C... WASM_HASH=...'; exit 1; }
	stellar contract invoke \
		--id "$(CONTRACT_ID)" \
		--source "$(SOURCE)" \
		--network "$(NETWORK)" \
		-- upgrade --new_wasm_hash "$(WASM_HASH)"
