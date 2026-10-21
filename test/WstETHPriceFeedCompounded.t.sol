// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, stdError} from "forge-std/Test.sol";
import {IChainlinkFeed, IWstETH} from "../src/WstETHPriceFeed.sol";
import {WstETHPriceFeedCompounded} from "../src/WstETHPriceFeedCompounded.sol";

contract WstETHPriceFeedCompoundedTest is Test {
    WstETHPriceFeedCompounded internal feed;

    uint80 internal constant ROUND_ID = 42;
    uint256 internal constant STARTED_AT = 1_699_999_900;
    uint256 internal constant UPDATED_AT = 1_700_000_000;
    uint80 internal constant ANSWERED_IN_ROUND = 43;

    function setUp() public {
        vm.warp(UPDATED_AT + 100);
        feed = new WstETHPriceFeedCompounded();
        vm.etch(address(feed.wstETH()), hex"00");
        vm.etch(address(feed.stEthToEth()), hex"00");
        vm.etch(address(feed.ethToUsd()), hex"00");
        _mockRate(1.2e18);
        _mockStEthEth(0.99e18);
        _mockEthUsd(2500e8);
    }

    function test_MainnetDependenciesAndDecimals() public view {
        assertEq(address(feed.wstETH()), 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
        assertEq(address(feed.stEthToEth()), 0x86392dC19c0b719886221c78AB11eb8Cf5c52812);
        assertEq(address(feed.ethToUsd()), 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
        assertEq(feed.decimals(), 18);
    }

    function test_PriceAndMetadata() public view {
        _assertPrice(2970e18);
        // The oldest start and update timestamps come from different inputs.
        _assertMetadata(STARTED_AT - 10, UPDATED_AT);
    }

    function test_ParityAndPremium() public {
        _mockStEthEth(1e18);
        _assertPrice(3000e18);
        _mockStEthEth(1.01e18);
        _assertPrice(3030e18);
    }

    function test_DividesOnlyAfterAllMultiplications() public {
        _mockRate(1e18 + 1);
        _mockStEthEth(0.5e18);
        _mockEthUsd(2e8);

        // Dividing rate * stETH/ETH by 1e18 first would incorrectly lose the last unit.
        _assertPrice(1e18 + 1);
    }

    function test_RoundingTruncatesTowardZero() public {
        _mockRate(1e18 + 1);
        _mockStEthEth(0.5e18);
        _mockEthUsd(1e8);
        _assertPrice(0.5e18);

        _mockEthUsd(-1e8);
        _assertPrice(-0.5e18);
    }

    function test_ZeroRateIsUsedDirectly() public {
        _mockRate(0);
        _assertPrice(0);
    }

    function test_ZeroStEthEthAnswerIsUsedDirectly() public {
        _mockStEthEth(0);
        _assertPrice(0);
    }

    function test_ZeroEthUsdAnswerIsUsedDirectly() public {
        _mockEthUsd(0);
        _assertPrice(0);
    }

    function test_NegativeStEthEthAnswerIsUsedDirectly() public {
        _mockStEthEth(-0.99e18);
        _assertPrice(-2970e18);
    }

    function test_NegativeEthUsdAnswerIsUsedDirectly() public {
        _mockEthUsd(-2500e8);
        _assertPrice(-2970e18);
    }

    function test_TwoNegativeAnswersProducePositivePrice() public {
        _mockStEthEth(-0.99e18);
        _mockEthUsd(-2500e8);
        _assertPrice(2970e18);
    }

    function test_StEthEthTimestampsCanBothBeOlder() public {
        _mockTimestamps(STARTED_AT - 20, UPDATED_AT - 20, STARTED_AT, UPDATED_AT);
        _assertMetadata(STARTED_AT - 20, UPDATED_AT - 20);
    }

    function test_EthUsdTimestampsCanBothBeOlder() public {
        _mockTimestamps(STARTED_AT, UPDATED_AT, STARTED_AT - 20, UPDATED_AT - 20);
        _assertMetadata(STARTED_AT - 20, UPDATED_AT - 20);
    }

    function test_EqualTimestamps() public {
        _mockTimestamps(STARTED_AT, UPDATED_AT, STARTED_AT, UPDATED_AT);
        _assertMetadata(STARTED_AT, UPDATED_AT);
    }

    function test_ZeroTimestampsArePassedThroughFromEitherInput() public {
        _mockTimestamps(0, 0, STARTED_AT, UPDATED_AT);
        _assertMetadata(0, 0);
        _mockTimestamps(STARTED_AT, UPDATED_AT, 0, 0);
        _assertMetadata(0, 0);
    }

    function test_StaleTimestampsDoNotRejectPrice() public {
        vm.warp(UPDATED_AT + 30 days);
        _assertMetadata(STARTED_AT - 10, UPDATED_AT);
        _assertPrice(2970e18);
    }

    function test_FutureTimestampsDoNotRejectPrice() public {
        uint256 future = block.timestamp + 1 days;
        _mockTimestamps(future, future + 10, future + 1, future + 20);
        _assertMetadata(future, future + 10);
        _assertPrice(2970e18);
    }

    function test_StEthEthRevertPropagates() public {
        bytes memory reason = abi.encodeWithSignature("Error(string)", "stETH/ETH unavailable");
        vm.mockCallRevert(address(feed.stEthToEth()), abi.encodeCall(IChainlinkFeed.latestRoundData, ()), reason);
        _assertBothRevert(reason);
    }

    function test_EthUsdRevertPropagates() public {
        bytes memory reason = abi.encodeWithSignature("Error(string)", "ETH/USD unavailable");
        vm.mockCallRevert(address(feed.ethToUsd()), abi.encodeCall(IChainlinkFeed.latestRoundData, ()), reason);
        _assertBothRevert(reason);
    }

    function test_LidoRevertPropagates() public {
        bytes memory reason = abi.encodeWithSignature("Error(string)", "Lido unavailable");
        vm.mockCallRevert(address(feed.wstETH()), abi.encodeCall(IWstETH.stEthPerToken, ()), reason);
        _assertBothRevert(reason);
    }

    function test_FirstMultiplicationOverflowReverts() public {
        _mockRate(2);
        _mockStEthEth(type(int256).max);
        _mockEthUsd(1);
        _assertBothRevert(stdError.arithmeticError);
    }

    function test_SecondMultiplicationOverflowReverts() public {
        _mockRate(1);
        _mockStEthEth(2);
        _mockEthUsd(type(int256).max);
        _assertBothRevert(stdError.arithmeticError);
    }

    function testFuzz_Price(int256 rate, int256 stEthEthPrice, int256 ethUsdPrice) public {
        rate = bound(rate, 1e18, 10e18);
        stEthEthPrice = bound(stEthEthPrice, 1, 10e18);
        ethUsdPrice = bound(ethUsdPrice, 1, 1e16);
        // The bounded positive rate fits both uint256 and int256.
        // forge-lint: disable-next-line(unsafe-typecast)
        _mockRate(uint256(rate));
        _mockStEthEth(stEthEthPrice);
        _mockEthUsd(ethUsdPrice);

        (, int256 answer,,,) = feed.latestRoundData();
        assertEq(feed.latestAnswer(), answer);
        assertGe(answer, 0);
        int256 product = rate * stEthEthPrice * ethUsdPrice;
        assertLe(answer * 1e26, product);
        assertLt(product - answer * 1e26, 1e26);
    }

    function testFuzz_MetadataMinima(uint64 stEthStart, uint64 stEthUpdate, uint64 ethStart, uint64 ethUpdate) public {
        _mockTimestamps(stEthStart, stEthUpdate, ethStart, ethUpdate);
        _assertMetadata(
            stEthStart < ethStart ? stEthStart : ethStart, stEthUpdate < ethUpdate ? stEthUpdate : ethUpdate
        );
        _assertPrice(2970e18);
    }

    function _assertPrice(int256 expected) internal view {
        (, int256 answer,,,) = feed.latestRoundData();
        assertEq(answer, expected);
        assertEq(feed.latestAnswer(), expected);
    }

    function _assertMetadata(uint256 expectedStart, uint256 expectedUpdate) internal view {
        (uint80 roundId,, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = feed.latestRoundData();
        assertEq(roundId, ROUND_ID);
        assertEq(answeredInRound, ANSWERED_IN_ROUND);
        assertEq(startedAt, expectedStart);
        assertEq(updatedAt, expectedUpdate);
    }

    function _assertBothRevert(bytes memory reason) internal {
        vm.expectRevert(reason);
        feed.latestRoundData();
        vm.expectRevert(reason);
        feed.latestAnswer();
    }

    function _mockRate(uint256 rate) internal {
        vm.mockCall(address(feed.wstETH()), abi.encodeCall(IWstETH.stEthPerToken, ()), abi.encode(rate));
    }

    function _mockStEthEth(int256 price) internal {
        _mockRound(feed.stEthToEth(), 11, price, STARTED_AT - 10, UPDATED_AT + 10, 12);
    }

    function _mockEthUsd(int256 price) internal {
        _mockRound(feed.ethToUsd(), ROUND_ID, price, STARTED_AT, UPDATED_AT, ANSWERED_IN_ROUND);
    }

    function _mockTimestamps(uint256 stEthStart, uint256 stEthUpdate, uint256 ethStart, uint256 ethUpdate) internal {
        _mockRound(feed.stEthToEth(), 11, 0.99e18, stEthStart, stEthUpdate, 12);
        _mockRound(feed.ethToUsd(), ROUND_ID, 2500e8, ethStart, ethUpdate, ANSWERED_IN_ROUND);
    }

    function _mockRound(
        IChainlinkFeed oracle,
        uint80 roundId,
        int256 price,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) internal {
        vm.mockCall(
            address(oracle),
            abi.encodeCall(IChainlinkFeed.latestRoundData, ()),
            abi.encode(roundId, price, startedAt, updatedAt, answeredInRound)
        );
    }
}
