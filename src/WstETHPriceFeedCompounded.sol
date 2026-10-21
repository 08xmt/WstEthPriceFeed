// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IChainlinkFeed, IWstETH} from "./WstETHPriceFeed.sol";

/// @notice Ethereum mainnet wstETH/USD feed using Chainlink stETH/ETH, ETH/USD, and Lido's conversion rate.
/// @dev Consumers must validate price validity and the freshness of both Chainlink inputs.
contract WstETHPriceFeedCompounded {
    IWstETH public constant wstETH = IWstETH(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
    IChainlinkFeed public constant stEthToEth = IChainlinkFeed(0x86392dC19c0b719886221c78AB11eb8Cf5c52812);
    IChainlinkFeed public constant ethToUsd = IChainlinkFeed(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);

    /// @notice Returns the 18-decimal USD price per wstETH with the minimum input timestamps.
    /// @dev stEthPerToken and stETH/ETH have 18 decimals; ETH/USD has 8 decimals. Multiplication
    /// is checked and the single final division truncates toward zero. No validity or freshness
    /// checks are performed. Upstream reverts and checked arithmetic failures propagate.
    /// roundId and answeredInRound identify only the ETH/USD input, not a composite round.
    /// startedAt and updatedAt are independently minimized and do not track Lido rate updates.
    function latestRoundData()
        public
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (, int256 stEthEthAnswer, uint256 stEthStartedAt, uint256 stEthUpdatedAt,) = stEthToEth.latestRoundData();
        (roundId, answer, startedAt, updatedAt, answeredInRound) = ethToUsd.latestRoundData();

        answer = int256(wstETH.stEthPerToken()) * stEthEthAnswer * answer / 1e26;
        startedAt = stEthStartedAt < startedAt ? stEthStartedAt : startedAt;
        updatedAt = stEthUpdatedAt < updatedAt ? stEthUpdatedAt : updatedAt;
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
