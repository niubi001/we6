// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "hardhat/console.sol";
import "./ExampleExternalContract.sol";

contract Staker {
    ExampleExternalContract public exampleExternalContract;

    mapping(address => uint256) public balances;
    mapping(address => uint256) public depositBlocks;

    uint256 public constant MAX_POWER_BLOCK = 5;
    //before divided by 100
    uint256 public constant MAX_REWARD_RATE = 2**(MAX_POWER_BLOCK - 1);
    uint256 public constant ACC_BEFORE_MAX = 2**MAX_POWER_BLOCK - 1;

    uint256 public constant timePerBlock = 15 seconds;
    uint256 public currentBlock = block.number;
    uint256 withdrawalBlocks = currentBlock + 120 seconds / timePerBlock;
    uint256 claimBlocks = currentBlock + 240 seconds / timePerBlock;

    // Events
    event Stake(address indexed sender, uint256 amount);
    event Received(address, uint256);
    event Execute(address indexed sender, uint256 amount);

    // Modifiers
    /*
  Checks if the withdrawal period has been reached or not
  */
    modifier withdrawalDeadlineReached(bool requireReached) {
        uint256 timeRemaining = withdrawalTimeLeft();
        if (requireReached) {
            require(timeRemaining == 0, "Withdrawal period is not reached yet");
        } else {
            require(timeRemaining > 0, "Withdrawal period has been reached");
        }
        _;
    }

    /*
  Checks if the claim period has ended or not
  */
    modifier claimDeadlineReached(bool requireReached) {
        uint256 timeRemaining = claimPeriodLeft();
        if (requireReached) {
            require(timeRemaining == 0, "Claim deadline is not reached yet");
        } else {
            require(timeRemaining > 0, "Claim deadline has been reached");
        }
        _;
    }

    /*
  Requires that the contract only be completed once!
  */
    modifier notCompleted() {
        bool completed = exampleExternalContract.completed();
        require(!completed, "Stake already completed!");
        _;
    }

    constructor(address exampleExternalContractAddress) {
        exampleExternalContract = ExampleExternalContract(
            exampleExternalContractAddress
        );
    }

    // Stake function for a user to stake ETH in our contract
    function stake()
        public
        payable
        withdrawalDeadlineReached(false)
        claimDeadlineReached(false)
    {
        balances[msg.sender] = balances[msg.sender] + msg.value;
        depositBlocks[msg.sender] = block.number;
        emit Stake(msg.sender, msg.value);
    }

    /*
  Withdraw function for a user to remove their staked ETH inclusive
  of both principal and any accrued interest
  */
    function withdraw()
        public
        withdrawalDeadlineReached(true)
        claimDeadlineReached(false)
        notCompleted
    {
        require(balances[msg.sender] > 0, "You have no balance to withdraw!");
        uint256 individualBalance = balances[msg.sender];
        uint256 indBalanceRewards;
        if (block.number > depositBlocks[msg.sender] + MAX_POWER_BLOCK) {
            indBalanceRewards =
                individualBalance +
                (individualBalance / 100) *
                (((block.number -
                    (depositBlocks[msg.sender] + MAX_POWER_BLOCK)) *
                    MAX_REWARD_RATE) + ACC_BEFORE_MAX);
        } else {
            indBalanceRewards =
                individualBalance +
                (individualBalance / 100) *
                (2**(block.number - depositBlocks[msg.sender]) - 1);
        }
        balances[msg.sender] = 0;

        // Transfer all ETH via call! (not transfer) cc: https://solidity-by-example.org/sending-ether
        (bool sent, ) = msg.sender.call{value: indBalanceRewards}("");
        require(sent, "RIP; withdrawal failed :( ");
    }

    /*
  Allows any user to repatriate "unproductive" funds that are left in the staking contract
  past the defined withdrawal period
  */
    function execute() public claimDeadlineReached(true) notCompleted {
        uint256 contractBalance = address(this).balance;
        exampleExternalContract.complete{value: contractBalance}();
    }

    function retrieve() public {
        exampleExternalContract.withdraw();
    }

    /*
  READ-ONLY function to calculate the time remaining before the minimum staking period has passed
  */
    function withdrawalTimeLeft() public view returns (uint256) {
        if (block.number < withdrawalBlocks) {
            return (withdrawalBlocks - block.number) * timePerBlock;
        } else {
            return (0);
        }
    }

    /*
  READ-ONLY function to calculate the time remaining before the minimum staking period has passed
  */
    function claimPeriodLeft() public view returns (uint256) {
        if (block.number < claimBlocks) {
            return (claimBlocks - block.number) * timePerBlock;
        } else {
            return (0);
        }
    }

    /*
  Time to "kill-time" on our local testnet
  */
    function killTime() public {
        currentBlock = block.number;
    }

    /*
  \Function for our smart contract to receive ETH
  cc: https://docs.soliditylang.org/en/latest/contracts.html#receive-ether-function
  */
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
}
