// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;


contract LPContract {

    function getReserves() public pure returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = 123;
        _reserve1 = 489;
        _blockTimestampLast = 0;
    }
    
}