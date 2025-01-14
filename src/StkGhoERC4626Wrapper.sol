// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IStakeToken} from "./interfaces/IStakeToken.sol";
import {IERC4626, IERC20, IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IQuoter} from "./interfaces/IQuoter.sol";
import {ISwapRouter} from "./interfaces/ISwapRouter.sol";
import {IGsm} from "./interfaces/IGsm.sol";

import "forge-std/Test.sol";

contract StkGhoERC4626Wrapper is IERC4626, ERC20 {
    address public constant STK_GHO =
        0x1a88Df1cFe15Af22B3c4c783D4e6F7F9e0C1885d;
    address public constant GHO = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;

    address public constant AAVE = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    uint24 public constant AAVE_USDC_UNIV3_FEE = 3000;
    IGsm public constant USDC_GSM =
        IGsm(0x0d8eFfC11dF3F229AA1EA0509BC9DFa632A13578);

    address public constant QUOTER = 0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6;
    ISwapRouter public constant SWAP_ROUTER =
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    modifier withMigrate(uint256 keepAssets) {
        uint256 rewards = IStakeToken(STK_GHO).getTotalRewardsBalance(
            address(this)
        );
        if (rewards > 0) {
            _migrateRewards(keepAssets);
        }
        _;
    }

    constructor() ERC20("Wrapped StkGho", "WStkGho") {}

    /* --- IERC4626 --- */
    /// @inheritdoc IERC4626
    function asset() external pure returns (address) {
        return GHO;
    }

    /// @inheritdoc IERC4626
    function totalAssets() public view returns (uint256) {
        uint256 rewards = IStakeToken(STK_GHO).getTotalRewardsBalance(
            address(this)
        );
        uint256 shares = IERC20(STK_GHO).balanceOf(address(this));

        uint256 ghoFromReward = rewards == 0
            ? 0
            : _rewardToUnderlyingExactInput(rewards);
        uint256 ghoFromShare = shares == 0
            ? 0
            : IStakeToken(STK_GHO).previewRedeem(shares);

        return ghoFromReward + ghoFromShare;
    }

    /// @inheritdoc IERC4626
    function convertToShares(uint256 assets) external view returns (uint256) {
        return _assetToShare(assets);
    }

    /// @inheritdoc IERC4626
    function convertToAssets(uint256 shares) external view returns (uint256) {
        return _shareToAsset(shares);
    }

    /// @inheritdoc IERC4626
    function maxDeposit(
        address // receiver
    ) external pure virtual returns (uint256 maxAssets) {
        return 2 ** 256 - 1;
    }

    /// @inheritdoc IERC4626
    function previewDeposit(uint256 assets) external view returns (uint256) {
        return _assetToShare(assets);
    }

    /// @inheritdoc IERC4626
    function deposit(
        uint256 assets,
        address receiver
    ) external withMigrate(type(uint256).max) returns (uint256 shares) {
        shares = _assetToShare(assets);

        IERC20(GHO).transferFrom(msg.sender, address(this), assets);

        uint256 stakeAmount = IERC20(GHO).balanceOf(address(this));
        IERC20(GHO).approve(STK_GHO, stakeAmount);
        IStakeToken(STK_GHO).stake(address(this), stakeAmount);

        _mint(receiver, shares);
    }

    /// @inheritdoc IERC4626
    function maxMint(
        address // receiver
    ) external pure virtual returns (uint256) {
        return 2 ** 256 - 1;
    }

    /// @inheritdoc IERC4626
    function previewMint(uint256 shares) external view returns (uint256) {
        return _shareToAsset(shares);
    }

    /// @inheritdoc IERC4626
    function mint(
        uint256 shares,
        address receiver
    ) external withMigrate(type(uint256).max) returns (uint256 assets) {
        assets = _shareToAsset(shares);

        IERC20(GHO).transferFrom(msg.sender, address(this), assets);

        uint256 stakeAmount = IERC20(GHO).balanceOf(address(this));
        IERC20(GHO).approve(STK_GHO, stakeAmount);
        IStakeToken(STK_GHO).stake(address(this), stakeAmount);

        _mint(receiver, shares);
    }

    /// @inheritdoc IERC4626
    function maxWithdraw(
        address owner
    ) external view virtual returns (uint256 maxAssets) {
        uint256 shares = balanceOf(owner);
        maxAssets = _shareToAsset(shares);
    }

    /// @inheritdoc IERC4626
    function previewWithdraw(
        uint256 assets
    ) external view returns (uint256 shares) {
        shares = _assetToShare(assets);
    }

    /// @inheritdoc IERC4626
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external virtual returns (uint256 shares) {
        uint256 swappedAsset = _migrateRewards(assets);
        shares = _assetToShare(assets);

        if (swappedAsset < assets) {
            uint256 stkGhoRedeemAmount = IStakeToken(STK_GHO).previewStake(
                assets - swappedAsset
            );
            IERC20(STK_GHO).approve(STK_GHO, stkGhoRedeemAmount);
            IStakeToken(STK_GHO).redeem(address(this), stkGhoRedeemAmount);
        }
        IERC20(GHO).transfer(receiver, assets);

        _burn(owner, shares);
    }

    /// @inheritdoc IERC4626
    function maxRedeem(address owner) external view returns (uint256) {
        uint256 shares = balanceOf(owner);
        return shares;
    }

    /// @inheritdoc IERC4626
    function previewRedeem(
        uint256 shares
    ) external view virtual returns (uint256 assets) {
        assets = _shareToAsset(shares);
    }

    /// @inheritdoc IERC4626
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) external virtual returns (uint256 assets) {
        assets = _shareToAsset(shares);
        uint256 swappedAsset = _migrateRewards(assets);

        if (swappedAsset < assets) {
            uint256 stkGhoRedeemAmount = IStakeToken(STK_GHO).previewStake(
                assets - swappedAsset
            );
            IERC20(STK_GHO).approve(STK_GHO, stkGhoRedeemAmount);
            IStakeToken(STK_GHO).redeem(address(this), stkGhoRedeemAmount);
        }
        IERC20(GHO).transfer(receiver, assets);

        _burn(owner, shares);
    }

    function _assetToShare(
        uint256 assets
    ) internal view returns (uint256 shares) {
        uint256 totalAssetsTemp = totalAssets();
        if (totalAssetsTemp == 0) {
            shares = assets;
        } else {
            shares = (assets * totalSupply()) / totalAssetsTemp;
        }
    }

    function _shareToAsset(
        uint256 shares
    ) internal view returns (uint256 assets) {
        uint256 totalSupplyTemp = totalSupply();
        if (totalSupplyTemp == 0) {
            assets = shares;
        } else {
            assets = (shares * totalAssets()) / totalSupplyTemp;
        }
    }

    function _migrateRewards(
        uint256 keepAssets
    ) internal returns (uint256 assets) {
        uint256 rewards = IStakeToken(STK_GHO).getTotalRewardsBalance(
            address(this)
        );
        IStakeToken(STK_GHO).claimRewards(address(this), rewards);

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
        (, assets) = USDC_GSM.sellAsset(usdcAmount, address(this));

        uint256 stakeAmounts = keepAssets < assets
            ? assets - keepAssets
            : assets;

        if (stakeAmounts > 0) {
            IERC20(GHO).approve(STK_GHO, assets);
            IStakeToken(STK_GHO).stake(address(this), assets);
        }
    }

    function _rewardToUnderlyingExactInput(
        uint256 rewards
    ) internal view returns (uint256 underlying) {
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

        (, underlying, , ) = USDC_GSM.getGhoAmountForSellAsset(usdcAmount);
    }
}
