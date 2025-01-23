# StkGhoERC7540Wrapper Smart Contract

The `StkGhoERC7540Wrapper` is a Solidity smart contract that acts as a wrapper for staked GHO tokens, providing additional functionality such as rewards claiming, operator authorization, and ERC7540 compliance.

This contract enables users to interact with staked GHO tokens seamlessly while adhering to the ERC7540 standard and implementing useful interfaces like `IERC7575` and `IERC7540Redeem`.

---

## Features

- **Token Wrapping**: Wraps staked GHO (`StkGHO`) tokens into a new ERC20 token (`WStkGHO`).
- **Rewards Management**: Tracks and enables users to claim rewards accumulated via staked tokens.
- **Operator Authorization**: Supports operator functionality, allowing users to delegate control to authorized operators.
- **ERC7540 Compliance**: Implements multiple interfaces (`IERC7540Redeem`, `IERC7575`, `IERC7540Operator`) to support advanced token standards.
- **Cool-down and Redemption**: Facilitates staked token redemption with cooldown checks.
- **Secure Authorization**: Uses EIP-712 and signature verification to securely authorize operators.

---

## Contract Details

| **Parameter**        | **Description**        |
| -------------------- | ---------------------- |
| **Contract Name**    | `StkGhoERC7540Wrapper` |
| **Token Name**       | Wrapped StkGho         |
| **Token Symbol**     | WStkGho                |
| **Underlying Token** | Staked GHO (`StkGHO`)  |
| **Reward Token**     | AAVE                   |
| **Precision**        | 18                     |

### Addresses

- **Staked GHO (`STK_GHO`)**: `0x1a88Df1cFe15Af22B3c4c783D4e6F7F9e0C1885d`
- **GHO**: `0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f`
- **AAVE**: `0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9`

---

## Key Functionalities

### Token Operations

- **Wrap Tokens**: Deposit staked GHO tokens to receive WStkGHO tokens.
- **Redeem Tokens**: Redeem WStkGHO tokens for the underlying staked GHO.
- **Asset Conversion**:
  - Convert assets to shares and vice versa.
  - Preview deposit, mint, withdraw, and redeem operations.

### Rewards Management

- **Claim Rewards**: Users can claim rewards (denominated in AAVE) accrued from staking.
- **Harvest Rewards**: Accumulate rewards internally.

### Operator Authorization

- **Set Operator**: Authorize or deauthorize an operator.
- **Authorize Operator**: Securely authorize operators using off-chain signatures.

### ERC7540 Compliance

- **Redeem Requests**: Request and manage token redemptions.
- **Pending Requests**: View pending redeem requests.
- **Claimable Requests**: Check claimable redeem requests.

---

## Installation

1. **Clone the Repository**

   ```bash
   git clone <repository-url>
   cd <repository-directory>
   ```

2. **Install Dependencies**  
   Install the required OpenZeppelin contracts:

   ```bash
   npm install @openzeppelin/contracts
   ```

3. **Compile the Contract**

   ```bash
   npx hardhat compile
   ```

4. **Deploy the Contract**  
   Update deployment scripts as necessary and run:
   ```bash
   npx hardhat run scripts/deploy.js
   ```

---

## Usage

### Wrap Tokens

To wrap `StkGHO` into `WStkGHO`:

```solidity
contract.deposit(assets, receiver);
```

### Redeem Tokens

To redeem `WStkGHO` for `StkGHO`:

```solidity
contract.redeem(shares, receiver, owner);
```

### Claim Rewards

To claim accrued AAVE rewards:

```solidity
contract.claimRewards(owner);
```

### Authorize Operators

To authorize an operator off-chain and submit the signature:

```solidity
contract.authorizeOperator(controller, operator, approved, nonce, deadline, signature);
```

---
