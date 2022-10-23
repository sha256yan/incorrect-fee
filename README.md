# LBPair contracts consistently collect less fees than their FeeParameters

---
## Motivation and Severity 
LBpair contracts' fees fall short by 0.1% on single bin with the deficit growing exponentially with multi-bin swaps.


This report will refer to this difference in fees, that is, the difference between the expected fees and the actual collected fees as the "Fee Deficit".


![feeDeficitGrowth](https://user-images.githubusercontent.com/91401566/197405701-e6df80c4-dcdf-44f5-9fd2-74ef1c66b954.png)

The exponential growth of the Fee Deficit percentage is concerning, considering that the vast majority of the fees collected
by LPs and DEXs are during high volatility periods.
Note that the peak Fee Deficit percentage of 1.6% means that 1.6% of expected fees would not be collected.




https://user-images.githubusercontent.com/91401566/197406096-5771893b-82f6-43e8-aa42-ccda449e4936.mov

With an assumed average total fee of 1% (higher than usual due to ```variableFee``` component) and average Fee Deficit percentage of 0.4%;
The total Fee Deficit from a period similar to May 7th 2022 - May 14th 2022, with approximately $1.979B in trading volume, would be ***$79,160*** over one week.




[SwapHelper.getAmounts](https://github.com/code-423n4/2022-10-traderjoe/blob/79f25d48b907f9d0379dd803fc2abc9c5f57db93/src/libraries/SwapHelper.sol#L59-L65) carries most of the blame for this error.


3 main causes have been identified and will be discussed in this report.
- [Incorrect use of getFeeAmountFrom](#incorrect-use-of-getfeeamountfrom)
- [Incorrect conditional for amountIn overflow](#incorrect-conditional-for-amountin-overflow)
- [Need for an additional FeeHelper function](#need-for-an-additional-feehelper-function)


--- 



### Affected contracts and libraries

- LBPair.sol
  - [swap](https://github.com/sha256yan/incorrect-fee/blob/dc355df9ee61a41185dedd7017063fc508584f24/src/LBPair.sol#L304-L330)

- LBRouter.sol
  - [getSwapIn](https://github.com/sha256yan/incorrect-fee/blob/899b2318b7d368dbb938a0f1b56748eb0ac3442a/src/LBRouter.sol#L124-L125)
  - [getSwapOut](https://github.com/sha256yan/incorrect-fee/blob/899b2318b7d368dbb938a0f1b56748eb0ac3442a/src/LBRouter.sol#L168-L169)

- SwapHelper.sol
  - [getAmounts](https://github.com/code-423n4/2022-10-traderjoe/blob/79f25d48b907f9d0379dd803fc2abc9c5f57db93/src/libraries/SwapHelper.sol#L59-L65)


---

### Proposed changes

- FeeHelper.sol
  - [getAmountInWithFees](https://github.com/sha256yan/incorrect-fee/blob/899b2318b7d368dbb938a0f1b56748eb0ac3442a/src/libraries/FeeHelper.sol#L164-L173) ( ***New*** )


- SwapHelper.sol
  - [getAmountsV2](https://github.com/sha256yan/incorrect-fee/blob/348b00988d377d96c9ad64917413524815739884/src/libraries/SwapHelper.sol#L118-L126) ( ***New*** )

- LBRouter.sol
  - [getSwapIn](https://github.com/sha256yan/incorrect-fee/blob/716cddf2583da86674376cb5346bf46b701b242c/test/mocks/correctFee/LBRouterV2.sol#L124-L125) ( ***Modified*** )
  - [getSwapOut](https://github.com/sha256yan/incorrect-fee/blob/c1719b8429c7d25e4e12fc4632842285a2eaaf8b/test/mocks/correctFee/LBRouterV2.sol#L168-L169) ( ***Modified*** )

- LBPair.sol
  - [swap](https://github.com/sha256yan/incorrect-fee/blob/348b00988d377d96c9ad64917413524815739884/test/mocks/correctFee/LBPair.sol#L332-L333)  ( ***Modified*** )

---

### Details
- As mentioned earlier, most issues arise from SwapHelper.getAmounts . The SwapHelper library is often used for the Bin type. ([Example in LBPair](https://github.com/sha256yan/incorrect-fee/blob/dc355df9ee61a41185dedd7017063fc508584f24/src/LBPair.sol#L36))
- LBPair.swap uses _bin.getAmounts(...) on the active bin to calculate fees. ([See here](https://github.com/sha256yan/incorrect-fee/blob/dc355df9ee61a41185dedd7017063fc508584f24/src/LBPair.sol#L329-L330))
- Inside of SwapHelper.getAmounts, for a given swap, if a bin has enough liqudity, the fee is calculated using ([FeeHelper.getFeeAmountFrom](https://github.com/code-423n4/2022-10-traderjoe/blob/79f25d48b907f9d0379dd803fc2abc9c5f57db93/src/libraries/SwapHelper.sol#L65)). This results in smaller than expected fees.

- LBRouter.getSwapOut relies on SwapHelper.getAmounts to simulate swaps. Its simulations adjust to the correct fee upon using SwapHelper.getAmountsV2 ([LBRouter.getSwapOut](https://github.com/sha256yan/incorrect-fee/blob/899b2318b7d368dbb938a0f1b56748eb0ac3442a/src/LBRouter.sol#L124-L125), [SwapHelper.getAmounts](), [SwapHelper.getAmountsV2]())
- LBRouter.getSwapIn has a fee calculation error which is independent of SwapHelper.getAmounts. [See here](https://github.com/sha256yan/incorrect-fee/blob/899b2318b7d368dbb938a0f1b56748eb0ac3442a/src/LBRouter.sol#L168-L169)


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
- [FeeHelper.getFeeAmount(amountIn)](https://github.com/sha256yan/incorrect-fee/blob/1396f6c07ae91bfe5833fd629357983432a97f8b/src/libraries/FeeHelper.sol#L116-L118) uses exactly the formula ourlined in the correct feeAmount calculation and is the correct method in this case.


---


# Incorrect condition for amountIn overflow
- The [condition](https://github.com/sha256yan/incorrect-fee/blob/348b00988d377d96c9ad64917413524815739884/src/libraries/SwapHelper.sol#L61) for when an amountIn overflows the maximum amount available in a bin is flawed.
- The Fee Deficit here could potentially trigger an unnecessary bin de-activation.

### Evidence
#### Snippet 1

```
        fees = fp.getFeeAmountDistribution(fp.getFeeAmount(_maxAmountInToBin));

        if (_maxAmountInToBin + fees.total <= amountIn) {
            //do things
        }
```
- Collecting the fees on ```_maxAmountInToBin``` before doing so on ```amountIn``` means we are not checking  to see whether ```amountIn``` after 

Consider the following:
#### Snippet 2
```
        fees = fp.getFeeAmountDistribution(fp.getFeeAmount(amountIn));

        if (_maxAmountInToBin <  amountIn - fees.total) {
            //do things
        }
```
- Now, the fees are collected on ```amountIn```.
- Assuming both conditions are true, the fees from Snippet2 will be necessarily larger than those in Snippet1 since in both cases ``` _maxAmountInToBin <  amountIn ```.



---




# Need for an additional FeeHelper function
- There are currently functions to answer the following question: How many tokens must a user send, to end up with a given amountInToBin after fees, before the swap itself takes place?

### Evidence
- ```LBRouter.getSwapIn(, amountOut, )``` needs this question answered. At a given price, how many tokens must a user send, to receive ```amountOut```?
  - We use the ```amountOut``` and price to work backwards to the ```amountInToBin```.
  - Current approach calculates fees on ```amountInToBin```. ([See here](https://github.com/sha256yan/incorrect-fee/blob/899b2318b7d368dbb938a0f1b56748eb0ac3442a/src/LBRouter.sol#L124-L125))
  - This is incorrect as fees should be calculated on ```amountIn```. (As we discussed in [Incorrect use of getFeeAmountFrom](#incorrect-use-of-getfeeamountfrom))


- SwapHelper.getAmounts needs to know what hypothetical ```amountIn``` would end up as ```maxAmountInToBin``` after fees. This is needed to be able to avoid [Incorrect amountIn overflow](#incorrect-conditional-for-amountin-overflow)


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
