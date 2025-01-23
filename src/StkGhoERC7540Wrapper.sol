// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IStakeToken} from "./interfaces/IStakeToken.sol";
import {IERC7540Redeem, IERC7575, IERC7540Operator, IERC7540CancelRedeem, IAuthorizeOperator} from "./interfaces/IERC7540.sol";
import {IStkGhoERC7540Wrapper} from "./IStkGhoERC7540Wrapper.sol";

import {EIP712Lib} from "./libraries/EIP712Lib.sol";
import {SignatureLib} from "./libraries/SignatureLib.sol";

/// @title StkGhoERC7540Wrapper
/// @notice A wrapper contract for staked GHO tokens implementing ERC7540 and additional interfaces
/// @dev This contract wraps staked GHO tokens and provides additional functionality like rewards claiming and operator authorization
contract StkGhoERC7540Wrapper is IStkGhoERC7540Wrapper, ERC20 {
    address public constant STK_GHO =
        0x1a88Df1cFe15Af22B3c4c783D4e6F7F9e0C1885d;
    address public constant GHO = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;
    address public constant AAVE = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;

    uint8 public constant PRECISION = 18;

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

    /// @dev claim rewards
    modifier withClaim() {
        _claimRewards();
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

    /// @notice Constructor function
    /// @dev Initializes the contract with the name "Wrapped StkGho" and symbol "WStkGho"
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
    ) external view returns (bool) {
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
    ) external virtual returns (uint256 shares) {
        shares = _assetToShare(assets);
        _redeem(assets, shares, receiver, owner);
    }

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
    ) external virtual returns (uint256) {
        uint256 assets = _shareToAsset(shares);
        _redeem(assets, shares, receiver, owner);
    }

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

    /// @inheritdoc IStkGhoERC7540Wrapper
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
        uint256, // requestId
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
        uint256, // requestId
        address controller
    ) external view returns (uint256) {
        (bool redeemable, ) = _checkRedeemable();
        if (redeemable) {
            return balanceOf(controller);
        }

        return 0;
    }

    /// @inheritdoc IStkGhoERC7540Wrapper
    function getRewards(address owner) external view returns (uint256) {
        uint256 assets = _shareToAsset(balanceOf(owner));
        (, , uint256 newIndex) = IStakeToken(STK_GHO).assets(address(STK_GHO));

        console.log(assets);
        console.log(newIndex);
        console.log(userIndex[owner]);
        console.log(stackedRewards[owner]);
        return
            stackedRewards[owner] +
            _getRewards(assets, newIndex, userIndex[owner]);
    }

    /// @inheritdoc IStkGhoERC7540Wrapper
    function claimRewards(
        address owner
    ) external withClaim returns (uint256 rewards) {
        rewards = stackedRewards[owner];
        stackedRewards[owner] = 0;

        IERC20(AAVE).transfer(owner, rewards);
    }

    /// @inheritdoc IStkGhoERC7540Wrapper
    function harvest() external {
        _claimRewards();
    }

    /// @notice Convert assets to shares
    /// @param assets The amount of assets to convert
    /// @return shares The equivalent amount of shares
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

    /// @notice Convert shares to assets
    /// @param shares The amount of shares to convert
    /// @return assets The equivalent amount of assets
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

    /// @notice Internal function to claim rewards
    function _claimRewards() internal {
        uint256 rewards = IStakeToken(STK_GHO).getTotalRewardsBalance(
            address(this)
        );
        if (rewards > 0) {
            IStakeToken(STK_GHO).claimRewards(address(this), rewards);
        }
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

    /// @notice Updates the user's index for reward calculation
    /// @dev This function is called internally to update the user's reward index and calculate new rewards
    /// @param receiver The address of the user whose index is being updated
    function _updateUserIndex(address receiver) internal {
        (, , uint256 newIndex) = IStakeToken(STK_GHO).assets(address(STK_GHO));
        uint256 userBalance = _shareToAsset(balanceOf(receiver));
        if (userIndex[receiver] > 0 && userBalance > 0) {
            uint256 userRewards = _getRewards(
                userBalance,
                newIndex,
                userIndex[receiver]
            );
            stackedRewards[receiver] += userRewards;
        }

        userIndex[receiver] = newIndex;
    }

    /// @notice Internal function to deposit assets and mint shares
    /// @param assets The amount of assets to deposit
    /// @param shares The amount of shares to mint
    /// @param receiver The address that will receive the minted shares
    function _deposit(
        uint256 assets,
        uint256 shares,
        address receiver
    ) internal {
        IERC20(GHO).transferFrom(msg.sender, address(this), assets);

        IERC20(GHO).approve(STK_GHO, assets);
        IStakeToken(STK_GHO).stake(address(this), assets);
        _updateUserIndex(receiver);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /// @notice Internal function to redeem shares for assets
    /// @param assets The amount of assets to withdraw
    /// @param shares The amount of shares to burn
    /// @param receiver The address that will receive the assets
    function _redeem(
        uint256 assets,
        uint256 shares,
        address receiver,
        address owner
    ) internal {
        (bool redeemable, ) = _checkRedeemable();
        if (!redeemable) {
            revert RedeemDisabled();
        }
        uint256 stkGhoAmount = IStakeToken(STK_GHO).previewStake(assets);
        IStakeToken(STK_GHO).redeem(address(this), stkGhoAmount);

        _burn(owner, shares);

        IERC20(GHO).transfer(receiver, assets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    /// @notice Internal function to check if redeem is possible
    /// @return redeemable True if redeem is currently possible
    /// @return triggerenable True if cooldown can be triggered
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

    /// @notice Internal function to update user balances and indices
    /// @dev This function is called on every transfer to update reward calculations
    /// @param from The address tokens are transferred from
    /// @param to The address tokens are transferred to
    /// @param value The amount of tokens transferred
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
