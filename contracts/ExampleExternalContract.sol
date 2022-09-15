// SPDX-License-Identifier: MIT
pragma solidity 0.8.4; //Do not change the solidity version as it negativly impacts submission grading

contract ExampleExternalContract {
    address owner;
    bool public completed;

    constructor() {
        owner = msg.sender;
    }

    function complete() public payable {
        completed = true;
    }

    function withdraw() public {
        require(owner == tx.origin || owner == msg.sender, "Stop!");
        require(completed == true, "execute does not completed!");
        (bool sent, ) = msg.sender.call{value: address(this).balance}("");
        require(sent, "RIP; withdrawal failed :( ");
        completed = false;
    }
}
