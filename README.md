# StakeTokenERC4626Wrapper

## Overview

The `StakeTokenERC4626Wrapper` contract is an abstract implementation that adheres to the ERC-4626 standard (Tokenized Vaults) while wrapping a staking token that implements the `IStakeToken` interface. This contract facilitates compatibility with ERC-4626 while enabling staking functionality for an underlying asset.

It uses delegate calls to the `STAKE_TOKEN` for ERC-20 interactions and provides functionality for deposits, withdrawals, and conversions between assets and shares.

---

## Key Features

- **ERC-4626 Compatibility**: Implements the ERC-4626 standard for tokenized vaults.
- **ERC-20 Support**: Integrates with ERC-20 functions (e.g., `transfer`, `approve`, `transferFrom`) using delegate calls.
- **Staking Token Wrapper**: Wraps a staking token (`IStakeToken`) to expose staking functionality as an ERC-4626 vault.
- **Efficient Conversions**: Supports conversion between assets and shares based on staking token methods like `previewStake` and `previewRedeem`.

---

## Constructor

### Parameters

- `_stakeToken` (address): The address of the staking token contract.

### Behavior

- The constructor initializes the contract with the provided staking token (`STAKE_TOKEN`) and determines the underlying staked asset (`ASSET`) using the `STAKED_TOKEN()` function of the staking token.

---

## Interfaces and Inheritance

- **IERC20Metadata**: Implements functions such as `name`, `symbol`, and `decimals` for token metadata.
- **IERC20**: Implements standard ERC-20 functions such as `transfer`, `balanceOf`, `approve`, and `transferFrom`.
- **IERC4626**: Implements the ERC-4626 vault standard for deposits, withdrawals, and asset/share conversions.

---

## Functions

### IERC20Metadata

- `name()`: Returns the name of the staking token.
- `symbol()`: Returns the symbol of the staking token.
- `decimals()`: Returns the number of decimals used by the staking token.

### IERC20

- `totalSupply()`: Returns the total supply of the staking token.
- `balanceOf(address account)`: Returns the staking token balance of the specified account.
- `transfer(address to, uint256 value)`: Transfers tokens to the specified address using delegate calls.
- `allowance(address owner, address spender)`: Returns the allowance for a spender to spend an owner’s tokens.
- `approve(address spender, uint256 value)`: Approves the spender to spend a specified value using delegate calls.
- `transferFrom(address from, address to, uint256 value)`: Transfers tokens from one address to another using delegate calls.

### IERC4626

- `asset()`: Returns the address of the underlying staked asset.
- `totalAssets()`: Returns the total amount of underlying assets held by the staking token.
- `convertToShares(uint256 assets)`: Converts an amount of assets to shares using `previewStake`.
- `convertToAssets(uint256 shares)`: Converts an amount of shares to assets using `previewRedeem`.
- `maxDeposit(address receiver)`: Returns the maximum amount of assets that can be deposited (currently unlimited).
- `previewDeposit(uint256 assets)`: Returns the equivalent shares for a given amount of assets to be deposited.
- `deposit(uint256 assets, address receiver)`: Transfers and stakes the specified amount of assets, returning the equivalent shares.
- `maxMint(address receiver)`: Returns the maximum amount of shares that can be minted (currently unlimited).
- `previewMint(uint256 shares)`: Returns the equivalent assets required for a given amount of shares to be minted.
- `mint(uint256 shares, address receiver)`: Stakes the required assets to mint the specified number of shares.
- `maxWithdraw(address owner)`: Abstract function for determining the maximum amount of assets that can be withdrawn by an owner.
- `previewWithdraw(uint256 assets)`: Returns the equivalent shares required to withdraw a given amount of assets.
- `withdraw(uint256 assets, address receiver, address owner)`: Abstract function for withdrawing assets.
- `maxRedeem(address owner)`: Returns the maximum shares that can be redeemed by an owner.
- `previewRedeem(uint256 shares)`: Returns the equivalent assets for a given number of shares to be redeemed.
- `redeem(uint256 shares, address receiver, address owner)`: Abstract function for redeeming shares.

---

## Delegate Calls

ERC-20 operations (`transfer`, `approve`, `transferFrom`) are executed using `delegatecall` to the `STAKE_TOKEN` to leverage its logic. This approach ensures the wrapper adheres to the staking token’s rules and permissions.

---

## Abstract Functions

The following functions are left abstract and must be implemented by derived contracts:

- `maxWithdraw(address owner)`: Determines the maximum assets that can be withdrawn by the owner.
- `withdraw(uint256 assets, address receiver, address owner)`: Implements withdrawal functionality.
- `redeem(uint256 shares, address receiver, address owner)`: Implements share redemption functionality.

---

## Example Usage

To use the `StakeTokenERC4626Wrapper`, create a derived contract and implement the abstract methods (`maxWithdraw`, `withdraw`, `redeem`). Deploy the contract with the address of an existing staking token that adheres to the `IStakeToken` interface.

---

## Dependencies

- OpenZeppelin Contracts (`IERC20`, `IERC20Metadata`, `IERC4626`)
- `IStakeToken`: Custom interface defining the staking token’s functionality.

---

## Notes

1. **Immutable Addresses**: Both `STAKE_TOKEN` and `ASSET` are declared as `immutable` for gas efficiency.
2. **Delegate Calls**: While convenient, the use of `delegatecall` introduces potential security risks. Ensure the staking token is trusted.
3. **Abstract Contract**: This contract cannot be deployed directly; it requires a concrete implementation of the abstract methods.

