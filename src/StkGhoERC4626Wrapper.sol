// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IStakeToken} from "./interfaces/IStakeToken.sol";
import {IUniswapV3StaticQuoter} from "./interfaces/IUniswapV3StaticQuoter.sol";
import {ISwapRouter} from "./interfaces/ISwapRouter.sol";
import {IGsm} from "./interfaces/IGsm.sol";
import {IERC7540Redeem, IERC7575} from "./interfaces/IERC7540.sol";

import "forge-std/Test.sol";

contract StkGhoERC4626Wrapper is IERC7540Redeem, ERC20 {
    address public constant STK_GHO =
        0x1a88Df1cFe15Af22B3c4c783D4e6F7F9e0C1885d;
    address public constant GHO = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;

    address public constant AAVE = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    uint24 public constant AAVE_USDC_UNIV3_FEE = 3000;
    IGsm public constant USDC_GSM =
        IGsm(0x0d8eFfC11dF3F229AA1EA0509BC9DFa632A13578);

    IUniswapV3StaticQuoter public constant QUOTER =
        IUniswapV3StaticQuoter(0xc80f61d1bdAbD8f5285117e1558fDDf8C64870FE);
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

    /* --- IERC7575 --- */
    /// @inheritdoc IERC7575
    function asset() external pure returns (address) {
        return GHO;
    }

    /// @inheritdoc IERC7575
    function share() external view returns (address) {
        return address(this);
    }

    /// @inheritdoc IERC7575
    function convertToShares(uint256 assets) external view returns (uint256) {
        return _assetToShare(assets);
    }

    /// @inheritdoc IERC7575
    function convertToAssets(uint256 shares) external view returns (uint256) {
        return _shareToAsset(shares);
    }

    /// @inheritdoc IERC7575
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

    /// @inheritdoc IERC7575
    function maxDeposit(
        address // receiver
    ) external pure virtual returns (uint256 maxAssets) {
        return 2 ** 256 - 1;
    }

    /// @inheritdoc IERC7575
    function previewDeposit(uint256 assets) external view returns (uint256) {
        return _assetToShare(assets);
    }

    /// @inheritdoc IERC7575
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

    /// @inheritdoc IERC7575
    function maxMint(
        address // receiver
    ) external pure virtual returns (uint256) {
        return 2 ** 256 - 1;
    }

    /// @inheritdoc IERC7575
    function previewMint(uint256 shares) external view returns (uint256) {
        return _shareToAsset(shares);
    }

    /// @inheritdoc IERC7575
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

    /// @inheritdoc IERC7575
    function maxWithdraw(
        address owner
    ) external view virtual returns (uint256 maxAssets) {
        uint256 shares = balanceOf(owner);
        maxAssets = _shareToAsset(shares);
    }

    /// @inheritdoc IERC7575
    function previewWithdraw(
        uint256 assets
    ) external view returns (uint256 shares) {
        shares = _assetToShare(assets);
    }

    /// @inheritdoc IERC7575
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

    /// @inheritdoc IERC7575
    function maxRedeem(address owner) external view returns (uint256) {
        uint256 shares = balanceOf(owner);
        return shares;
    }

    /// @inheritdoc IERC7575
    function previewRedeem(
        uint256 shares
    ) external view virtual returns (uint256 assets) {
        assets = _shareToAsset(shares);
    }

    /// @inheritdoc IERC7575
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
        if (rewards == 0) {
            return assets;
        }

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
        uint256 usdcAmount = QUOTER.quoteExactInputSingle(
            IUniswapV3StaticQuoter.QuoteExactInputSingleParams({
                tokenIn: AAVE,
                tokenOut: USDC,
                amountIn: rewards,
                fee: AAVE_USDC_UNIV3_FEE,
                sqrtPriceLimitX96: 0
            })
        );

        (, underlying, , ) = USDC_GSM.getGhoAmountForSellAsset(usdcAmount);
    }
}
