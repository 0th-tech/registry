.PHONY: deploy sync test typecheck clean fmt fmt-check

NETWORK ?= devnet

CONTRACT = contracts/starknet

-include .env.$(NETWORK)
-include deployments/$(NETWORK).env
export

# make deploy NETWORK=<devnet|sepolia|mainnet>
deploy:
	mkdir -p deployments
	address=$$(cd $(CONTRACT) && sncast --profile $(NETWORK) --json deploy --contract-name Registry \
		--salt 0x0 --constructor-calldata $(REGISTRY_ADMIN_ACCOUNT) | jq -er 'select(.type == "response").contract_address') && \
		echo "REGISTRY=$$address" | tee deployments/$(NETWORK).env

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
