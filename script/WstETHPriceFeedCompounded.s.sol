// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {WstETHPriceFeedCompounded} from "../src/WstETHPriceFeedCompounded.sol";

contract WstETHPriceFeedCompoundedScript is Script {
    function run() public returns (WstETHPriceFeedCompounded feed) {
        vm.startBroadcast();
        feed = new WstETHPriceFeedCompounded();
        vm.stopBroadcast();
    }
}
