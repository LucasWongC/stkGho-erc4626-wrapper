// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IStakeToken} from "./interfaces/IStakeToken.sol";
import {IUniswapV3StaticQuoter} from "./interfaces/IUniswapV3StaticQuoter.sol";
import {ISwapRouter} from "./interfaces/ISwapRouter.sol";
import {IGsm} from "./interfaces/IGsm.sol";
import {IERC7540Redeem, IERC7575, IERC7540Operator, IERC7575, IERC7540CancelRedeem, IAuthorizeOperator} from "./interfaces/IERC7540.sol";

import {EIP712Lib} from "./libraries/EIP712Lib.sol";
import {SignatureLib} from "./libraries/SignatureLib.sol";

/// @title IStkGhoERC7540Wrapper
/// @notice A wrapper contract for staked GHO tokens implementing ERC7540 and additional interfaces
/// @dev This contract wraps staked GHO tokens and provides additional functionality like rewards claiming and operator authorization
interface IStkGhoERC7540Wrapper is
    IERC7540Redeem,
    IERC7575,
    IAuthorizeOperator
{
    /// @dev Reverts if operator is invalid
    error InvalidOperator();
    /// @dev Reverts if time is expired
    error TimeExpired();
    /// @dev Reverts if nonce is used before
    error InvalidNonce();
    /// @dev Reverts if signature is invalid
    error InvalidSignature();
    /// @dev Redeem functionality disabled
    error RedeemDisabled();

    /// @dev Invalidate nonce
    function invalidateNonce(bytes32 nonce) external;

    /// @notice Get the total rewards for a given owner
    /// @param owner The address of the owner to check rewards for
    /// @return rewards The total amount of rewards available for the owner
    function getRewards(address owner) external view returns (uint256 rewards);

    /// @notice Claim rewards for a given owner
    /// @param owner The address of the owner claiming rewards
    /// @return rewards The amount of rewards claimed
    function claimRewards(address owner) external returns (uint256 rewards);
}
