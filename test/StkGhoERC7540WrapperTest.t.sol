// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {StkGhoERC7540Wrapper, IStkGhoERC7540Wrapper, IERC20, IStakeToken} from "src/StkGhoERC7540Wrapper.sol";

contract StkGhoERC7540WrapperTest is Test {
    event Deposit(
        address indexed sender,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );
    event Withdraw(
        address indexed sender,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );
    event RedeemRequest(
        address indexed controller,
        address indexed owner,
        uint256 indexed requestId,
        address sender,
        uint256 assets
    );

    StkGhoERC7540Wrapper public stkGhoWrapper;
    address public stkGho;
    address public gho;

    address public alice;
    address public bob;

    function setUp() public virtual {
        vm.createSelectFork("mainnet", 21623283);
        stkGhoWrapper = new StkGhoERC7540Wrapper();
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

contract DepositAndMintTest is StkGhoERC7540WrapperTest {
    uint256 public constant amount = 100e18;

    function test_deposit() public {
        uint256 totalAssetsBefore = stkGhoWrapper.totalAssets();
        uint256 previewedDeposit = stkGhoWrapper.previewDeposit(amount);

        vm.startPrank(alice);
        IERC20(gho).approve(address(stkGhoWrapper), amount);

        vm.expectEmit(true, true, true, true, address(stkGhoWrapper));
        emit Deposit(alice, alice, amount, amount);
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

        vm.expectEmit(true, true, true, true, address(stkGhoWrapper));
        emit Deposit(alice, alice, amount, amount);
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
}

contract WithdrawAndRedeemTest is StkGhoERC7540WrapperTest {
    uint256 amount = 100e18;

    function setUp() public override {
        super.setUp();

        vm.startPrank(alice);
        IERC20(gho).approve(address(stkGhoWrapper), amount);
        stkGhoWrapper.deposit(amount, alice);
        vm.stopPrank();
    }

    function test_withdraw() public {
        uint256 ghoBalanceBefore = IERC20(gho).balanceOf(alice);

        vm.startPrank(alice);
        IERC20(stkGhoWrapper).approve(address(stkGhoWrapper), amount);

        vm.expectRevert(IStkGhoERC7540Wrapper.RedeemDisabled.selector);
        stkGhoWrapper.withdraw(amount, alice, alice);

        vm.expectEmit(true, true, true, true, address(stkGhoWrapper));
        emit RedeemRequest(
            alice,
            alice,
            stkGhoWrapper.DEFAULT_REQUEST_ID(),
            alice,
            amount
        );
        stkGhoWrapper.requestRedeem(amount, alice, alice);

        uint256 pendingRedeemAmount = stkGhoWrapper.pendingRedeemRequest(
            0,
            alice
        );
        uint256 claimablePendingRedeemAmount = stkGhoWrapper
            .claimableRedeemRequest(0, alice);
        assertEq(pendingRedeemAmount, amount);
        assertEq(claimablePendingRedeemAmount, 0);

        uint256 cooldown = IStakeToken(stkGho).getCooldownSeconds();
        vm.warp(block.timestamp + cooldown + 1);

        pendingRedeemAmount = stkGhoWrapper.pendingRedeemRequest(0, alice);
        claimablePendingRedeemAmount = stkGhoWrapper.claimableRedeemRequest(
            0,
            alice
        );
        assertEq(pendingRedeemAmount, 0);
        assertEq(claimablePendingRedeemAmount, amount);

        vm.expectEmit(true, true, true, true, address(stkGhoWrapper));
        emit Withdraw(alice, alice, alice, amount, amount);
        stkGhoWrapper.withdraw(amount, alice, alice);

        pendingRedeemAmount = stkGhoWrapper.pendingRedeemRequest(0, alice);
        claimablePendingRedeemAmount = stkGhoWrapper.claimableRedeemRequest(
            0,
            alice
        );
        assertEq(pendingRedeemAmount, 0);
        assertEq(claimablePendingRedeemAmount, 0);
    }

    function test_redeem() public {
        uint256 ghoBalanceBefore = IERC20(gho).balanceOf(alice);

        vm.startPrank(alice);
        IERC20(stkGhoWrapper).approve(address(stkGhoWrapper), amount);

        vm.expectRevert(IStkGhoERC7540Wrapper.RedeemDisabled.selector);
        stkGhoWrapper.redeem(amount, alice, alice);

        vm.expectEmit(true, true, true, true, address(stkGhoWrapper));
        emit RedeemRequest(
            alice,
            alice,
            stkGhoWrapper.DEFAULT_REQUEST_ID(),
            alice,
            amount
        );
        stkGhoWrapper.requestRedeem(amount, alice, alice);

        uint256 pendingRedeemAmount = stkGhoWrapper.pendingRedeemRequest(
            0,
            alice
        );
        uint256 claimablePendingRedeemAmount = stkGhoWrapper
            .claimableRedeemRequest(0, alice);
        assertEq(pendingRedeemAmount, amount);
        assertEq(claimablePendingRedeemAmount, 0);

        uint256 cooldown = IStakeToken(stkGho).getCooldownSeconds();
        vm.warp(block.timestamp + cooldown + 1);

        pendingRedeemAmount = stkGhoWrapper.pendingRedeemRequest(0, alice);
        claimablePendingRedeemAmount = stkGhoWrapper.claimableRedeemRequest(
            0,
            alice
        );
        assertEq(pendingRedeemAmount, 0);
        assertEq(claimablePendingRedeemAmount, amount);

        vm.expectEmit(true, true, true, true, address(stkGhoWrapper));
        emit Withdraw(alice, alice, alice, amount, amount);
        stkGhoWrapper.redeem(amount, alice, alice);

        pendingRedeemAmount = stkGhoWrapper.pendingRedeemRequest(0, alice);
        claimablePendingRedeemAmount = stkGhoWrapper.claimableRedeemRequest(
            0,
            alice
        );
        assertEq(pendingRedeemAmount, 0);
        assertEq(claimablePendingRedeemAmount, 0);
    }
}
