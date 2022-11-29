// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

import "./Randomness.sol";
import "./RandomnessConsumer.sol";
import "hardhat/console.sol";

contract Lottery is RandomnessConsumer {

   /// @notice The Randomness Precompile Interface
    Randomness public randomness =
        Randomness(0x0000000000000000000000000000000000000809);

    uint256[] public VRFOutputRandomWord;

    error WaitingFulfillment();
    error NotEnoughFee(uint256 value, uint256 required);
    error DepositTooLow(uint256 value, uint256 required);
    uint64 public FULFILLMENT_GAS_LIMIT = 300000; 
    uint64 public SEND_GAS_LIMIT = 300000; 

    uint256 public MIN_FEE = FULFILLMENT_GAS_LIMIT * 1 gwei;
    uint256 public SEND_FEE = SEND_GAS_LIMIT * 1 gwei;
    uint32 public VRF_BLOCKS_DELAY = MIN_VRF_BLOCKS_DELAY;
    bytes32 public SALT_PREFIX = "my_demo_salt_change_me";
    uint256 public globalRequestCount;
    uint256 public requestId;
    uint32 public REQUIRED_PEOPLE = 1;

    address owner;

    address[] public buyerAddress;
    mapping(address => uint) public buyerBalances;
    uint public winnerCount = 1;

    function checkBuyerExits(address buyer) internal view returns(bool){
        uint arrayLength = buyerAddress.length;
        for (uint i=0; i<arrayLength; i++) {
            if (buyerAddress[i]==buyer) return true;
        }
        return false;
    }

    function buyLottery() external payable {
        if (!checkBuyerExits(msg.sender)){
            buyerAddress.push(msg.sender);
        }
        buyerBalances[msg.sender] += msg.value;
    }

    Randomness.RandomnessSource randomnessSource;

    constructor(Randomness.RandomnessSource source)
        RandomnessConsumer()
    {
        randomnessSource = source;
        owner = msg.sender;
        globalRequestCount = 0;
        /// Set the requestId to the maximum allowed value by the precompile (64 bits)
        requestId = 2**64 - 1;
    }

    function requestRandomWords(uint cnt) external payable enoughPeople {
        /// We check we haven't started the randomness request yet
        if (
            randomness.getRequestStatus(requestId) !=
            Randomness.RequestStatus.DoesNotExist
        ) {
            revert WaitingFulfillment();
        }

        uint256 fee = msg.value - randomness.requiredDeposit();

        if (msg.value < randomness.requiredDeposit() + MIN_FEE) {
            revert NotEnoughFee(msg.value, randomness.requiredDeposit() + MIN_FEE);
        }

        requestId = randomness.requestLocalVRFRandomWords(
                msg.sender,
                fee,
                FULFILLMENT_GAS_LIMIT,
                SALT_PREFIX ^ bytes32(globalRequestCount++),
                1,
                VRF_BLOCKS_DELAY
        );
        winnerCount = cnt;
    }

    function increaseRequestFee() external payable {
        randomness.increaseRequestFee(requestId, msg.value);
    }

    function adjustRequiredPeople(uint32 people) external notStart onlyOwner {
        REQUIRED_PEOPLE = people;
    }

    function fulfillRequest() public {
        randomness.fulfillRequest(requestId);
    }

    address[] public winners;

    function fulfillRandomWords(
        uint256, /* requestId */
        uint256[] memory randomWords
    ) internal override {
       delete winners;
       uint arrayLength = buyerAddress.length;
       uint totalShare = 0;
       for (uint i=0; i<winnerCount; i++) {
           uint winnerIndex = randomWords[i] % arrayLength;
           console.log("winner index is %s", winnerIndex);
           address winner = buyerAddress[winnerIndex];
           console.log("winner address is %s", winner);
           winners.push(winner);
           totalShare += buyerBalances[winner];
        } 
        console.log("totalShare address is %s", totalShare);
        uint balance = address(this).balance;
        for (uint i =0; i < winners.length; i++) {
            withdrawMoney(winners[i], balance / totalShare * buyerBalances[winners[i]]);
        }
    }

   function withdrawMoney(address _to, uint _value) internal {
        payable(_to).transfer(_value - SEND_FEE);
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier enoughPeople() {
        require(buyerAddress.length >= REQUIRED_PEOPLE);
        _;
    }

    modifier notStart() {
        require(buyerAddress.length == 0);
        _;
    }
}
