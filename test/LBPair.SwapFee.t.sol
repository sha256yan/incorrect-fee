// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "./TestHelper.sol";

import "test/mocks/LBPairCorrectFee/LBPair.sol";

contract SwapFee is TestHelper {

    LBPair internal correctFeePair;
    LBFactory internal correctFeeFactory;

    function setUp() public {
        token6D = new ERC20MockDecimals(6);
        token18D = new ERC20MockDecimals(18);

        factory = new LBFactory(DEV, 8e14);

        //note this is the same factory implementation. Could not store 2 pairs with same tokens and binStep in one factory; that's the only reason it exists.
        correctFeeFactory = new LBFactory(DEV, 8e14);

        //factory
        ILBPair _LBPairImplementation = new LBPair(factory);
        factory.setLBPairImplementation(address(_LBPairImplementation));
        setDefaultFactoryPresets(DEFAULT_BIN_STEP);
        addAllAssetsToQuoteWhitelist(factory);


        //correctFeeFactory
        //note a reminder: the only thing different about this pair implementation is that is uses SwapHelperV2 which has a modified getAmountsOut function.
        _LBPairImplementation = new CorrectFeeLBPair(correctFeeFactory);
        correctFeeFactory.setLBPairImplementation(address(_LBPairImplementation));
        _setFactoryPreset(correctFeeFactory, DEFAULT_BIN_STEP);
        addAllAssetsToQuoteWhitelist(correctFeeFactory);

        router = new LBRouter(ILBFactory(DEV), IJoeFactory(DEV), IWAVAX(DEV));


        pair = createLBPairDefaultFees(token6D, token18D);

        correctFeePair = LBPair(address(correctFeeFactory.createLBPair(token6D, token18D, ID_ONE, DEFAULT_BIN_STEP)));
    }


    function testSingleBinSwapFeeDifference() public {
        uint112 _token18DAmount = 1e12;

        _createLiquidity(pair, _token18DAmount);
        _createLiquidity(correctFeePair, _token18DAmount);


        uint112 _token6DAmountIn = _token18DAmount;
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

    //@note fuzzing to see whether correctPairFees - pairFees holds.
    function testSingleBinSwapFeeDifferenceFuzz(uint112 _token18DAmount) public {

        vm.assume(_token18DAmount > 0);

        _createLiquidity(pair, _token18DAmount);
        _createLiquidity(correctFeePair, _token18DAmount);


        uint112 _token6DAmountIn = _token18DAmount;
        uint256 pairFees = _getFeesFromSwap(pair, _token6DAmountIn);
        uint256 correctPairFees = _getFeesFromSwap(correctFeePair, _token6DAmountIn);

        emit log_named_uint("difference: ", correctPairFees - pairFees);
    }


    //@note fuzzing to see whether correctPairFees - pairFees holds.
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



    function _getFeesFromSwap(LBPair _pair, uint112 _token6DAmountIn) internal returns(uint256 xFeesCollectedFromSwap){

        //store fees on X token (token6D) before and after the swap to calculate how much fees were collected from swap.
        (uint256 xFeesBeforeSwap, ) = _getGlobalPairFees(_pair);
        _swapXtoY(_pair, _token6DAmountIn);
        (uint256 xFeesAfterSwap, ) = _getGlobalPairFees(_pair);

        xFeesCollectedFromSwap = xFeesAfterSwap - xFeesBeforeSwap;

        emit log_named_uint("collected: ", xFeesCollectedFromSwap);

        return xFeesCollectedFromSwap;
    }



    /// @notice Mints token18D and adds liquidity to the initial active bin of the pair using it.
    function _createLiquidity(LBPair _pair, uint112 _tokenAmount) internal {

        token18D.mint(address(_pair), _tokenAmount);

        uint256[] memory _ids = new uint256[](1);
        _ids[0] = ID_ONE;

        uint256[] memory _liquidities = new uint256[](1);
        _liquidities[0] = Constants.PRECISION;

        _pair.mint(_ids, new uint256[](1), _liquidities, DEV);
    }


    //@note mints liquidity accross multiple bins.
    function _createSpreadLiquidity(LBPair _pair, uint112 _tokenAmount, uint16 _numberOfBins) internal {

        uint256[] memory _ids = new uint256[](_numberOfBins);
        uint256[] memory _liquidities = new uint256[](_numberOfBins);

        for(uint i; i < _numberOfBins; i++) {
            _ids[i] = ID_ONE - i;
            _liquidities[i] = Constants.PRECISION / _numberOfBins;
        }

        token18D.mint(address(_pair), _tokenAmount);
        _pair.mint(_ids, new uint256[](_numberOfBins), _liquidities, DEV);
    }



    function _swapXtoY(LBPair _pair, uint112 _amountXIn) internal returns(uint256 amountYOut) {

        token6D.mint(address(_pair), _amountXIn);

        if(address(_pair) == address(correctFeePair)) {
            (amountYOut, ) = CorrectFeeLBPair(address(_pair)).swap(true, DEV);
        }
        else {
            (amountYOut, ) = _pair.swap(true, DEV);
        }

        return amountYOut;
    }


    function _setFactoryPreset(LBFactory _factory, uint16 _binStep) internal {
        _factory.setPreset(
            _binStep,
            DEFAULT_BASE_FACTOR,
            DEFAULT_FILTER_PERIOD,
            DEFAULT_DECAY_PERIOD,
            DEFAULT_REDUCTION_FACTOR,
            DEFAULT_VARIABLE_FEE_CONTROL,
            DEFAULT_PROTOCOL_SHARE,
            DEFAULT_MAX_VOLATILITY_ACCUMULATED,
            DEFAULT_SAMPLE_LIFETIME
        );
    }



    /// @notice given a swap amount and a pair's fee params, return total fees. 
    function _getTotalFee(LBPair _pair, uint _amountXIn) internal view returns (uint fee) {

        FeeHelper.FeeParameters memory feeParams = _pair.feeParameters();

        uint fee = FeeHelper.getFeeAmount(feeParams, _amountXIn);

        return fee;
    }


    function _getGlobalPairFees(LBPair _pair) internal view returns (uint256 xFees, uint256 yFees) {
        (xFees, yFees, , ) = _pair.getGlobalFees();
    }



}
