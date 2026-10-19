// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {WstETHPriceFeed} from "../src/WstETHPriceFeed.sol";

contract WstETHPriceFeedScript is Script {
    function run() public returns (WstETHPriceFeed feed) {
        vm.startBroadcast();
        feed = new WstETHPriceFeed();
        vm.stopBroadcast();
    }
}
