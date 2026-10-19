// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, stdError} from "forge-std/Test.sol";
import {WstETHPriceFeed, IChainlinkFeed, IWstETH} from "../src/WstETHPriceFeed.sol";

contract WstETHPriceFeedTest is Test {
    WstETHPriceFeed internal feed;

    uint80 internal constant ROUND_ID = 42;
    uint256 internal constant STARTED_AT = 1_699_999_900;
    uint256 internal constant UPDATED_AT = 1_700_000_000;
    uint80 internal constant ANSWERED_IN_ROUND = 43;

    function setUp() public {
        vm.warp(UPDATED_AT + 100);
        feed = new WstETHPriceFeed();
        vm.etch(address(feed.stEthToUsd()), hex"00");
        vm.etch(address(feed.wstETH()), hex"00");
        _mockRound(2500e8, UPDATED_AT);
        _mockRate(1.2e18);
    }

    function test_MainnetDependenciesAndDecimals() public view {
        assertEq(address(feed.wstETH()), 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
        assertEq(address(feed.stEthToUsd()), 0xCfE54B5cD566aB89272946F602D76Ea879CAb4a8);
        assertEq(feed.decimals(), 18);
    }

    function test_PriceAndMetadata() public view {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            feed.latestRoundData();

        assertEq(answer, 3000e18);
        assertEq(feed.latestAnswer(), answer);
        assertEq(roundId, ROUND_ID);
        assertEq(startedAt, STARTED_AT);
        assertEq(updatedAt, UPDATED_AT);
        assertEq(answeredInRound, ANSWERED_IN_ROUND);
    }

    function test_RoundsDownPositivePrice() public {
        _mockRound(1e8 + 1, UPDATED_AT);
        _mockRate(1e18 + 1);

        assertEq(feed.latestAnswer(), 1_000_000_010_000_000_001);
    }

    function test_ZeroPriceIsPassedThrough() public {
        _mockRound(0, UPDATED_AT);

        assertEq(feed.latestAnswer(), 0);
    }

    function test_NegativePriceIsPassedThrough() public {
        _mockRound(-2500e8, UPDATED_AT);

        assertEq(feed.latestAnswer(), -3000e18);
    }

    function test_StaleTimestampIsPassedThrough() public {
        vm.warp(UPDATED_AT + 30 days);

        (,,, uint256 updatedAt,) = feed.latestRoundData();
        assertEq(updatedAt, UPDATED_AT);
        assertEq(feed.latestAnswer(), 3000e18);
    }

    function test_ZeroTimestampIsPassedThrough() public {
        _mockRound(2500e8, 0);

        (,,, uint256 updatedAt,) = feed.latestRoundData();
        assertEq(updatedAt, 0);
        assertEq(feed.latestAnswer(), 3000e18);
    }

    function test_ChainlinkRevertPropagates() public {
        bytes memory reason = abi.encodeWithSignature("Error(string)", "Chainlink unavailable");
        vm.mockCallRevert(address(feed.stEthToUsd()), abi.encodeCall(IChainlinkFeed.latestRoundData, ()), reason);

        vm.expectRevert(reason);
        feed.latestRoundData();
        vm.expectRevert(reason);
        feed.latestAnswer();
    }

    function test_LidoRevertPropagates() public {
        bytes memory reason = abi.encodeWithSignature("Error(string)", "Lido unavailable");
        vm.mockCallRevert(address(feed.wstETH()), abi.encodeCall(IWstETH.stEthPerToken, ()), reason);

        vm.expectRevert(reason);
        feed.latestRoundData();
        vm.expectRevert(reason);
        feed.latestAnswer();
    }

    function test_MultiplicationOverflowReverts() public {
        _mockRound(type(int256).max, UPDATED_AT);

        vm.expectRevert(stdError.arithmeticError);
        feed.latestRoundData();
        vm.expectRevert(stdError.arithmeticError);
        feed.latestAnswer();
    }

    function testFuzz_Price(int256 stEthUsdPrice, int256 stEthPerToken) public {
        stEthUsdPrice = bound(stEthUsdPrice, 1, 1e16);
        stEthPerToken = bound(stEthPerToken, 1e18, 10e18);
        _mockRound(stEthUsdPrice, UPDATED_AT);
        // The rate is bounded above zero, so converting it to uint256 is safe.
        // forge-lint: disable-next-line(unsafe-typecast)
        _mockRate(uint256(stEthPerToken));

        (, int256 answer,,,) = feed.latestRoundData();
        assertGe(answer, 0);
        assertEq(feed.latestAnswer(), answer);
        // The returned price differs from the exact product by less than one output unit.
        assertLe(answer * 1e8, stEthUsdPrice * stEthPerToken);
        assertLt(stEthUsdPrice * stEthPerToken - answer * 1e8, 1e8);
    }

    function _mockRound(int256 price, uint256 updatedAt) internal {
        vm.mockCall(
            address(feed.stEthToUsd()),
            abi.encodeCall(IChainlinkFeed.latestRoundData, ()),
            abi.encode(ROUND_ID, price, STARTED_AT, updatedAt, ANSWERED_IN_ROUND)
        );
    }

    function _mockRate(uint256 rate) internal {
        vm.mockCall(address(feed.wstETH()), abi.encodeCall(IWstETH.stEthPerToken, ()), abi.encode(rate));
    }
}
