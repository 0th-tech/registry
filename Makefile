.PHONY: deploy sync up down logs test typecheck clean fmt fmt-check

NETWORK ?= devnet

CONTRACT = contracts/starknet
SYNC_IMAGE ?= ghcr.io/0th-tech/registry-sync:v0.1.0

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

test:
	cd $(CONTRACT) && snforge test

typecheck:
	cd sync && pnpm run typecheck

clean:
	rm -rf $(CONTRACT)/target
	rm -f deployments/devnet.env

fmt:
	cd $(CONTRACT) && scarb fmt
	cd sync && pnpm run fmt

fmt-check:
	cd $(CONTRACT) && scarb fmt --check
	cd sync && pnpm run fmt-check
