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

    function setUp() public virtual {
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
        vm.warp(block.timestamp + 256 * 24 * 60 * 60);

        uint256 totalAssetsAfter = stkGhoWrapper.totalAssets();

        assertGt(totalAssetsAfter, totalAssetsBefore);

        IERC20(gho).approve(address(stkGhoWrapper), amount);
        stkGhoWrapper.deposit(amount, alice);

        uint256 wStkGhoBalance = stkGhoWrapper.balanceOf(alice);
        assertLt(wStkGhoBalance, 2 * amount);

        vm.stopPrank();
    }

    function test_mintWithMigrate() public {
        vm.startPrank(alice);

        IERC20(gho).approve(address(stkGhoWrapper), amount);
        stkGhoWrapper.mint(amount, alice);

        uint256 totalAssetsBefore = stkGhoWrapper.totalAssets();
        vm.warp(block.timestamp + 256 * 24 * 60 * 60);

        uint256 totalAssetsAfter = stkGhoWrapper.totalAssets();

        assertGt(totalAssetsAfter, totalAssetsBefore);

        uint256 assets = stkGhoWrapper.previewMint(amount);
        IERC20(gho).approve(address(stkGhoWrapper), assets);
        stkGhoWrapper.mint(amount, alice);

        totalAssetsBefore = totalAssetsAfter;
        totalAssetsAfter = stkGhoWrapper.totalAssets();
        assertGt(totalAssetsAfter, 2 * amount);
        assertEq(totalAssetsAfter, totalAssetsBefore + assets);

        vm.stopPrank();
    }
}

contract WithdrawAndRedeemTest is StkGhoERC4626WrapperTest {
    uint256 amount = 100e18;

    function setUp() public override {
        super.setUp();

        vm.startPrank(alice);
        IERC20(gho).approve(address(stkGhoWrapper), amount);
        stkGhoWrapper.deposit(amount, alice);
        vm.stopPrank();
    }

    function test_withdrawFrom_stkGhoShares() public {
        uint256 totalAssetsBefore = stkGhoWrapper.totalAssets();
        uint256 previewedWithdraw = stkGhoWrapper.previewWithdraw(amount);
        uint256 ghoBalanceBefore = IERC20(gho).balanceOf(alice);

        vm.startPrank(alice);
        IERC20(stkGhoWrapper).approve(address(stkGhoWrapper), amount);
        stkGhoWrapper.withdraw(amount, alice, alice);

        uint256 totalAssetsAfter = stkGhoWrapper.totalAssets();
        uint256 stkGhoBalance = IERC20(stkGho).balanceOf(
            address(stkGhoWrapper)
        );
        uint256 wStkGhoBalance = stkGhoWrapper.balanceOf(alice);
        uint256 ghoBalanceAfter = IERC20(gho).balanceOf(alice);

        assertEq(totalAssetsAfter, totalAssetsBefore - amount);
        assertEq(previewedWithdraw, amount);
        assertEq(stkGhoBalance, 0);
        assertEq(wStkGhoBalance, 0);
        assertEq(ghoBalanceAfter, ghoBalanceBefore + amount);
    }
}
