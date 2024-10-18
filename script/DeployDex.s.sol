// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "src/DEX.sol";
import "./HelperConfigDex.s.sol";

contract DeployDex is Script {
    function run() external {}

    function deployDex() public returns (DEX, HelperConfigDex) {
        HelperConfigDex config = new HelperConfigDex();
        (address ethToken, address daiToken, address ethUsdPriceFeed, address daiUsdPriceFeed) =
            config.activeNetworkConfig();

        vm.startBroadcast();
        DEX dex = new DEX(ethToken, daiToken, ethUsdPriceFeed, daiUsdPriceFeed);
        vm.stopBroadcast();
        return (dex, config);
    }
}
