# Build and static-analysis workflows.

.PHONY: check lint build build-release inspect list-contracts

check:
	cargo check --workspace

lint:
	cargo clippy --workspace -- -D warnings

build: preflight
	stellar contract build

build-release: preflight
	stellar contract build --release

inspect: preflight
	@test -n "$(CONTRACT)" || { printf '%s\n' 'Usage: make inspect CONTRACT=deposit_handler'; exit 1; }
	stellar contract inspect --wasm "$(WASM_DIR)/$(CONTRACT).wasm"

list-contracts:
	@printf '%s\n' $(CONTRACTS)
