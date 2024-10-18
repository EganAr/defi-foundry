// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/StdInvariant.sol";
import "src/DEX.sol";
import "script/HelperConfigDex.s.sol";
import "../mocks/ERC20Mock.sol";
import "../mocks/MockV3Aggregator.sol";

contract HandlerDex is Test {
    DEX dex;
    HelperConfigDex config;

    uint256 public constant MAX_DEPOSIT_AMOUNT = type(uint96).max;
    uint256 public constant MIN_DEPOSIT_AMOUNT = 10000;
    uint256 public constant ETH_PRICE_USD = 2000e18;
    uint256 constant PRICE_PRECISION = 1e18;
    uint256 public timeCalled;

    constructor(DEX _dex, HelperConfigDex _config) {
        dex = _dex;
        config = _config;
    }

    function addLiquidity(uint256 ethAmount) public {
        ethAmount = bound(ethAmount, MIN_DEPOSIT_AMOUNT, MAX_DEPOSIT_AMOUNT);
        uint256 daiAmount = (ethAmount * ETH_PRICE_USD) / PRICE_PRECISION;
        (address ethToken, address daiToken,,) = config.activeNetworkConfig();

        vm.startPrank(msg.sender);
        ERC20Mock(ethToken).approve(address(dex), ethAmount);
        ERC20Mock(daiToken).approve(address(dex), daiAmount);
        ERC20Mock(ethToken).faucet(msg.sender, ethAmount);
        ERC20Mock(daiToken).faucet(msg.sender, daiAmount);

        dex.addLiquidity(ethAmount, daiAmount);
        vm.stopPrank();
    }

    function removeLiquidity(uint256 ethAmount) public {
        (address ethToken, address daiToken,,) = config.activeNetworkConfig();
        ethAmount = bound(ethAmount, MIN_DEPOSIT_AMOUNT, MAX_DEPOSIT_AMOUNT);
        uint256 daiAmount = (ethAmount * ETH_PRICE_USD) / PRICE_PRECISION;
        uint256 lpToken;

        vm.startPrank(msg.sender);
        ERC20Mock(ethToken).approve(address(dex), ethAmount);
        ERC20Mock(daiToken).approve(address(dex), daiAmount);
        ERC20Mock(ethToken).faucet(msg.sender, ethAmount);
        ERC20Mock(daiToken).faucet(msg.sender, daiAmount);

        lpToken = dex.addLiquidity(ethAmount, daiAmount);
        dex.removeLiquidity(lpToken);
        vm.stopPrank();
    }

    modifier addingLiquidity(uint256 ethAmount) {
        ethAmount = bound(ethAmount, MIN_DEPOSIT_AMOUNT, MAX_DEPOSIT_AMOUNT);
        uint256 daiAmount = (ethAmount * ETH_PRICE_USD) / PRICE_PRECISION;
        (address ethToken, address daiToken,,) = config.activeNetworkConfig();

        vm.startPrank(msg.sender);
        ERC20Mock(ethToken).approve(address(dex), ethAmount);
        ERC20Mock(daiToken).approve(address(dex), daiAmount);
        ERC20Mock(ethToken).faucet(msg.sender, ethAmount);
        ERC20Mock(daiToken).faucet(msg.sender, daiAmount);

        dex.addLiquidity(ethAmount, daiAmount);
        vm.stopPrank();
        _;
    }

    function swap(uint256 token, uint256 amount) public addingLiquidity(amount) {
        (uint256 totalEthSupply, uint256 totalDaiSupply) = dex.getLiquidityTotalSupply();
        (address ethToken,,,) = config.activeNetworkConfig();

        token = bound(token, 1, 2000);
        address tokenIn = _getTokenIn(token);

        if (tokenIn == ethToken) {
            uint256 maxValueEth = totalEthSupply / 2;
            amount = bound(amount, MIN_DEPOSIT_AMOUNT, maxValueEth);
        } else {
            uint256 maxValueDai = totalDaiSupply / 2;
            amount = bound(amount, MIN_DEPOSIT_AMOUNT, maxValueDai);
        }

        uint256 minAmountOut = dex.getOutputAmount(tokenIn, amount);

        vm.startPrank(msg.sender);
        ERC20Mock(tokenIn).approve(address(dex), amount);
        ERC20Mock(tokenIn).faucet(msg.sender, amount);

        dex.swap(tokenIn, amount, minAmountOut);
        vm.stopPrank();
    }

    function _getTokenIn(uint256 tokenIn) public view returns (address) {
        (address ethToken, address daiToken,,) = config.activeNetworkConfig();
        if (tokenIn % 2 == 0) {
            return ethToken;
        }

        return daiToken;
    }
}
