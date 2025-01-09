// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {StkGhoERC4626Wrapper} from "src/StkGhoERC4626Wrapper.sol";
import {IERC4626, IERC20, IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

contract StkGhoERC4626WrapperTest is Test {
    StkGhoERC4626Wrapper public stkGhoWrapper;
    address public stkGho;

    address public alice;
    address public bob;

    function setUp() public {
        vm.createSelectFork("mainnet");
        stkGhoWrapper = new StkGhoERC4626Wrapper();
        stkGho = stkGhoWrapper.STK_GHO();

        alice = makeAddr("alice");
        bob = makeAddr("bob");

        deal(stkGho, alice, 1_000e18);
    }
}

contract ERC20Test is StkGhoERC4626WrapperTest {
    function test_IERC20Metadata_functions() public {
        assertEq(stkGhoWrapper.name(), IERC20Metadata(stkGho).name());
        assertEq(stkGhoWrapper.symbol(), IERC20Metadata(stkGho).symbol());
        assertEq(stkGhoWrapper.decimals(), IERC20Metadata(stkGho).decimals());
    }

    function test_IERC20_view_functions() public {
        vm.prank(alice);
        IERC20(stkGho).approve(bob, 1e18);
        assertEq(stkGhoWrapper.totalSupply(), IERC20(stkGho).totalSupply());
        assertEq(
            stkGhoWrapper.balanceOf(alice),
            IERC20(stkGho).balanceOf(alice)
        );
        assertEq(
            stkGhoWrapper.allowance(alice, bob),
            IERC20(stkGho).allowance(alice, bob)
        );
    }

    function test_transfer() public {
        uint256 aliceBalanceBefore = stkGhoWrapper.balanceOf(alice);
        uint256 bobBalanceBefore = stkGhoWrapper.balanceOf(bob);

        vm.startPrank(alice);
        assertTrue(stkGhoWrapper.transfer(bob, 1e18));

        uint256 aliceBalanceAfter = stkGhoWrapper.balanceOf(alice);
        uint256 bobBalanceAfter = stkGhoWrapper.balanceOf(bob);

        assertEq(aliceBalanceBefore, aliceBalanceAfter + 1e18);
        assertEq(bobBalanceBefore, bobBalanceAfter - 1e18);

        vm.stopPrank();
    }
}
