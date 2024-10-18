// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "src/DEX.sol";
import "script/DeployDex.s.sol";
import "script/HelperConfigDex.s.sol";
import "./mocks/ERC20Mock.sol";
import "./mocks/MockV3Aggregator.sol";

contract DexTest is Test {
    DEX dex;
    HelperConfigDex config;
    DeployDex deployer;

    address public user = makeAddr("user");
    address public liquidator = makeAddr("liquidator");
    uint256 public ETH_FAUCET = 10 ether;
    uint256 public DAI_FAUCET = 20000 ether;

    function setUp() public {
        deployer = new DeployDex();
        (dex, config) = deployer.deployDex();
    }

    modifier approvedTokens() {
        vm.startPrank(liquidator);
        (address ethToken, address daiToken, address ethUsdPriceFeed, address daiUsdPriceFeed) =
            config.activeNetworkConfig();
        ERC20Mock(ethToken).approve(address(dex), ETH_FAUCET);
        ERC20Mock(daiToken).approve(address(dex), DAI_FAUCET);

        ERC20Mock(ethToken).faucet(liquidator, ETH_FAUCET);
        ERC20Mock(daiToken).faucet(liquidator, DAI_FAUCET);
        vm.stopPrank();
        _;
    }

    function testAddLiquidity() public approvedTokens {
        uint256 ethAmount = 1e18;
        uint256 daiAmount = 2000e18;
        vm.prank(liquidator);
        uint256 lpTokens = dex.addLiquidity(ethAmount, daiAmount);

        (uint256 ethBalance, uint256 daiBalance) = dex.getUserLiquidity(liquidator);
        (uint256 totalEthSupply, uint256 totalDaiSupply) = dex.getLiquidityTotalSupply();
        uint256 lpTokenBalance = dex.getLpTokensBalance(liquidator);

        assert(ethBalance == ethAmount);
        assert(daiBalance == daiAmount);
        assert(totalEthSupply == ethAmount);
        assert(totalDaiSupply == daiAmount);
        assertEq(lpTokenBalance, lpTokens);
    }

    function testRevertAddLiquidityCurrentRatioReturnsZero() public approvedTokens {
        (,, address ethUsdPriceFeed, address daiUsdPriceFeed) = config.activeNetworkConfig();
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(1e8);
        MockV3Aggregator(daiUsdPriceFeed).updateAnswer(2e26);

        uint256 ethAmount = 1e18;
        uint256 daiAmount = 2000e18;
        vm.prank(liquidator);
        vm.expectRevert(DEX.DEX__ZeroPrice.selector);
        dex.addLiquidity(ethAmount, daiAmount);
    }

    function testRevertAddLiquidityMoreThanZero() public approvedTokens {
        uint256 ethAmount = 0;
        uint256 daiAmount = 2000e18;
        vm.prank(liquidator);
        vm.expectRevert(DEX.DEX__MustGreaterThanZero.selector);
        dex.addLiquidity(ethAmount, daiAmount);
    }

    function testRevertAddLiquidityAmountTooHigh() public approvedTokens {
        uint256 ethAmount = type(uint256).max / 1e18;
        uint256 daiAmount = 2000e18;
        vm.startPrank(liquidator);
        (address ethToken,,,) = config.activeNetworkConfig();
        ERC20Mock(ethToken).approve(address(dex), ethAmount);
        ERC20Mock(ethToken).faucet(liquidator, ethAmount);
        vm.expectRevert(DEX.DEX__AmountTooHigh.selector);
        dex.addLiquidity(ethAmount, daiAmount);
        vm.stopPrank();
    }

    function testRevertAddLiquidityAmountTooLow() public approvedTokens {
        uint256 ethAmount = 1000;
        uint256 daiAmount = 1000;
        vm.prank(liquidator);
        vm.expectRevert(DEX.DEX__AmountTooLow.selector);
        dex.addLiquidity(ethAmount, daiAmount);
    }

    function testRevertAddLiquidityInvalidTokenRatio() public approvedTokens {
        uint256 ethAmount = 1e18;
        uint256 daiAmount = 1000e18;
        vm.prank(liquidator);
        vm.expectRevert(DEX.DEX__InvalidTokenRatio.selector);
        dex.addLiquidity(ethAmount, daiAmount);
    }

    function testRevertAddLiquidityTransferFailed() public approvedTokens {
        uint256 ethAmount = 1e18;
        uint256 daiAmount = 2000e18;
        (address ethToken,,,) = config.activeNetworkConfig();
        vm.startPrank(liquidator);
        ERC20Mock(ethToken).setTransferFromShouldFail(true);
        vm.expectRevert(DEX.DEX__TransferFailed.selector);
        dex.addLiquidity(ethAmount, daiAmount);
        vm.stopPrank();
    }

    function testRemoveLiquidity() public approvedTokens {
        uint256 ethAmount = 1e18;
        uint256 daiAmount = 2000e18;
        uint256 lpToken;

        vm.startPrank(liquidator);
        lpToken = dex.addLiquidity(ethAmount, daiAmount);
        lpToken = dex.addLiquidity(ethAmount, daiAmount);
        uint256 lpTokenBalance = dex.getLpTokensBalance(liquidator);
        console.log("lpTokenBalance", lpTokenBalance);
        dex.removeLiquidity(lpToken);
        vm.stopPrank();

        (uint256 ethBalance, uint256 daiBalance) = dex.getUserLiquidity(liquidator);
        lpTokenBalance = dex.getLpTokensBalance(liquidator);
        uint256 totalLpToken = dex.getTotalLpTokens();
        console.log("totalLpToken", totalLpToken);
        console.log("lpTokenBalance after", lpTokenBalance);
        assertEq(ethBalance, ethAmount);
        assertEq(daiBalance, daiAmount);
    }

    function testRevertRemoveLiquidityMoreThanZero() public approvedTokens {
        uint256 ethAmount = 1e18;
        uint256 daiAmount = 2000e18;
        uint256 lpToken;

        vm.startPrank(liquidator);
        lpToken = dex.addLiquidity(ethAmount, daiAmount);
        lpToken = dex.addLiquidity(ethAmount, daiAmount);

        vm.expectRevert(DEX.DEX__MustGreaterThanZero.selector);
        dex.removeLiquidity(0);
        vm.stopPrank();
    }

    function testRevertRemoveLiquidityInffuicientLiquidityBalance() public approvedTokens {
        uint256 ethAmount = 1e18;
        uint256 daiAmount = 2000e18;
        uint256 lpToken;

        vm.startPrank(liquidator);
        lpToken = dex.addLiquidity(ethAmount, daiAmount);
        lpToken = dex.addLiquidity(ethAmount, daiAmount);

        uint256 lpTokenBalance = dex.getLpTokensBalance(liquidator);
        vm.expectRevert(DEX.DEX__InsufficientLiquidityBalance.selector);
        dex.removeLiquidity(lpTokenBalance);
        vm.stopPrank();
    }

    function testRevertRemoveLiquidityTransferFailed() public approvedTokens {
        uint256 ethAmount = 1e18;
        uint256 daiAmount = 2000e18;
        uint256 lpToken;

        (address ethToken,,,) = config.activeNetworkConfig();
        vm.startPrank(liquidator);
        lpToken = dex.addLiquidity(ethAmount, daiAmount);
        lpToken = dex.addLiquidity(ethAmount, daiAmount);
        ERC20Mock(ethToken).setTransferFromShouldFail(true);
        vm.expectRevert(DEX.DEX__TransferFailed.selector);
        dex.removeLiquidity(lpToken);
        vm.stopPrank();
    }

    modifier addLiquidity() {
        uint256 ethAmount = ETH_FAUCET;
        uint256 daiAmount = DAI_FAUCET;
        vm.startPrank(liquidator);
        (address ethToken, address daiToken, address ethUsdPriceFeed, address daiUsdPriceFeed) =
            config.activeNetworkConfig();
        ERC20Mock(ethToken).approve(address(dex), ETH_FAUCET);
        ERC20Mock(daiToken).approve(address(dex), DAI_FAUCET);

        ERC20Mock(ethToken).faucet(liquidator, ETH_FAUCET);
        ERC20Mock(daiToken).faucet(liquidator, DAI_FAUCET);

        dex.addLiquidity(ethAmount, daiAmount);
        vm.stopPrank();
        _;
    }

    modifier approvedUser() {
        vm.startPrank(user);
        (address ethToken, address daiToken, address ethUsdPriceFeed, address daiUsdPriceFeed) =
            config.activeNetworkConfig();
        ERC20Mock(ethToken).approve(address(dex), ETH_FAUCET);
        ERC20Mock(daiToken).approve(address(dex), DAI_FAUCET);

        ERC20Mock(ethToken).faucet(user, ETH_FAUCET);
        ERC20Mock(daiToken).faucet(user, DAI_FAUCET);
        vm.stopPrank();
        _;
    }

    function testSwapToken() public addLiquidity approvedUser {
        (address ethToken,,,) = config.activeNetworkConfig();
        uint256 ethAmount = 0.1 ether;
        uint256 minAmountOut = 195e18;

        vm.startPrank(user, user);
        uint256 daiAmount = dex.swap(ethToken, ethAmount, minAmountOut);
        vm.stopPrank();

        console.log("daiAmount", daiAmount);
        assertGe(daiAmount, minAmountOut);
    }

    function testRevertSwapPriceCircuitBreak() public addLiquidity approvedUser {
        (address ethToken,, address ethUsdPriceFeed,) = config.activeNetworkConfig();
        uint256 ethAmount = 0.1 ether;
        uint256 minAmountOut = 190e18;

        vm.startPrank(user, user);
        dex.swap(ethToken, ethAmount, minAmountOut);
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(1500e8);
        vm.expectRevert(DEX.DEX__CircuitBreakerTriggered.selector);
        dex.swap(ethToken, ethAmount, minAmountOut);
        vm.stopPrank();
    }

    function testRevertRateLimited() public addLiquidity approvedUser {
        (address ethToken,,,) = config.activeNetworkConfig();
        uint256 ethAmount = 0.01 ether;
        uint256 minAmountOut = 10e18;

        for (uint256 i = 0; i < 10; i++) {
            vm.startPrank(user, user);
            uint256 daiAmount = dex.swap(ethToken, ethAmount, minAmountOut);
            console.log("daiAmount", daiAmount);
            vm.stopPrank();
        }

        vm.startPrank(user, user);
        vm.expectRevert(abi.encodeWithSelector(DEX.DEX__RateLimitExceeded.selector, 86399));
        dex.swap(ethToken, ethAmount, minAmountOut);
        vm.stopPrank();
    }

    function testRevertSwapFlashLoanProtection() public addLiquidity approvedUser {
        (address ethToken,,,) = config.activeNetworkConfig();
        uint256 ethAmount = 0.1 ether;
        uint256 minAmountOut = 195e18;

        vm.startPrank(user);
        vm.expectRevert(DEX.DEX__FlashLoanProtection.selector);
        dex.swap(ethToken, ethAmount, minAmountOut);
        vm.stopPrank();
    }

    function testRevertSwapInvalidToken() public addLiquidity approvedUser {
        ERC20Mock invalidToken = new ERC20Mock("Invalid Token", "INV");
        vm.startPrank(user, user);
        vm.expectRevert(DEX.DEX__InvalidSwapToken.selector);
        dex.swap(address(invalidToken), 1e18, 1e18);
        vm.stopPrank();
    }

    function testRevertSwapAmountTooHigh() public addLiquidity approvedUser {
        (address ethToken,,,) = config.activeNetworkConfig();
        uint256 ethAmount = 6 ether;
        uint256 minAmountOut = 1000e18;

        vm.startPrank(user, user);
        vm.expectRevert(DEX.DEX__AmountTooHigh.selector);
        dex.swap(ethToken, ethAmount, minAmountOut);
        vm.stopPrank();
    }

    function testRevertSwapExcessiveSlippage() public addLiquidity approvedUser {
        (address ethToken,,,) = config.activeNetworkConfig();
        uint256 ethAmount = 0.1 ether;
        uint256 minAmountOut = 200e18;

        vm.startPrank(user, user);
        vm.expectRevert(DEX.DEX__ExcessiveSlippage.selector);
        dex.swap(ethToken, ethAmount, minAmountOut);
        vm.stopPrank();
    }

    function testRevertSwapTransferFailed() public addLiquidity approvedUser {
        (address ethToken,,,) = config.activeNetworkConfig();
        uint256 ethAmount = 0.1 ether;
        uint256 minAmountOut = 195e18;

        vm.startPrank(user, user);
        ERC20Mock(ethToken).setTransferFromShouldFail(true);
        vm.expectRevert(DEX.DEX__TransferFailed.selector);
        dex.swap(ethToken, ethAmount, minAmountOut);
        vm.stopPrank();
    }
}
