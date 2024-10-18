// HelperConfig.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {ERC20Mock} from "../test/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";

contract HelperConfigDex is Script {
    struct NetworkConfig {
        address ethToken;
        address daiToken;
        address ethUsdPriceFeed;
        address daiUsdPriceFeed;
    }

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant DAI_USD_PRICE = 1e8;

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilConfig();
        }
    }

    function getSepoliaConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            ethToken: 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9, // Sepolia WETH
            daiToken: 0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2, // Sepolia DAI still unknown
            ethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306, // Sepolia ETH/USD
            daiUsdPriceFeed: 0x14866185B1962B63C3Ea9E03Bc1da838bab34C19 // Sepolia DAI/USD
        });
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.ethToken != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();

        // Deploy Mocks
        ERC20Mock ethToken = new ERC20Mock("Wrapped ETH", "WETH");
        ERC20Mock daiToken = new ERC20Mock("DAI Stablecoin", "DAI");

        MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        MockV3Aggregator daiUsdPriceFeed = new MockV3Aggregator(DECIMALS, DAI_USD_PRICE);

        vm.stopBroadcast();

        return NetworkConfig({
            ethToken: address(ethToken),
            daiToken: address(daiToken),
            ethUsdPriceFeed: address(ethUsdPriceFeed),
            daiUsdPriceFeed: address(daiUsdPriceFeed)
        });
    }
}
