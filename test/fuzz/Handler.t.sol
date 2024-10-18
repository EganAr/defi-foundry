// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/StdInvariant.sol";
import "src/LendingBorrowing.sol";
import "script/HelperConfig.s.sol";
import "../mocks/MockDAI.sol";
import "../mocks/MockCollateral.sol";
import "../mocks/MockV3Aggregator.sol";

contract Handler is Test {
    LendingBorrowing lending;
    HelperConfig config;

    uint256 public constant MAX_DEPOSIT_AMOUNT = type(uint96).max;
    uint256 public timeCalled;

    constructor(LendingBorrowing _lending, HelperConfig _config) {
        lending = _lending;
        config = _config;
    }

    function deposit(uint256 _amount) public {
        _amount = bound(_amount, 1, MAX_DEPOSIT_AMOUNT);

        (address Dai,,) = config.activeConfig();
        vm.startPrank(msg.sender);
        MockDAI(Dai).approve(address(lending), _amount);
        MockDAI(Dai).faucet(msg.sender, _amount);

        lending.deposit(_amount);
        vm.stopPrank();
    }

    function withdraw(uint256 _amount) public {
        _amount = bound(_amount, 1, MAX_DEPOSIT_AMOUNT);

        (address Dai,,) = config.activeConfig();
        vm.startPrank(msg.sender);
        MockDAI(Dai).approve(address(lending), _amount);
        MockDAI(Dai).faucet(msg.sender, _amount);
        lending.deposit(_amount);

        uint256 withdrawn = lending.getUserDeposit(msg.sender, Dai);
        lending.withdraw(withdrawn);
        vm.stopPrank();
    }

    function depositCollateral(uint256 _amount) public {
        _amount = bound(_amount, 1, MAX_DEPOSIT_AMOUNT);

        (, address Collateral,) = config.activeConfig();
        vm.startPrank(msg.sender);
        MockCollateral(Collateral).approve(address(lending), _amount);
        MockCollateral(Collateral).faucet(msg.sender, _amount);

        lending.depositCollateral(_amount);
        vm.stopPrank();
    }

    function redeemCollateral(uint256 _amount) public {
        _amount = bound(_amount, 1, MAX_DEPOSIT_AMOUNT);

        (, address Collateral,) = config.activeConfig();
        vm.startPrank(msg.sender);
        MockCollateral(Collateral).approve(address(lending), _amount);
        MockCollateral(Collateral).faucet(msg.sender, _amount);

        lending.depositCollateral(_amount);
        lending.redeemCollateral(_amount);
        vm.stopPrank();
    }

    function borrow(uint256 _amount) public {
        _amount = bound(_amount, 1, MAX_DEPOSIT_AMOUNT);
        (address Dai, address Collateral,) = config.activeConfig();

        vm.startPrank(msg.sender);
        MockDAI(Dai).approve(address(lending), _amount);
        MockDAI(Dai).faucet(address(lending), _amount);
        MockDAI(Dai).faucet(msg.sender, _amount);

        MockCollateral(Collateral).approve(address(lending), _amount);
        MockCollateral(Collateral).faucet(msg.sender, _amount);

        lending.depositCollateral(_amount);
        lending.borrow(_amount);
        vm.stopPrank();
    }

    function repayBorrow(uint256 _amount) public {
        _amount = bound(_amount, 1, MAX_DEPOSIT_AMOUNT);
        (address Dai, address Collateral,) = config.activeConfig();

        vm.startPrank(msg.sender);
        MockDAI(Dai).approve(address(lending), _amount);
        MockDAI(Dai).faucet(address(lending), _amount);
        MockDAI(Dai).faucet(msg.sender, _amount);

        MockCollateral(Collateral).approve(address(lending), _amount);
        MockCollateral(Collateral).faucet(msg.sender, _amount);

        lending.depositCollateral(_amount);
        lending.borrow(_amount);
        lending.repayBorrow(_amount);
        vm.stopPrank();
    }
}
