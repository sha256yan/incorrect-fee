# LBPair fee calculation error
- LBPair contracts do not collect the correct number of fees on swaps.
- Fees are usually short by about 0.1% for single bin swaps.
- For multi-bin swaps, the lost fees compound and the difference grows larger with each bin that is crossed. (due to the variable fee increasing)
- These issues arise from SwapHelper.getAmounts, and the contracts and libraries that rely on it


I have identified 3 main root causes which I will present with accompanying evidence and solutions. 
- [Incorrect use of getFeeAmountFrom](#incorrect-use-of-getfeeamountfrom)
- [Incorrect conditional for amountIn overflow](#incorrect-conditional-for-amountin-overflow)
- [Need for an additional FeeHelper function](#need-for-an-additional-feehelper-function)


--- 



### Affected existing contracts and libraries

- LBPair.sol
  - [swap](https://github.com/sha256yan/incorrect-fee/blob/dc355df9ee61a41185dedd7017063fc508584f24/src/LBPair.sol#L304-L330)

- LBRouter.sol
  - [getSwapIn](https://github.com/sha256yan/incorrect-fee/blob/899b2318b7d368dbb938a0f1b56748eb0ac3442a/src/LBRouter.sol#L124-L125)
  - [getSwapOut](https://github.com/sha256yan/incorrect-fee/blob/899b2318b7d368dbb938a0f1b56748eb0ac3442a/src/LBRouter.sol#L168-L169)

- SwapHelper.sol
  - [getAmounts](https://github.com/code-423n4/2022-10-traderjoe/blob/79f25d48b907f9d0379dd803fc2abc9c5f57db93/src/libraries/SwapHelper.sol#L59-L65)


---

### New or modifed contracts and libraries

- FeeHelper.sol
  - [getAmountInWithFees](https://github.com/sha256yan/incorrect-fee/blob/899b2318b7d368dbb938a0f1b56748eb0ac3442a/src/libraries/FeeHelper.sol#L164-L173) ( *** New *** )


- SwapHelper.sol
  - [getAmountsV2](https://github.com/sha256yan/incorrect-fee/blob/716cddf2583da86674376cb5346bf46b701b242c/test/mocks/correctFee/SwapHelperV2.sol#L68-L76) ( *** New *** )

- LBRouterV2.sol
  - [getSwapIn](https://github.com/sha256yan/incorrect-fee/blob/716cddf2583da86674376cb5346bf46b701b242c/test/mocks/correctFee/LBRouterV2.sol#L124-L125) ( *** Modified *** )

---

### Details
- As mentioned earlier, most issues arise from SwapHelper.getAmounts . The SwapHelper library is often used for the Bin type. ([Example in LBPair](https://github.com/sha256yan/incorrect-fee/blob/dc355df9ee61a41185dedd7017063fc508584f24/src/LBPair.sol#L36))
- LBPair.swap uses _bin.getAmounts(...) on the active bin to calculate fees. ([See here](https://github.com/sha256yan/incorrect-fee/blob/dc355df9ee61a41185dedd7017063fc508584f24/src/LBPair.sol#L329-L330))
- Inside of SwapHelper.getAmounts, for a given swap, if a bin has enough liqudity, the fee is calculated using ([FeeHelper.getFeeAmountFrom](https://github.com/code-423n4/2022-10-traderjoe/blob/79f25d48b907f9d0379dd803fc2abc9c5f57db93/src/libraries/SwapHelper.sol#L65)). This results in smaller than expected fees.

- LBRouter.getSwapOut relies on SwapHelper.getAmounts to simulate swaps. Its simulations adjust to the correct fee upon using SwapHelper.getAmountsV2 ([LBRouter.getSwapOut](https://github.com/sha256yan/incorrect-fee/blob/899b2318b7d368dbb938a0f1b56748eb0ac3442a/src/LBRouter.sol#L124-L125), [SwapHelper.getAmounts](), [SwapHelper.getAmountsV2]())
- LBRouter.getSwapIn has a fee calculation error which is independent of SwapHelper.getAmounts. [See here](https://github.com/sha256yan/incorrect-fee/blob/899b2318b7d368dbb938a0f1b56748eb0ac3442a/src/LBRouter.sol#L168-L169)
- 


---


# Incorrect use of getFeeAmountFrom
- When there is enough liquidity in a bin for a swap, we should use FeeHelper.getFeeAmount(amountIn) instead of FeeHelper.getFeeAmountFrom(amountIn).

### Evidence
- amountIn, the parameter passed to calculate fees, is the amount of tokens in the LBPair contract in excess of the reserves and fees of the pair for that token. [Inside LBPair.sol](https://github.com/sha256yan/incorrect-fee/blob/1396f6c07ae91bfe5833fd629357983432a97f8b/src/LBPair.sol#L312-L314) --- [Inside TokenHelper](https://github.com/sha256yan/incorrect-fee/blob/1396f6c07ae91bfe5833fd629357983432a97f8b/src/libraries/TokenHelper.sol#L59-L69)


Will now use example numbers:
- Let amountIn = 1e10 (meaning the user has transferred/minted 1e10 tokens to the LBPair)
- Let PRECISION = 1e18
- Let totalFee =  0.00125 x precision (fee of 0.0125%)
- Let price = 1 (parity)
- If the current bin has enough liqudity, feeAmount must be: (amountIn * totalFee ) / (PRECISION) = 12500000 
- [FeeHelper.getFeeAmountFrom(amountIn)](https://github.com/sha256yan/incorrect-fee/blob/1396f6c07ae91bfe5833fd629357983432a97f8b/src/libraries/FeeHelper.sol#L124-L126) uses the formula: feeAmount = (amountIn * totalFee) / (PRECISION + totalFee) = 12484394
- [FeeHelper.getFeeAmount(amountIn)](https://github.com/sha256yan/incorrect-fee/blob/1396f6c07ae91bfe5833fd629357983432a97f8b/src/libraries/FeeHelper.sol#L116-L118) uses exactly the formula ourlined in the correct feeAmount calculation.


---


# Incorrect conditional for amountIn overflow
- The current conditional in SwapHelper.getAmounts tasked with determining when 

### Evidence
#### Snippet 1

```
        fees = fp.getFeeAmountDistribution(fp.getFeeAmount(_maxAmountInToBin));

        if (_maxAmountInToBin + fees.total <= amountIn) {
            amountInToBin = _maxAmountInToBin;
            amountOutOfBin = _reserve;
        }
```
- Here, we are saying if ```_maxAmountInToBin+ ( the fee you would pay if your amountIn was _maxAmountInToBin ) <= amountIn```, then the ```amountInToBin``` must be ```_maxAmountInToBin```.
- The fee being 

Consider
#### Snippet 2
```
        fees = fp.getFeeAmountDistribution(fp.getFeeAmount(amountIn));

        if (_maxAmountInToBin <  amountIn - fees.total) {
            (, uint256 _fee) = fp.getAmountInWithFees(_maxAmountInToBin);
            fees = fp.getFeeAmountDistribution(_fee);
            amountInToBin = _maxAmountInToBin;
            amountOutOfBin = _reserve;
        }
```
- Now, the fees are collected on ```amountIn```.



---




# Need for an additional FeeHelper function
- There are currently functions to answer the following question: How much tokens must a user send, to end up with a given amountInToBin after fees, before the swap itself takes place?

### Evidence
- LBRouter.getSwapIn(, amountOut, ) needs this question answered. At a given price, how many tokens must a user send, to receive amountOut?
  - We use the amountOut and price to work backwards to the amountInToBin.
  - Current approach calculates fees on amountInToBin. ([See here](https://github.com/sha256yan/incorrect-fee/blob/899b2318b7d368dbb938a0f1b56748eb0ac3442a/src/LBRouter.sol#L124-L125))
  - This is incorrect as fees should be calculated on amountIn. (As we discussed in [Incorrect use of getFeeAmountFrom](#incorrect-use-of-getfeeamountfrom))


- SwapHelper.getAmounts needs to be 


---


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
