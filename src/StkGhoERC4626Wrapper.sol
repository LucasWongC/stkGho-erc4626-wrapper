// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {StakeTokenERC4626Wrapper, IERC20, IStakeToken, IERC4626} from "./StakeTokenERC4626Wrapper.sol";
import {IQuoter} from "./interfaces/IQuoter.sol";
import {ISwapRouter} from "./interfaces/ISwapRouter.sol";
import {IGsm} from "./interfaces/IGsm.sol";

contract StkGhoERC4626Wrapper is StakeTokenERC4626Wrapper {
    address public constant STK_GHO =
        0x1a88Df1cFe15Af22B3c4c783D4e6F7F9e0C1885d;

    address public constant AAVE = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    uint24 public constant AAVE_USDC_UNIV3_FEE = 3000;
    IGsm public constant USDC_GSM =
        IGsm(0x0d8eFfC11dF3F229AA1EA0509BC9DFa632A13578);

    address public constant QUOTER = 0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6;
    ISwapRouter public constant SWAP_ROUTER =
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    constructor() StakeTokenERC4626Wrapper(STK_GHO) {}

    /// @inheritdoc IERC4626
    function maxWithdraw(
        address owner
    ) public view override returns (uint256 maxAssets) {
        uint256 shares = IERC20(STAKE_TOKEN).balanceOf(owner);
        uint256 rewards = IStakeToken(STAKE_TOKEN).getTotalRewardsBalance(
            owner
        );

        bytes memory quoterCallData = abi.encodeWithSignature(
            "quoteExactInputSingle(address,address,uint24,uint256,uint160)",
            AAVE,
            USDC,
            AAVE_USDC_UNIV3_FEE,
            rewards,
            0
        );
        (bool success, bytes memory data) = QUOTER.staticcall(quoterCallData);

        require(success, "staticcall failed");
        uint256 usdcAmount = abi.decode(data, (uint256));

        (, uint256 ghoAmounts, , ) = USDC_GSM.getGhoAmountForSellAsset(
            usdcAmount
        );
        uint256 redeemAmount = IStakeToken(STAKE_TOKEN).previewRedeem(shares);

        maxAssets = redeemAmount + ghoAmounts;
    }

    function previewClaim(
        uint256 assets
    ) public view returns (uint256 rewards) {
        (uint256 usdcAmount, , , ) = USDC_GSM.getAssetAmountForSellAsset(
            assets
        );
        bytes memory quoterCallData = abi.encodeWithSignature(
            "quoteExactOutputSingle(address,address,uint24,uint256,uint160)",
            AAVE,
            USDC,
            AAVE_USDC_UNIV3_FEE,
            usdcAmount,
            0
        );
        (bool success, bytes memory data) = QUOTER.staticcall(quoterCallData);
        require(success, "staticcall failed");

        rewards = abi.decode(data, (uint256));
    }

    /// @inheritdoc IERC4626
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external override returns (uint256 redeemShares) {
        uint256 maxAssets = maxWithdraw(owner);
        uint256 claimAmount = maxAssets > assets ? assets : maxAssets;
        uint256 rewards = previewClaim(claimAmount);
        bytes memory data = abi.encodeWithSignature(
            "claimRewards(address,uint256)",
            address(this),
            rewards
        );

        (bool success, ) = STAKE_TOKEN.delegatecall(data);

        require(success, "Delegatecall failed");

        IERC20(AAVE).approve(address(SWAP_ROUTER), rewards);
        uint256 usdcAmount = SWAP_ROUTER.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: AAVE,
                tokenOut: USDC,
                fee: AAVE_USDC_UNIV3_FEE,
                recipient: address(this),
                deadline: block.timestamp + 100,
                amountIn: rewards,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );

        IERC20(USDC).approve(address(USDC_GSM), usdcAmount);
        (, uint256 ghoAmount) = USDC_GSM.sellAsset(usdcAmount, address(this));
        if (ghoAmount < claimAmount) revert();

        if (ghoAmount < assets) {
            redeemShares = IStakeToken(STAKE_TOKEN).previewStake(
                assets - ghoAmount
            );
            uint256 shares = IERC20(STAKE_TOKEN).balanceOf(owner);
            if (shares < redeemShares) revert();

            data = abi.encodeWithSignature(
                "redeem(address,uint256)",
                address(this),
                redeemShares
            );

            (success, ) = STAKE_TOKEN.delegatecall(data);

            require(success, "Delegatecall failed");
        }

        IERC20(ASSET).transfer(receiver, assets);
    }

    /// @inheritdoc IERC4626
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) external override returns (uint256 assets) {
        uint256 rewards = IStakeToken(STAKE_TOKEN).getTotalRewardsBalance(
            owner
        );
        bytes memory data = abi.encodeWithSignature(
            "claimRewards(address,uint256)",
            address(this),
            rewards
        );

        (bool success, ) = STAKE_TOKEN.delegatecall(data);

        require(success, "Delegatecall failed");

        IERC20(AAVE).approve(address(SWAP_ROUTER), rewards);
        uint256 usdcAmount = SWAP_ROUTER.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: AAVE,
                tokenOut: USDC,
                fee: AAVE_USDC_UNIV3_FEE,
                recipient: address(this),
                deadline: block.timestamp + 100,
                amountIn: rewards,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );

        IERC20(USDC).approve(address(USDC_GSM), usdcAmount);
        USDC_GSM.sellAsset(usdcAmount, address(this));

        data = abi.encodeWithSignature(
            "redeem(address,uint256)",
            address(this),
            shares
        );

        (success, ) = STAKE_TOKEN.delegatecall(data);

        require(success, "Delegatecall failed");

        assets = IERC20(ASSET).balanceOf(address(this));

        IERC20(ASSET).transfer(receiver, assets);
    }
}
