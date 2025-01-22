// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IStakeToken} from "./interfaces/IStakeToken.sol";
import {IUniswapV3StaticQuoter} from "./interfaces/IUniswapV3StaticQuoter.sol";
import {ISwapRouter} from "./interfaces/ISwapRouter.sol";
import {IGsm} from "./interfaces/IGsm.sol";
import {IERC7540Redeem, IERC7575, IERC7540Operator, IERC7575, IERC7540CancelRedeem, IAuthorizeOperator} from "./interfaces/IERC7540.sol";

import {EIP712Lib} from "./libraries/EIP712Lib.sol";
import {SignatureLib} from "./libraries/SignatureLib.sol";
import "forge-std/Test.sol";

contract StkGhoERC4626Wrapper is
    IERC7540Redeem,
    IERC7575,
    IAuthorizeOperator,
    ERC20
{
    address public constant STK_GHO =
        0x1a88Df1cFe15Af22B3c4c783D4e6F7F9e0C1885d;
    address public constant GHO = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;

    address public constant AAVE = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    uint24 public constant AAVE_USDC_UNIV3_FEE = 3000;
    IGsm public constant USDC_GSM =
        IGsm(0x0d8eFfC11dF3F229AA1EA0509BC9DFa632A13578);

    uint8 public constant PRECISION = 18;

    IUniswapV3StaticQuoter public constant QUOTER =
        IUniswapV3StaticQuoter(0xc80f61d1bdAbD8f5285117e1558fDDf8C64870FE);
    ISwapRouter public constant SWAP_ROUTER =
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    /// @dev to calculate rewards
    mapping(address user => uint256 index) public userIndex;
    mapping(address user => uint256 rewards) public stackedRewards;

    /// @inheritdoc IERC7540Operator
    mapping(address => mapping(address => bool)) public isOperator;

    uint256 public constant DEFAULT_REQUEST_ID = 0;

    bytes32 private immutable nameHash;
    bytes32 private immutable versionHash;
    /// @inheritdoc IAuthorizeOperator
    bytes32 public immutable DOMAIN_SEPARATOR;
    bytes32 public constant AUTHORIZE_OPERATOR_TYPEHASH =
        keccak256(
            "AuthorizeOperator(address controller,address operator,bool approved,bytes32 nonce,uint256 deadline)"
        );
    mapping(address controller => mapping(bytes32 nonce => bool used))
        public authorizations;

    error InvalidOperator();
    error InvalidController();
    error AlreadyClaimed();
    error TimeExpired();
    error InvalidNonce();
    error InvalidSignature();

    modifier withClaim() {
        uint256 rewards = IStakeToken(STK_GHO).getTotalRewardsBalance(
            address(this)
        );
        if (rewards > 0) {
            _claimRewards(rewards);
        }
        _;
    }

    /// @dev trigger cooldown
    modifier withCooldown() {
        (, bool triggerenable) = _checkRedeemable();
        if (triggerenable) {
            IStakeToken(STK_GHO).cooldown();
        }

        _;
    }

    constructor() ERC20("Wrapped StkGho", "WStkGho") {
        nameHash = keccak256(bytes("Wrapped StkGHO"));
        versionHash = keccak256(bytes("1"));
        DOMAIN_SEPARATOR = EIP712Lib.calculateDomainSeparator(
            nameHash,
            versionHash
        );
    }

    function supportsInterface(
        bytes4 interfaceId
    ) external pure override returns (bool) {
        return
            interfaceId == type(IERC7540Redeem).interfaceId ||
            interfaceId == type(IERC7540Operator).interfaceId ||
            interfaceId == type(IERC7575).interfaceId ||
            interfaceId == type(IERC20).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }

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
        uint256 shares = IERC20(STK_GHO).balanceOf(address(this));

        return IStakeToken(STK_GHO).previewRedeem(shares);
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
    ) external returns (uint256 shares) {
        shares = _assetToShare(assets);
        _deposit(assets, shares, receiver);
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
    ) external returns (uint256 assets) {
        assets = _shareToAsset(shares);
        _deposit(assets, shares, receiver);
    }

    /// @inheritdoc IERC7575
    function maxWithdraw(
        address owner
    ) external view virtual returns (uint256 maxAssets) {
        uint256 shares = balanceOf(owner);
        maxAssets = _shareToAsset(shares);
    }

    /// @inheritdoc IERC7575
    function previewWithdraw(uint256) external view returns (uint256) {
        revert();
    }

    /// @inheritdoc IERC7575
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external virtual returns (uint256) {}

    /// @inheritdoc IERC7575
    function maxRedeem(address owner) external view returns (uint256) {
        uint256 shares = balanceOf(owner);
        return shares;
    }

    /// @inheritdoc IERC7575
    function previewRedeem(uint256) external view virtual returns (uint256) {
        revert();
    }

    /// @inheritdoc IERC7575
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) external virtual returns (uint256) {}

    /// @inheritdoc IERC7540Operator
    function setOperator(
        address operator,
        bool approved
    ) public virtual returns (bool success) {
        if (msg.sender == operator) {
            revert InvalidOperator();
        }

        isOperator[msg.sender][operator] = approved;
        emit OperatorSet(msg.sender, operator, approved);
        success = true;
    }

    /// @inheritdoc IAuthorizeOperator
    function authorizeOperator(
        address controller,
        address operator,
        bool approved,
        bytes32 nonce,
        uint256 deadline,
        bytes memory signature
    ) external returns (bool success) {
        if (controller == operator) {
            revert InvalidOperator();
        }
        if (block.timestamp > deadline) {
            revert TimeExpired();
        }
        if (authorizations[controller][nonce]) {
            revert InvalidNonce();
        }

        authorizations[controller][nonce] = true;

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(
                        AUTHORIZE_OPERATOR_TYPEHASH,
                        controller,
                        operator,
                        approved,
                        nonce,
                        deadline
                    )
                )
            )
        );

        if (!SignatureLib.isValidSignature(controller, digest, signature)) {
            revert InvalidSignature();
        }

        isOperator[controller][operator] = approved;
        emit OperatorSet(controller, operator, approved);

        success = true;
    }

    function invalidateNonce(bytes32 nonce) external {
        authorizations[msg.sender][nonce] = true;
    }

    /// @inheritdoc IERC7540Redeem
    function requestRedeem(
        uint256 shares,
        address controller,
        address owner
    ) external withCooldown returns (uint256 requestId) {
        address sender = isOperator[owner][msg.sender] ? owner : msg.sender;
        requestId = DEFAULT_REQUEST_ID;

        uint256 assets = _shareToAsset(shares);

        emit RedeemRequest(controller, owner, requestId, sender, assets);
    }

    /// @inheritdoc IERC7540Redeem
    function pendingRedeemRequest(
        uint256 requestId,
        address controller
    ) external view returns (uint256) {
        (bool redeemable, bool triggerenable) = _checkRedeemable();
        if (redeemable || triggerenable) {
            return 0;
        } else {
            return balanceOf(controller);
        }
    }

    /// @inheritdoc IERC7540Redeem
    function claimableRedeemRequest(
        uint256 requestId,
        address controller
    ) external view returns (uint256) {
        (bool redeemable, ) = _checkRedeemable();
        if (redeemable) {
            return balanceOf(controller);
        }

        return 0;
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

    function _claimRewards(uint256 rewards) internal {
        IStakeToken(STK_GHO).claimRewards(address(this), rewards);
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

    /**
     * @dev Internal function for the calculation of user's rewards on a distribution
     * @param principalUserBalance Amount staked by the user on a distribution
     * @param newIndex Current index of the distribution
     * @param prevIndex Index stored for the user, representation his staking moment
     * @return The rewards
     */
    function _getRewards(
        uint256 principalUserBalance,
        uint256 newIndex,
        uint256 prevIndex
    ) internal pure returns (uint256) {
        return
            (principalUserBalance * (newIndex - prevIndex)) /
            (10 ** uint256(PRECISION));
    }

    function _updateUserIndex(address receiver) internal {
        (, , uint256 newIndex) = IStakeToken(STK_GHO).assets(address(STK_GHO));
        uint256 userBalance = _shareToAsset(balanceOf(receiver));
        if (userIndex[receiver] > 0 && userBalance > 0) {
            uint256 userRewards = _getRewards(
                userBalance,
                newIndex,
                userIndex[receiver]
            );
            userIndex[receiver] = newIndex;
            stackedRewards[receiver] += userRewards;
        }
    }

    function _deposit(
        uint256 assets,
        uint256 shares,
        address receiver
    ) internal withClaim {
        IERC20(GHO).transferFrom(msg.sender, address(this), assets);

        IStakeToken(STK_GHO).stake(address(this), assets);
        _updateUserIndex(receiver);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function _checkRedeemable()
        internal
        view
        returns (bool redeemable, bool triggerenable)
    {
        (uint40 timestamp, ) = IStakeToken(STK_GHO).stakersCooldowns(
            address(this)
        );
        uint256 cooldownSeconds = IStakeToken(STK_GHO).getCooldownSeconds();
        uint256 unstakeWindow = IStakeToken(STK_GHO).UNSTAKE_WINDOW();

        triggerenable =
            timestamp + cooldownSeconds + unstakeWindow < block.timestamp;
        redeemable =
            timestamp + cooldownSeconds + unstakeWindow >= block.timestamp &&
            timestamp + cooldownSeconds <= block.timestamp;
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override {
        _updateUserIndex(from);
        _updateUserIndex(to);
        super._update(from, to, value);
    }
}
