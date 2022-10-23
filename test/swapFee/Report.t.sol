// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "test/swapFee/SwapFeeHelper.sol";

contract Report is SwapFeeTestHelper {



    function _calculateFee(LBPair _pair, uint256 _amountIn) internal view returns(uint256 correctPairFees) {
        FeeHelper.FeeParameters memory _fp = _pair.feeParameters();
        (uint256 baseFee, uint256 variableFee) = (FeeHelper.getBaseFee(_fp), FeeHelper.getVariableFee(_fp));
        uint256 totalFee = baseFee + variableFee;
        uint256 correctPairFees = (_amountIn * totalFee) / Constants.PRECISION;
        return correctPairFees;
    }

    function _calculateDeficitPercentage(uint _smallFee, uint _bigFee, uint _precision) internal pure returns(uint deficitPercentage) {
        return((_bigFee -  _smallFee) * _precision) / _bigFee;
    }





    function testSingleBinSwapFeeDifference() public {

        //minting liq
        uint112 _token18DAmount = 1e12;
        _createLiquidity(pair, _token18DAmount);
        uint112 _token6DAmountIn = 1e10;
        
        /// @note verify _calculateFee above
        uint256 correctPairFees = _calculateFee(pair, _token6DAmountIn);

        //record fees from actual swap. (uses )
        uint256 pairFees = _getFeesFromSwap(pair, _token6DAmountIn);

        emit log_named_uint("fee deficit: ", correctPairFees - pairFees);
        emit log_named_uint("deficit percentage x 10^5 ", _calculateDeficitPercentage(pairFees, correctPairFees, 1e5));
    }


    /// @dev we can no longer use _calculateFee for multi-bin swaps, since the variable fee updates mid-swap.
    /// @dev Instead, we compare the original LBPair's fees to an LBPair with identical params that uses SwapHelper.getAmountsV2.
    function testMultiBinSwapFeeDifference() public {

        uint112 _token18DAmount = 1e12;
        uint16 _numberOfBins = 100;

        _createSpreadLiquidity(pair, _token18DAmount, _numberOfBins);
        _createSpreadLiquidity(correctFeePair, _token18DAmount, _numberOfBins);


        uint112 _token6DAmountIn = _token18DAmount;
        uint256 pairFees = _getFeesFromSwap(pair, _token6DAmountIn);
        uint256 correctPairFees = _getFeesFromSwap(correctFeePair, _token6DAmountIn);

        emit log_named_uint("fee deficit: ", correctPairFees - pairFees);

        emit log_named_uint("deficit percentage x 10^5 ", _calculateDeficitPercentage(pairFees, correctPairFees, 1e5));

    }


    function testMultiBinGrowth() public {
        uint16 binMax = 100;
        (uint256[] memory deficits, uint256[] memory deficitPercentages) = _recordMultiBinDeficits(binMax);


        emit log_string("MultiBin deficits: ");
        _arrayLog(deficits);

        emit log_string("MultiBin deficitPercentages: ");
        _arrayLog(deficitPercentages);
    }


    function _recordMultiBinDeficits(uint16 _maxNumberOfBins) internal returns(uint256[] memory, uint256[] memory){
        
        uint256[] memory deficits = new uint256[](_maxNumberOfBins);
        uint256[] memory deficitPercentages = new uint256[](_maxNumberOfBins);

        for(uint16 i = 1; i < _maxNumberOfBins; i++ ) {
            super.setUp();
            uint112 _token18DAmount = 1e12;
            uint16 _numberOfBins = i;

            _createSpreadLiquidity(pair, _token18DAmount, _numberOfBins);
            _createSpreadLiquidity(correctFeePair, _token18DAmount, _numberOfBins);


            uint112 _token6DAmountIn = _token18DAmount;
            uint256 pairFees = _getFeesFromSwap(pair, _token6DAmountIn);
            uint256 correctPairFees = _getFeesFromSwap(correctFeePair, _token6DAmountIn);

            deficits[i - 1] = (correctPairFees - pairFees);
            deficitPercentages[i - 1] = (_calculateDeficitPercentage(pairFees, correctPairFees, 1e5));

        }

        return (deficits, deficitPercentages);

    }

}
