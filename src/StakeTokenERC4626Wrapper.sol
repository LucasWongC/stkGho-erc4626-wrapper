// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IStakeToken} from "./interfaces/IStakeToken.sol";
import {IERC4626, IERC20, IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

abstract contract StakeTokenERC4626Wrapper is IERC4626 {
    address immutable STAKE_TOKEN;
    address immutable ASSET;

    constructor(address _stakeToken) {
        STAKE_TOKEN = _stakeToken;
        ASSET = IStakeToken(STAKE_TOKEN).STAKED_TOKEN();
    }

    /* --- IERC20Metadata --- */

    /// @inheritdoc IERC20Metadata
    function name() external view returns (string memory) {
        return IERC20Metadata(STAKE_TOKEN).name();
    }

    /// @inheritdoc IERC20Metadata
    function symbol() external view returns (string memory) {
        return IERC20Metadata(STAKE_TOKEN).symbol();
    }

    /// @inheritdoc IERC20Metadata
    function decimals() external view returns (uint8) {
        return IERC20Metadata(STAKE_TOKEN).decimals();
    }

    /* --- IERC20 --- */

    /// @inheritdoc IERC20
    function totalSupply() external view returns (uint256) {
        return IERC20(STAKE_TOKEN).totalSupply();
    }

    /// @inheritdoc IERC20
    function balanceOf(address account) external view returns (uint256) {
        return IERC20(STAKE_TOKEN).balanceOf(account);
    }

    /// @inheritdoc IERC20
    function transfer(address to, uint256 value) external returns (bool) {
        bytes memory data = abi.encodeWithSignature(
            "transfer(address,uint256)",
            to,
            value
        );

        (bool success, bytes memory returnData) = STAKE_TOKEN.delegatecall(
            data
        );

        require(success, "Delegatecall failed");

        if (returnData.length > 0) {
            return abi.decode(returnData, (bool));
        }

        return false;
    }

    /// @inheritdoc IERC20
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256) {
        return IERC20(STAKE_TOKEN).allowance(owner, spender);
    }

    /// @inheritdoc IERC20
    function approve(address spender, uint256 value) external returns (bool) {
        bytes memory data = abi.encodeWithSignature(
            "approve(address,uint256)",
            spender,
            value
        );

        (bool success, bytes memory returnData) = STAKE_TOKEN.delegatecall(
            data
        );

        require(success, "Delegatecall failed");

        if (returnData.length > 0) {
            return abi.decode(returnData, (bool));
        }

        return false;
    }

    /// @inheritdoc IERC20
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool) {
        bytes memory data = abi.encodeWithSignature(
            "transferFrom(address,address,uint256)",
            from,
            to,
            value
        );

        (bool success, bytes memory returnData) = STAKE_TOKEN.delegatecall(
            data
        );

        require(success, "Delegatecall failed");

        if (returnData.length > 0) {
            return abi.decode(returnData, (bool));
        }

        return false;
    }

    /* --- IERC4626 --- */
    /// @inheritdoc IERC4626
    function asset() external view returns (address) {
        return ASSET;
    }

    /// @inheritdoc IERC4626
    function totalAssets() external view returns (uint256) {
        return IERC20(ASSET).balanceOf(address(STAKE_TOKEN));
    }

    /// @inheritdoc IERC4626
    function convertToShares(uint256 assets) external view returns (uint256) {
        return IStakeToken(STAKE_TOKEN).previewStake(assets);
    }

    /// @inheritdoc IERC4626
    function convertToAssets(uint256 shares) external view returns (uint256) {
        return IStakeToken(STAKE_TOKEN).previewRedeem(shares);
    }

    /// @inheritdoc IERC4626
    function maxDeposit(
        address // receiver
    ) external pure virtual returns (uint256 maxAssets) {
        return 2 ** 256 - 1;
    }

    /// @inheritdoc IERC4626
    function previewDeposit(uint256 assets) external view returns (uint256) {
        return IStakeToken(STAKE_TOKEN).previewStake(assets);
    }

    /// @inheritdoc IERC4626
    function deposit(
        uint256 assets,
        address receiver
    ) external returns (uint256 shares) {
        IERC20(ASSET).transferFrom(msg.sender, address(this), assets);
        IERC20(ASSET).approve(STAKE_TOKEN, assets);
        shares = IStakeToken(STAKE_TOKEN).previewStake(assets);
        IStakeToken(STAKE_TOKEN).stake(receiver, assets);
    }

    /// @inheritdoc IERC4626
    function maxMint(
        address // receiver
    ) external pure virtual returns (uint256) {
        return 2 ** 256 - 1;
    }

    /// @inheritdoc IERC4626
    function previewMint(uint256 shares) external view returns (uint256) {
        return IStakeToken(STAKE_TOKEN).previewRedeem(shares);
    }

    /// @inheritdoc IERC4626
    function mint(
        uint256 shares,
        address receiver
    ) external returns (uint256 assets) {
        assets = IStakeToken(STAKE_TOKEN).previewRedeem(shares);
        IERC20(ASSET).transferFrom(msg.sender, address(this), assets);
        IERC20(ASSET).approve(STAKE_TOKEN, assets);
        IStakeToken(STAKE_TOKEN).stake(receiver, assets);
    }

    /// @inheritdoc IERC4626
    function maxWithdraw(
        address owner
    ) external view virtual returns (uint256 maxAssets);

    /// @inheritdoc IERC4626
    function previewWithdraw(
        uint256 assets
    ) external view returns (uint256 shares) {
        shares = IStakeToken(STAKE_TOKEN).previewStake(assets);
    }

    /// @inheritdoc IERC4626
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external virtual returns (uint256 shares);

    /// @inheritdoc IERC4626
    function maxRedeem(address owner) external view returns (uint256) {
        return IERC20(STAKE_TOKEN).balanceOf(owner);
    }

    /// @inheritdoc IERC4626
    function previewRedeem(
        uint256 shares
    ) external view virtual returns (uint256 assets) {
        assets = IStakeToken(STAKE_TOKEN).previewRedeem(shares);
    }

    /// @inheritdoc IERC4626
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) external virtual returns (uint256 assets);
}
