// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "test/swapFee/SwapFeeHelper.sol";

contract SwapFee is SwapFeeTestHelper {


    function testSingleBinSwapFeeDifference() public {
        uint112 _token18DAmount = 1e12;

        _createLiquidity(pair, _token18DAmount);
        _createLiquidity(correctFeePair, _token18DAmount);


        uint112 _token6DAmountIn = 1e10;
        uint256 pairFees = _getFeesFromSwap(pair, _token6DAmountIn);
        uint256 correctPairFees = _getFeesFromSwap(correctFeePair, _token6DAmountIn);

        emit log_named_uint("difference: ", correctPairFees - pairFees);
    }


    function testMultiBinSwapFeeDifference() public {

        uint112 _token18DAmount = 1e12;
        uint16 _numberOfBins = 100;

        _createSpreadLiquidity(pair, _token18DAmount, _numberOfBins);
        _createSpreadLiquidity(correctFeePair, _token18DAmount, _numberOfBins);


        uint112 _token6DAmountIn = _token18DAmount;
        uint256 pairFees = _getFeesFromSwap(pair, _token6DAmountIn);
        uint256 correctPairFees = _getFeesFromSwap(correctFeePair, _token6DAmountIn);

        emit log_named_uint("difference: ", correctPairFees - pairFees);

    }

}
