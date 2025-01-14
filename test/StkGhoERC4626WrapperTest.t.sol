// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {StkGhoERC4626Wrapper} from "src/StkGhoERC4626Wrapper.sol";
import {IERC4626, IERC20, IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

contract StkGhoERC4626WrapperTest is Test {
    StkGhoERC4626Wrapper public stkGhoWrapper;
    address public stkGho;
    address public gho;

    address public alice;
    address public bob;

    function setUp() public {
        vm.createSelectFork("mainnet", 21623283);
        stkGhoWrapper = new StkGhoERC4626Wrapper();
        stkGho = stkGhoWrapper.STK_GHO();
        gho = stkGhoWrapper.GHO();

        alice = makeAddr("alice");
        bob = makeAddr("bob");

        deal(gho, alice, 1_000e18);
    }

    function test_default() public {
        assertEq(stkGhoWrapper.asset(), gho);
        assertEq(stkGhoWrapper.maxDeposit(address(0)), 2 ** 256 - 1);
        assertEq(stkGhoWrapper.maxMint(address(0)), 2 ** 256 - 1);
    }
}

contract DepositAndMintTest is StkGhoERC4626WrapperTest {
    uint256 public constant amount = 100e18;

    function test_deposit() public {
        uint256 totalAssetsBefore = stkGhoWrapper.totalAssets();
        uint256 previewedDeposit = stkGhoWrapper.previewDeposit(amount);

        vm.startPrank(alice);
        IERC20(gho).approve(address(stkGhoWrapper), amount);
        stkGhoWrapper.deposit(amount, alice);

        uint256 totalAssetsAfter = stkGhoWrapper.totalAssets();
        uint256 stkGhoBalance = IERC20(stkGho).balanceOf(
            address(stkGhoWrapper)
        );
        uint256 wStkGhoBalance = stkGhoWrapper.balanceOf(alice);

        assertEq(totalAssetsAfter, totalAssetsBefore + amount);
        assertEq(previewedDeposit, amount);
        assertEq(stkGhoBalance, amount);
        assertEq(wStkGhoBalance, amount);

        vm.stopPrank();
    }

    function test_mint() public {
        uint256 totalAssetsBefore = stkGhoWrapper.totalAssets();
        uint256 previewedMint = stkGhoWrapper.previewMint(amount);

        vm.startPrank(alice);
        IERC20(gho).approve(address(stkGhoWrapper), amount);
        stkGhoWrapper.mint(amount, alice);

        uint256 totalAssetsAfter = stkGhoWrapper.totalAssets();
        uint256 stkGhoBalance = IERC20(stkGho).balanceOf(
            address(stkGhoWrapper)
        );
        uint256 wStkGhoBalance = stkGhoWrapper.balanceOf(alice);

        assertEq(totalAssetsAfter, totalAssetsBefore + amount);
        assertEq(previewedMint, amount);
        assertEq(stkGhoBalance, amount);
        assertEq(wStkGhoBalance, amount);

        vm.stopPrank();
    }

    function test_depositWithMigrate() public {
        vm.startPrank(alice);

        IERC20(gho).approve(address(stkGhoWrapper), amount);
        stkGhoWrapper.deposit(amount, alice);

        uint256 totalAssetsBefore = stkGhoWrapper.totalAssets();
        vm.warp(block.timestamp + 30 * 24 * 60 * 60);

        uint256 totalAssetsAfter = stkGhoWrapper.totalAssets();

        assertGe(totalAssetsAfter, totalAssetsBefore);
        console.log(totalAssetsAfter);

        vm.stopPrank();
    }
}