---

Here is a comprehensive README for your `StkGhoERC4626Wrapper` contract:

---

# StkGhoERC4626Wrapper

The `StkGhoERC4626Wrapper` contract extends the functionality of the `StakeTokenERC4626Wrapper` to integrate with `stkGHO`, `AAVE`, and `USDC` tokens, enabling advanced token interactions such as swapping rewards and managing assets.

## Overview

This contract provides a wrapper for `stkGHO` (staked GHO) tokens with additional features:

1. Converts `stkGHO` rewards (AAVE tokens) into `GHO` via intermediate swaps.
2. Implements the ERC-4626 standard for tokenized vaults, allowing for deposits, withdrawals, and rewards claiming.
3. Integrates Uniswap v3 for swapping rewards and GSM (GHO Stablecoin Manager) for converting USDC to GHO.

## Key Features

- **Reward Management**: Allows users to claim and convert rewards (AAVE) into GHO tokens.
- **Swap Integration**: Uses Uniswap v3's `Quoter` and `SwapRouter` for converting AAVE to USDC.
- **Tokenized Vault**: Implements the ERC-4626 standard for `stkGHO`, enabling tokenized asset management.
- **GHO Conversion**: Converts USDC obtained from swaps into GHO via the GSM.

---

## Contract Details

### Constants

- **`STK_GHO`**: Address of the stkGHO token.
- **`AAVE`**: Address of the AAVE token.
- **`USDC`**: Address of the USDC token.
- **`AAVE_USDC_UNIV3_FEE`**: Uniswap v3 pool fee for AAVE-USDC swaps (3000 = 0.3%).
- **`USDC_GSM`**: Address of the GHO Stablecoin Manager.
- **`QUOTER`**: Address of the Uniswap v3 Quoter for querying swap rates.
- **`SWAP_ROUTER`**: Address of the Uniswap v3 Swap Router for executing swaps.

---

## Functions

### `maxWithdraw(address owner)`

Calculates the maximum amount of assets a user can withdraw. This includes both the redeemable stkGHO and converted rewards (AAVE → USDC → GHO).

- **Returns**: `maxAssets` - Total assets available for withdrawal.

---

### `previewClaim(uint256 assets)`

Estimates the amount of rewards (AAVE) needed to claim a specific amount of assets (GHO).

- **Returns**: `rewards` - Estimated AAVE rewards.

---

### `withdraw(uint256 assets, address receiver, address owner)`

Withdraws a specified amount of assets (GHO) for the user. Handles reward conversion (AAVE → USDC → GHO) and redeems additional stkGHO if necessary.

- **Parameters**:

  - `assets`: Amount of assets (GHO) to withdraw.
  - `receiver`: Address to receive the assets.
  - `owner`: Address of the asset owner.

- **Returns**: `redeemShares` - Number of shares redeemed.

---

### `redeem(uint256 shares, address receiver, address owner)`

Redeems a specified number of shares, converting all rewards and stkGHO into assets (GHO) and transferring them to the receiver.

- **Parameters**:

  - `shares`: Number of shares to redeem.
  - `receiver`: Address to receive the assets.
  - `owner`: Address of the share owner.

- **Returns**: `assets` - Amount of assets (GHO) redeemed.

---

## Workflow

### Deposit Workflow

1. Deposit stkGHO into the wrapper.
2. Receive ERC-4626 compatible shares in return.

### Withdraw Workflow

1. Calculate rewards available for withdrawal.
2. Convert AAVE → USDC → GHO.
3. Redeem additional stkGHO if necessary.
4. Transfer GHO to the receiver.

### Redeem Workflow

1. Claim rewards (AAVE).
2. Swap rewards to USDC via Uniswap v3.
3. Convert USDC to GHO via GSM.
4. Redeem shares and transfer GHO to the receiver.

---

## Dependencies

The contract relies on the following external protocols and interfaces:

- **Uniswap v3**: For AAVE to USDC swaps (`Quoter` and `SwapRouter`).
- **GHO Stablecoin Manager (GSM)**: For USDC to GHO conversion.
- **StakeTokenERC4626Wrapper**: Parent contract implementing the core ERC-4626 functionality.

---

## Error Handling

- **"staticcall failed"**: Indicates a failure in querying the Uniswap v3 Quoter.
- **"Delegatecall failed"**: Indicates a failure in delegating calls to the underlying `STAKE_TOKEN`.
- **Revert on insufficient balances**: Ensures users cannot withdraw or redeem more than their available balance.

---

## Security Considerations

- **Approval Management**: Ensures proper approvals for Uniswap and GSM interactions.
- **Reentrancy**: Uses `delegatecall` carefully; review for potential vulnerabilities.
- **Validation**: Reverts on invalid inputs or insufficient balances.

---

## Deployment

To deploy the contract:

1. Ensure all dependencies are deployed (e.g., Uniswap v3, GSM, stkGHO).
2. Deploy the `StkGhoERC4626Wrapper` contract, passing `STK_GHO` as the constructor parameter.

---

## Future Enhancements

- Add support for other swap routes or fees.
- Enhance gas efficiency for reward conversion.
- Introduce governance controls for contract upgrades or parameter tuning.

---
