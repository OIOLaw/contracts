// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.1;

contract trust {

    uint public inTrust;
    uint private lockedUntil;
    address payable owner;

    function receiveMoney(address payable _to) public payable {
        inTrust += msg.value;
        lockedUntil = block.timestamp + 0 minutes;
        owner = _to;
    }

    modifier onlyOwner(){
        require(msg.sender==owner);
        _;
    }
    function getBalance() public view returns(uint) {
        return address(this).balance;
    }
    function IsLocked() public view returns(bool) {
        return (block.timestamp < lockedUntil);
    }

    function withdrawMoney() onlyOwner() public {
        if(msg.sender == owner) {
            if(lockedUntil < block.timestamp) {
                address payable to = payable(msg.sender);
                to.transfer(1e18);
        }
        }
        
    }
    }
