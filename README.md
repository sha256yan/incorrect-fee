# LBPair fee calculation error background
- LBPair contracts do not collect the correct number of fees on swaps.
- Fees are usually short by about 0.1% for single bin swaps.
- For multi-bin swaps, the lost fees compound and the difference grows larger with each bin that is crossed. (due to the variable fee increasing)



## Detailed background
- LBPair.swap uses _bin.getAmounts(...) on the active bin to calculate fees. [See here](https://github.com/sha256yan/incorrect-fee/blob/dc355df9ee61a41185dedd7017063fc508584f24/src/LBPair.sol#L329-L330)
- _bin is an instance of the custom type Bin, which uses the SwapHelper library. [See here](https://github.com/sha256yan/incorrect-fee/blob/dc355df9ee61a41185dedd7017063fc508584f24/src/LBPair.sol#L36)
- For a given swap, if a bin has enough liqudity, the fee is calculated using [FeeHelper.getFeeAmountFrom(amountIn)](https://github.com/code-423n4/2022-10-traderjoe/blob/79f25d48b907f9d0379dd803fc2abc9c5f57db93/src/libraries/SwapHelper.sol#L65)





## Claim 1
- When there is enough liquidity in a bin for a swap, we should use FeeHelper.getFeeAmount(amountIn) instead of FeeHelper.getFeeAmountFrom(amountIn).

# Proof
- amountIn, the parameter passed to calculate fees, is the amount of tokens in the LBPair contract in excess of the reserves and fees of the pair for that token. [Inside LBPair.sol](https://github.com/sha256yan/incorrect-fee/blob/1396f6c07ae91bfe5833fd629357983432a97f8b/src/LBPair.sol#L312-L314)[Inside TokenHelper](https://github.com/sha256yan/incorrect-fee/blob/1396f6c07ae91bfe5833fd629357983432a97f8b/src/libraries/TokenHelper.sol#L59-L69)


Will now use example numbers:
- Let amountIn = 1e10
- Let PRECISION = 1e18
- Let totalFee =  0.00125 x precision
- Let price = 1 (parity)
- If the current bin has enough liqudity, feeAmount must be: (amountIn * totalFee ) / (PRECISION) = 12500000 
- [FeeHelper.getFeeAmountFrom(amountIn)](https://github.com/sha256yan/incorrect-fee/blob/1396f6c07ae91bfe5833fd629357983432a97f8b/src/libraries/FeeHelper.sol#L124-L126) users the formula: feeAmount = (amountIn * totalFee) / (PRECISION + totalFee) = 12484394
- [FeeHelper.getFeeAmount(amountIn)](https://github.com/sha256yan/incorrect-fee/blob/1396f6c07ae91bfe5833fd629357983432a97f8b/src/libraries/FeeHelper.sol#L116-L118) uses exactly the formula ourlined in the correct feeAmount calculation.









## Install dependencies

To install dependencies, run the following to install dependencies:

```
forge install
```

___

## Tests

To run tests, run the following command:

```
forge test
```