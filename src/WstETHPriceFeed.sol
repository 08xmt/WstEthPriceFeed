// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IChainlinkFeed {
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

interface IWstETH {
    function stEthPerToken() external view returns (uint256);
}

/// @notice Ethereum mainnet wstETH/USD feed using Chainlink stETH/USD and Lido's conversion rate.
/// @dev Derived from Inverse Finance's WstETHPriceFeed, without fallback pricing or governance.
/// Consumers must validate the returned price and round metadata, including freshness.
contract WstETHPriceFeed {
    IWstETH public constant wstETH = IWstETH(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
    IChainlinkFeed public constant stEthToUsd = IChainlinkFeed(0xCfE54B5cD566aB89272946F602D76Ea879CAb4a8);

    /// @notice Returns the 18-decimal USD price per wstETH and unmodified Chainlink round metadata.
    /// @dev stEthPerToken has 18 decimals and stETH/USD has 8 decimals. No validity or freshness
    /// checks are performed. Upstream reverts and checked arithmetic failures propagate.
    function latestRoundData()
        public
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (roundId, answer, startedAt, updatedAt, answeredInRound) = stEthToUsd.latestRoundData();
        answer = int256(wstETH.stEthPerToken()) * answer / 1e8;
    }

    /// @notice Returns the same 18-decimal price as latestRoundData().
    function latestAnswer() external view returns (int256) {
        (, int256 answer,,,) = latestRoundData();
        return answer;
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }
}
