// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "src/LendingBorrowing.sol";
import "./HelperConfig.s.sol";

contract DeployLendingBorrowing is Script {
    function run() external {}

    function deployLendingBorrowing() public returns (LendingBorrowing, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (address Dai, address Collateral, address PriceFeed) = helperConfig.activeConfig();

        vm.startBroadcast();
        LendingBorrowing lendingBorrowing = new LendingBorrowing(Dai, Collateral, PriceFeed);
        vm.stopBroadcast();

        return (lendingBorrowing, helperConfig);
    }
}
