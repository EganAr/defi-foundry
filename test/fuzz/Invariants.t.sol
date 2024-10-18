// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/StdInvariant.sol";
import "src/LendingBorrowing.sol";
import "script/DeployLendingBorrowing.s.sol";
import "script/HelperConfig.s.sol";
import "./Handler.t.sol";

contract InvariantsTest is StdInvariant, Test {
    LendingBorrowing lending;
    HelperConfig config;
    DeployLendingBorrowing deployer;
    Handler handler;

    function setUp() public {
        deployer = new DeployLendingBorrowing();
        (lending, config) = deployer.deployLendingBorrowing();

        handler = new Handler(lending, config);
        targetContract(address(handler));
    }

    function invariant_solvencyCheck() public view {
        uint256 totalBorrows = lending.getTotalBorrows();
        uint256 totalCollateralValue = lending.getTotalCollateralValue();
        uint256 adjustedCollateralValue = (totalCollateralValue * lending.COLLATERAL_FACTOR()) / 100;

        assertLe(
            totalBorrows, adjustedCollateralValue, "Invariant violated: Total borrows exceeds adjusted collateral value"
        );

        // Logging untuk debugging
        console.log("Total Borrows:", totalBorrows);
        console.log("Total Collateral Value:", totalCollateralValue);
        console.log("Adjusted Collateral Value:", adjustedCollateralValue);
        console.log("Time Function Called", handler.timeCalled());
    }
}
