// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "src/LendingBorrowing.sol";
import "script/DeployLendingBorrowing.s.sol";
import "script/HelperConfig.s.sol";
import "./mocks/MockDAI.sol";
import "./mocks/MockCollateral.sol";
import "./mocks/MockV3Aggregator.sol";

contract LendingTest is Test {
    LendingBorrowing lending;
    HelperConfig config;
    DeployLendingBorrowing deployer;

    address public RANDOM_USER = makeAddr("RandomUser");
    address public liquidator = makeAddr("liquidator");

    function setUp() public {
        deployer = new DeployLendingBorrowing();
        (lending, config) = deployer.deployLendingBorrowing();
    }

    modifier ApproveDAIAndCollateralThenDepositRandomUserDAI() {
        vm.startPrank(RANDOM_USER);
        (address Dai, address Collateral,) = config.activeConfig();
        MockDAI(Dai).approve(address(lending), 100000 ether);
        MockDAI(Dai).faucet(address(lending), 100000 ether);

        MockDAI(Dai).faucet(RANDOM_USER, 100 ether);

        MockCollateral(Collateral).approve(address(lending), 100 ether);
        MockCollateral(Collateral).faucet(RANDOM_USER, 100 ether);
        vm.stopPrank();
        _;
    }

    function testDepositDAI() public ApproveDAIAndCollateralThenDepositRandomUserDAI {
        vm.prank(RANDOM_USER);
        lending.deposit(10 ether);

        (address Dai,,) = config.activeConfig();
        uint256 deposited = lending.getUserDeposit(RANDOM_USER, Dai);
        assertEq(deposited, 10 ether);
    }

    function testRevertDepositDaiTransferFailed() public ApproveDAIAndCollateralThenDepositRandomUserDAI {
        (address Dai,,) = config.activeConfig();
        MockDAI(Dai).setTransferFromShouldFail(true);
        vm.prank(RANDOM_USER);
        vm.expectRevert(LendingBorrowing.LendingBorrowing__TransferFailed.selector);
        lending.deposit(10 ether);
    }

    function testRevertUserDepositMustGreaterThanZero() public ApproveDAIAndCollateralThenDepositRandomUserDAI {
        vm.prank(RANDOM_USER);
        vm.expectRevert(LendingBorrowing.LendingBorrowing__MustGreaterThanZero.selector);
        lending.deposit(0);
    }

    function testWithdrawDAI() public ApproveDAIAndCollateralThenDepositRandomUserDAI {
        vm.startPrank(RANDOM_USER);
        uint256 amount = 10 ether;
        lending.deposit(amount);
        lending.withdraw(amount);
        vm.stopPrank();

        (address Dai,,) = config.activeConfig();
        uint256 withdrawn = lending.getUserDeposit(RANDOM_USER, Dai);
        uint256 depositTime = lending.getUserTimestamp(RANDOM_USER, Dai);

        assertEq(withdrawn, 0);
        assertEq(depositTime, 0);
    }

    function testRevertWithdrawDAITransferFailed() public ApproveDAIAndCollateralThenDepositRandomUserDAI {
        (address Dai,,) = config.activeConfig();
        vm.startPrank(RANDOM_USER);
        lending.deposit(10 ether);

        MockDAI(Dai).setTransferFromShouldFail(true);
        vm.expectRevert(LendingBorrowing.LendingBorrowing__TransferFailed.selector);
        lending.withdraw(10 ether);
        vm.stopPrank();
    }

    function testRevertWithdrawDAITooMuch() public ApproveDAIAndCollateralThenDepositRandomUserDAI {
        vm.prank(RANDOM_USER);
        lending.deposit(10 ether);

        vm.prank(RANDOM_USER);
        vm.expectRevert(LendingBorrowing.LendingBorrowing__InsufficientBalance.selector);
        lending.withdraw(11 ether);
    }

    function testDepositCollateral() public ApproveDAIAndCollateralThenDepositRandomUserDAI {
        (, address Collateral,) = config.activeConfig();
        vm.prank(RANDOM_USER);
        lending.depositCollateral(10 ether);

        uint256 deposited = lending.getUserCollateral(RANDOM_USER, Collateral);
        uint256 totalDeposited = lending.getTotalCollateralValue();
        console.log("deposited", deposited);
        console.log("totalDeposited", totalDeposited);
        assertEq(deposited, 10 ether);
        assertEq(totalDeposited, 20000 ether);
    }

    function testRevertDepositCollateralTransferFailed() public ApproveDAIAndCollateralThenDepositRandomUserDAI {
        (, address Collateral,) = config.activeConfig();
        MockCollateral(Collateral).setTransferFromShouldFail(true);
        vm.prank(RANDOM_USER);
        vm.expectRevert(LendingBorrowing.LendingBorrowing__TransferFailed.selector);
        lending.depositCollateral(10 ether);
    }

    function testRedeemCollateral() public ApproveDAIAndCollateralThenDepositRandomUserDAI {
        (, address Collateral,) = config.activeConfig();
        vm.startPrank(RANDOM_USER);
        lending.depositCollateral(20 ether);
        lending.redeemCollateral(20 ether);
        vm.stopPrank();

        uint256 redeemed = lending.getUserCollateral(RANDOM_USER, Collateral);
        assertEq(redeemed, 0);
    }

    function testRevertRedeemCollateralTooMuch() public ApproveDAIAndCollateralThenDepositRandomUserDAI {
        vm.startPrank(RANDOM_USER);
        lending.depositCollateral(20 ether);

        vm.expectRevert(LendingBorrowing.LendingBorrowing__InsufficientCollateral.selector);
        lending.redeemCollateral(40 ether);
        vm.stopPrank();
    }

    function testRevertRedeemCollateralHealthFactorIsBroken() public ApproveDAIAndCollateralThenDepositRandomUserDAI {
        uint256 collateralAmount = 1e18;

        vm.startPrank(RANDOM_USER);
        lending.depositCollateral(collateralAmount);

        uint256 maxBorrowAmount = 100e18;
        lending.borrow(maxBorrowAmount);

        vm.expectRevert(abi.encodeWithSelector(LendingBorrowing.LendingBorrowing__HealthFactorIsBroken.selector, 0));
        lending.redeemCollateral(1e18);

        vm.stopPrank();
    }

    function testRevertRedeemCollateralTransferFailed() public ApproveDAIAndCollateralThenDepositRandomUserDAI {
        (, address Collateral,) = config.activeConfig();
        vm.startPrank(RANDOM_USER);
        lending.depositCollateral(20 ether);

        MockCollateral(Collateral).setTransferFromShouldFail(true);
        vm.expectRevert(LendingBorrowing.LendingBorrowing__TransferFailed.selector);
        lending.redeemCollateral(20 ether);
        vm.stopPrank();
    }

    function testBorrow() public ApproveDAIAndCollateralThenDepositRandomUserDAI {
        uint256 collateralAmount = 1e18;

        vm.startPrank(RANDOM_USER);
        lending.depositCollateral(collateralAmount);

        uint256 borrowLimit = lending.getBorrowLimit(RANDOM_USER);
        uint256 maxBorrowAmount = borrowLimit - 1e18;

        lending.borrow(maxBorrowAmount);
        vm.stopPrank();

        (address Dai,,) = config.activeConfig();
        uint256 borrowed = lending.getUserBorrow(RANDOM_USER, Dai);
        uint256 totalBorrowed = lending.getTotalBorrows();
        console.log("totalBorrowed", totalBorrowed);
        assertEq(borrowed, maxBorrowAmount);
    }

    function testRevertBorrowInsufficientCollateral() public ApproveDAIAndCollateralThenDepositRandomUserDAI {
        uint256 collateralAmount = 1e18;

        vm.startPrank(RANDOM_USER);
        lending.depositCollateral(collateralAmount);

        uint256 maxBorrowAmount = 1499e18;
        lending.borrow(maxBorrowAmount);
        vm.expectRevert(LendingBorrowing.LendingBorrowing__InsufficientCollateral.selector);
        lending.borrow(maxBorrowAmount);
        vm.stopPrank();
    }

    function testRevertBorrowTransferFailed() public ApproveDAIAndCollateralThenDepositRandomUserDAI {
        (address Dai,,) = config.activeConfig();
        uint256 collateralAmount = 1e18;

        vm.startPrank(RANDOM_USER);
        lending.depositCollateral(collateralAmount);

        uint256 maxBorrowAmount = 100e18;
        MockDAI(Dai).setTransferFromShouldFail(true);
        vm.expectRevert(LendingBorrowing.LendingBorrowing__TransferFailed.selector);
        lending.borrow(maxBorrowAmount);
        vm.stopPrank();
    }

    function testRepayBorrow() public ApproveDAIAndCollateralThenDepositRandomUserDAI {
        uint256 collateralAmount = 1e18;

        vm.startPrank(RANDOM_USER);
        lending.depositCollateral(collateralAmount);

        uint256 borrowAmount = 100e18;
        lending.borrow(borrowAmount);

        lending.repayBorrow(borrowAmount);
        vm.stopPrank();

        (address Dai,,) = config.activeConfig();
        uint256 borrowed = lending.getUserBorrow(RANDOM_USER, Dai);
        console.log("borrowed after repay", borrowed);
        assertEq(borrowed, 0);
    }

    function testRevertRepayBorrowTooMuch() public ApproveDAIAndCollateralThenDepositRandomUserDAI {
        uint256 collateralAmount = 1e18;

        vm.startPrank(RANDOM_USER);
        lending.depositCollateral(collateralAmount);

        uint256 maxBorrowAmount = 100e18;
        lending.borrow(maxBorrowAmount);

        vm.expectRevert(LendingBorrowing.LendingBorrowing__InsufficientBalance.selector);
        lending.repayBorrow(maxBorrowAmount + 1e18);
        vm.stopPrank();
    }

    function testRevertRepayBorrowTransferFailed() public ApproveDAIAndCollateralThenDepositRandomUserDAI {
        (address Dai,,) = config.activeConfig();
        uint256 collateralAmount = 1e18;

        vm.startPrank(RANDOM_USER);
        lending.depositCollateral(collateralAmount);

        uint256 borrowAmount = 100e18;
        lending.borrow(borrowAmount);

        MockDAI(Dai).setTransferFromShouldFail(true);
        vm.expectRevert(LendingBorrowing.LendingBorrowing__TransferFailed.selector);
        lending.repayBorrow(borrowAmount);
        vm.stopPrank();
    }

    modifier Liquidate() {
        (address Dai, address Collateral, address PriceFeed) = config.activeConfig();
        uint256 collateralAmount = 1e18;
        uint256 borrowAmount = 100e18;

        vm.startPrank(RANDOM_USER);
        MockCollateral(Collateral).approve(address(lending), collateralAmount);
        MockCollateral(Collateral).faucet(RANDOM_USER, collateralAmount);
        MockCollateral(Collateral).faucet(address(lending), collateralAmount);

        MockDAI(Dai).approve(address(lending), borrowAmount);
        MockDAI(Dai).faucet(address(lending), borrowAmount);

        lending.depositCollateral(collateralAmount);
        lending.borrow(borrowAmount);
        vm.stopPrank();

        int256 updatedPriceFeed = 100e8;
        MockV3Aggregator(PriceFeed).updateAnswer(updatedPriceFeed);

        vm.startPrank(liquidator);
        MockDAI(Dai).approve(address(lending), borrowAmount);
        MockDAI(Dai).faucet(liquidator, borrowAmount);

        lending.liquidate(RANDOM_USER, borrowAmount);
        vm.stopPrank();
        _;
    }

    function testLiquidate() public Liquidate {
        (, address Collateral,) = config.activeConfig();

        uint256 liquidatorCollateralBalance = MockCollateral(Collateral).balanceOf(liquidator);
        uint256 tokenAmountFromDebtCovered = lending.getCollateralTokenAmountFromDai(100e18);
        uint256 expectedCollateral =
            tokenAmountFromDebtCovered + (tokenAmountFromDebtCovered * lending.LIQUIDATION_BONUS()) / 100;

        assertEq(liquidatorCollateralBalance, expectedCollateral);
    }

    function testRevertLiquidateHealthFactorNotBroken() public {
        (address Dai, address Collateral,) = config.activeConfig();
        uint256 collateralAmount = 1e18;
        uint256 borrowAmount = 100e18;

        vm.startPrank(RANDOM_USER);
        MockCollateral(Collateral).approve(address(lending), collateralAmount);
        MockCollateral(Collateral).faucet(RANDOM_USER, collateralAmount);
        MockCollateral(Collateral).faucet(address(lending), collateralAmount);

        MockDAI(Dai).approve(address(lending), borrowAmount);
        MockDAI(Dai).faucet(address(lending), borrowAmount);

        lending.depositCollateral(collateralAmount);
        lending.borrow(borrowAmount);
        vm.stopPrank();

        vm.startPrank(liquidator);
        MockDAI(Dai).approve(address(lending), borrowAmount);
        MockDAI(Dai).faucet(liquidator, borrowAmount);

        vm.expectRevert(LendingBorrowing.LendingBorrowing__HealthFactorIsNotBroken.selector);
        lending.liquidate(RANDOM_USER, borrowAmount);
        vm.stopPrank();
    }

    function testRevertLiquidateNotEnoughCollateral() public {
        (address Dai, address Collateral, address PriceFeed) = config.activeConfig();
        uint256 collateralAmount = 0.1e18;
        uint256 borrowAmount = 100e18;

        vm.startPrank(RANDOM_USER);
        MockCollateral(Collateral).approve(address(lending), collateralAmount);
        MockCollateral(Collateral).faucet(RANDOM_USER, collateralAmount);
        MockCollateral(Collateral).faucet(address(lending), collateralAmount);

        MockDAI(Dai).approve(address(lending), borrowAmount);
        MockDAI(Dai).faucet(address(lending), borrowAmount);

        lending.depositCollateral(collateralAmount);
        lending.borrow(borrowAmount);
        vm.stopPrank();

        int256 updatedPriceFeed = 100e8;
        MockV3Aggregator(PriceFeed).updateAnswer(updatedPriceFeed);

        vm.startPrank(liquidator);
        MockDAI(Dai).approve(address(lending), borrowAmount);
        MockDAI(Dai).faucet(liquidator, borrowAmount);

        vm.expectRevert(LendingBorrowing.LendingBorrowing__NotEnoughCollateral.selector);
        lending.liquidate(RANDOM_USER, borrowAmount);
        vm.stopPrank();
    }

    function testRevertLiquidateCannotFromHimself() public {
        (address Dai, address Collateral, address PriceFeed) = config.activeConfig();
        uint256 collateralAmount = 1e18;
        uint256 borrowAmount = 100e18;

        vm.startPrank(RANDOM_USER);
        MockCollateral(Collateral).approve(address(lending), collateralAmount);
        MockCollateral(Collateral).faucet(RANDOM_USER, collateralAmount);
        MockCollateral(Collateral).faucet(address(lending), collateralAmount);

        MockDAI(Dai).approve(address(lending), borrowAmount);
        MockDAI(Dai).faucet(address(lending), borrowAmount);

        lending.depositCollateral(collateralAmount);
        lending.borrow(borrowAmount);
        vm.stopPrank();

        int256 updatedPriceFeed = 100e8;
        MockV3Aggregator(PriceFeed).updateAnswer(updatedPriceFeed);

        vm.startPrank(RANDOM_USER);
        MockDAI(Dai).approve(address(lending), borrowAmount);
        MockDAI(Dai).faucet(RANDOM_USER, borrowAmount);

        vm.expectRevert(LendingBorrowing.LendingBorrowing__UserCannotLiquidateHimself.selector);
        lending.liquidate(RANDOM_USER, borrowAmount);
        vm.stopPrank();
    }

    function testRevertLiquidateTransferFailed() public {
        (address Dai, address Collateral, address PriceFeed) = config.activeConfig();
        uint256 collateralAmount = 1e18;
        uint256 borrowAmount = 100e18;

        vm.startPrank(RANDOM_USER);
        MockCollateral(Collateral).approve(address(lending), collateralAmount);
        MockCollateral(Collateral).faucet(RANDOM_USER, collateralAmount);
        MockCollateral(Collateral).faucet(address(lending), collateralAmount);

        MockDAI(Dai).approve(address(lending), borrowAmount);
        MockDAI(Dai).faucet(address(lending), borrowAmount);

        lending.depositCollateral(collateralAmount);
        lending.borrow(borrowAmount);
        vm.stopPrank();

        int256 updatedPriceFeed = 100e8;
        MockV3Aggregator(PriceFeed).updateAnswer(updatedPriceFeed);

        vm.startPrank(liquidator);
        MockDAI(Dai).approve(address(lending), borrowAmount);
        MockDAI(Dai).faucet(liquidator, borrowAmount);

        MockDAI(Dai).setTransferFromShouldFail(true);
        vm.expectRevert(LendingBorrowing.LendingBorrowing__TransferFailed.selector);
        lending.liquidate(RANDOM_USER, borrowAmount);
        vm.stopPrank();
    }
}
