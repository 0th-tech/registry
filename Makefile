.PHONY: deploy sync up down logs build test typecheck clean fmt fmt-check

NETWORK ?= devnet

# A download that fails leaves no partial file behind
.DELETE_ON_ERROR:

CONTRACT = contracts/starknet
SYNC_IMAGE ?= ghcr.io/0th-tech/registry-sync:v0.1.0
CIRCUIT_VERSION ?= v0.1.1
CIRCUIT_RELEASE = https://github.com/0th-tech/circuit/releases/download/$(CIRCUIT_VERSION)

-include .env.$(NETWORK)
-include deployments/$(NETWORK).env
export

# Network targets: make <target> NETWORK=<devnet|sepolia|mainnet>, devnet by default

deploy:
	mkdir -p deployments
	address=$$(cd $(CONTRACT) && sncast --profile $(NETWORK) --json deploy --contract-name Registry \
		--salt 0x0 --constructor-calldata $(REGISTRY_ADMIN_ACCOUNT) | jq -er 'select(.type == "response").contract_address') && \
		echo "REGISTRY=$$address" | tee deployments/$(NETWORK).env

# Fails on devnet: the container cannot reach the devnet RPC on localhost
up:
	docker rm -f registry-sync-$(NETWORK) 2>/dev/null || true
	docker run -d --name registry-sync-$(NETWORK) --restart unless-stopped \
		-e RPC_URL -e REGISTRY -e REGISTRY_ADMIN_ACCOUNT -e REGISTRY_ADMIN_PRIVATE_KEY $(SYNC_IMAGE)

down:
	docker rm -f registry-sync-$(NETWORK)

logs:
	docker logs -f registry-sync-$(NETWORK)

sync:
	cd sync && pnpm run sync

# A file from the circuit's release, downloaded again whenever this Makefile changes, since it pins the version
sync/target/circuit/%: Makefile
	mkdir -p $(@D)
	curl -fsSL $(CIRCUIT_RELEASE)/$* -o $@

build:
	cd $(CONTRACT) && scarb --release build

test: sync/target/circuit/fixture.json
	cd $(CONTRACT) && snforge test
	cd sync && pnpm test

typecheck:
	cd sync && pnpm run typecheck

clean:
	rm -rf $(CONTRACT)/target sync/target
	rm -f deployments/devnet.env

fmt:
	cd $(CONTRACT) && scarb fmt
	cd sync && pnpm run fmt

fmt-check:
	cd $(CONTRACT) && scarb fmt --check
	cd sync && pnpm run fmt-check
