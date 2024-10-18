// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/StdInvariant.sol";
import "src/DEX.sol";
import "src/DLPToken.sol";
import "script/DeployDex.s.sol";
import "script/HelperConfigDex.s.sol";
import "./HandlerDex.t.sol";

contract InvariantsDex is StdInvariant, Test {
    DEX dex;
    HelperConfigDex config;
    DeployDex deployer;
    HandlerDex handler;
    DLPToken lpToken;

    uint256 constant PRICE_PRECISION = 1e18;
    uint256 public constant ETH_PRICE_USD = 2000e18;
    uint256 constant THRESHOLD = 1e15;
    uint256 constant INITIAL_ETH_LIQUIDITY = 1 ether;
    uint256 constant MINIMUM_LIQUIDITY = 10000;

    function setUp() public {
        deployer = new DeployDex();
        (dex, config) = deployer.deployDex();

        handler = new HandlerDex(dex, config);
        targetContract(address(handler));

        (address ethToken, address daiToken,,) = config.activeNetworkConfig();
        uint256 initialDaiLiquidity = (INITIAL_ETH_LIQUIDITY * ETH_PRICE_USD) / PRICE_PRECISION;

        ERC20Mock(ethToken).faucet(address(this), INITIAL_ETH_LIQUIDITY);
        ERC20Mock(daiToken).faucet(address(this), initialDaiLiquidity);

        ERC20Mock(ethToken).approve(address(dex), INITIAL_ETH_LIQUIDITY);
        ERC20Mock(daiToken).approve(address(dex), initialDaiLiquidity);

        dex.addLiquidity(INITIAL_ETH_LIQUIDITY, initialDaiLiquidity);
    }

    function invariant_checkTotalSupply() public view {
        (address ethToken, address daiToken,,) = config.activeNetworkConfig();

        uint256 totalSupply = dex.getTotalLpTokens();
        uint256 ethBalance = IERC20(ethToken).balanceOf(address(dex));
        uint256 daiBalance = IERC20(daiToken).balanceOf(address(dex));

        console.log("totalSupply", totalSupply);
        console.log("totalBalance", ethBalance + daiBalance);

        assert(totalSupply > 0);
        assert(totalSupply <= ethBalance + daiBalance);
    }

    function invariant_checkMinimumLiquidity() public view {
        (address ethToken, address daiToken,,) = config.activeNetworkConfig();

        uint256 ethBalance = IERC20(ethToken).balanceOf(address(dex));
        uint256 daiBalance = IERC20(daiToken).balanceOf(address(dex));

        assert(ethBalance >= MINIMUM_LIQUIDITY);
        assert(daiBalance >= MINIMUM_LIQUIDITY);
    }

}
