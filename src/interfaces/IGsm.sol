// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IGsm
 * @author Aave
 * @notice Defines the behaviour of a GHO Stability Module
 */
interface IGsm {
    /**
     * @notice Sells the GSM underlying asset in exchange for buying GHO
     * @dev Use `getAssetAmountForSellAsset` function to calculate the amount based on the GHO amount to buy
     * @param maxAmount The maximum amount of the underlying asset to sell
     * @param receiver Recipient address of the GHO being purchased
     * @return The amount of underlying asset sold
     * @return The amount of GHO bought by the user
     */
    function sellAsset(
        uint256 maxAmount,
        address receiver
    ) external returns (uint256, uint256);

    /**
     * @notice Returns the total amount of GHO, gross amount and fee result of selling assets
     * @param maxAssetAmount The maximum amount of underlying asset to sell
     * @return The exact amount of underlying asset to sell
     * @return The total amount of GHO the user buys (gross amount in GHO minus fee)
     * @return The gross amount of GHO
     * @return The fee amount in GHO, applied to the gross amount of GHO
     */
    function getGhoAmountForSellAsset(
        uint256 maxAssetAmount
    ) external view returns (uint256, uint256, uint256, uint256);

    /**
     * @notice Returns the amount of underlying asset, gross amount of GHO and fee result of selling assets
     * @param minGhoAmount The minimum amount of GHO the user must receive for selling underlying asset
     * @return The amount of underlying asset the user sells
     * @return The exact amount of GHO the user receives in exchange
     * @return The gross amount of GHO corresponding to the given total amount of GHO
     * @return The fee amount in GHO, charged for selling assets
     */
    function getAssetAmountForSellAsset(
        uint256 minGhoAmount
    ) external view returns (uint256, uint256, uint256, uint256);
}
