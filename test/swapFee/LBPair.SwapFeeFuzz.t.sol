// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "test/swapFee/SwapFeeHelper.sol";

contract SwapFee is SwapFeeTestHelper {


    //@note fuzzing to see whether correctPairFees > pairFees holds.
    function testSingleBinSwapFeeDifferenceFuzz(uint112 _token18DAmount) public {

        vm.assume(_token18DAmount > 0);

        _createLiquidity(pair, _token18DAmount);
        _createLiquidity(correctFeePair, _token18DAmount);


        uint112 _token6DAmountIn = _token18DAmount;
        uint256 pairFees = _getFeesFromSwap(pair, _token6DAmountIn);
        uint256 correctPairFees = _getFeesFromSwap(correctFeePair, _token6DAmountIn);

        emit log_named_uint("difference: ", correctPairFees - pairFees);
    }


    //@note fuzzing to see whether correctPairFees > pairFees holds.
    function testMultiBinSwapFeeDifferenceFuzz(uint112 _token18DAmount) public {
        uint16 _numberOfBins = 100;
        vm.assume(_token18DAmount > 1e10);

        _createSpreadLiquidity(pair, _token18DAmount, _numberOfBins);
        _createSpreadLiquidity(correctFeePair, _token18DAmount, _numberOfBins);


        uint112 _token6DAmountIn = _token18DAmount;
        uint256 pairFees = _getFeesFromSwap(pair, _token6DAmountIn);
        uint256 correctPairFees = _getFeesFromSwap(correctFeePair, _token6DAmountIn);

        emit log_named_uint("difference: ", correctPairFees - pairFees);

    }



}
