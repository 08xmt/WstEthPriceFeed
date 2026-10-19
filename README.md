# wstETH/USD price feed

A minimal Ethereum mainnet price feed derived from [Inverse Finance's WstETHPriceFeed](https://etherscan.io/address/0x894B896cDc772656Cbb1eE28e6Bd4a704caA7b61#code). It retains the primary pricing calculation and removes fallback pricing, governance, and heartbeat configuration.

## Pricing and interface

```text
wstETH/USD (18 decimals) = stETH per wstETH (18 decimals) × stETH/USD (8 decimals) / 1e8
```

For example, 1.2 stETH per wstETH and a stETH price of $2,500 produce `3000e18`. Integer division truncates toward zero. Solidity's checked multiplication reverts on overflow.

The contract has no constructor arguments and uses these fixed dependencies:

| Dependency | Ethereum mainnet address |
| --- | --- |
| Lido wstETH, `stEthPerToken()` | `0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0` |
| Chainlink stETH/USD, `latestRoundData()` | `0xCfE54B5cD566aB89272946F602D76Ea879CAb4a8` |

- `latestRoundData()` returns `(uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)`. Only `answer` is transformed; all round metadata comes unchanged from stETH/USD and does not track updates to Lido's conversion rate.
- `latestAnswer()` returns the same calculated price.
- `decimals()` returns `18`.
- `wstETH()` and `stEthToUsd()` expose the dependency addresses.

Consumers must validate price validity and round freshness. The feed does not check price bounds, positivity, timestamps, or round completeness, and it does not substitute another source. Zero and negative upstream answers are used directly in the calculation; stale timestamps are forwarded unchanged. Dependency reverts propagate to the caller.

## Build and test

With Foundry installed and the `lib/forge-std` submodule initialized:

```sh
forge fmt --check
forge build --sizes
forge test -vvv
```

Tests mock the two dependencies and require no RPC connection. They cover pricing, rounding, metadata, invalid and stale data passthrough, dependency failures, overflow, and fuzzed positive inputs.

## Deployment

Preview deployment using an Ethereum mainnet RPC:

```sh
forge script script/WstETHPriceFeed.s.sol:WstETHPriceFeedScript --rpc-url "$MAINNET_RPC_URL"
```

To deploy, configure a Foundry signer (for example, a keystore via `--account`) and add `--broadcast`. The contract uses Ethereum mainnet addresses and has no owner, setters, or upgrade mechanism.
