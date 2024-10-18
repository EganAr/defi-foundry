// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "test/mocks/MockDAI.sol";
import "test/mocks/MockCollateral.sol";
import "test/mocks/MockV3Aggregator.sol";

contract HelperConfig is Script {
    struct Config {
        address Dai;
        address Collateral;
        address PriceFeed;
    }

    Config public activeConfig;
    address DAI_TOKEN = 0x3e622317f8C93f7328350cF0B56d9eD4C620C5d6;
    address SEPOLIA_COLLATERAL_TOKEN = 0x3e622317f8C93f7328350cF0B56d9eD4C620C5d6; // token belum diinisialisasi
    address PRICE_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;

    constructor() {
        if (block.chainid == 11155111) {
            activeConfig = sepoliaConfig();
        } else {
            activeConfig = getOrCreateAnvilConfig();
        }
    }

    function sepoliaConfig() public view returns (Config memory) {
        return Config({Dai: DAI_TOKEN, Collateral: SEPOLIA_COLLATERAL_TOKEN, PriceFeed: PRICE_FEED});
    }

    function getOrCreateAnvilConfig() public returns (Config memory) {
        if (activeConfig.Dai != address(0)) {
            return activeConfig;
        }

        vm.startBroadcast();
        MockDAI mockDai = new MockDAI();
        MockCollateral mockCollateral = new MockCollateral();
        MockV3Aggregator mockPriceFeed = new MockV3Aggregator(8, 2000e8);
        vm.stopBroadcast();

        activeConfig =
            Config({Dai: address(mockDai), Collateral: address(mockCollateral), PriceFeed: address(mockPriceFeed)});

        return activeConfig;
    }
}
