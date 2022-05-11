# solidity-essentials
Solidity programming

#### Example-1

updateBalance & getBalance

```solidity
// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract MyLedger {
    mapping(address => uint) public balances;
    function updateBalance(uint newBal) public {
        balances[msg.sender] = newBal;
    }
    function getBalance() public view returns(uint) {
        return balances[msg.sender];
    }
}
```
#### Example-2

Inherited from Square
```solidity
// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/utils/Strings.sol";

contract Shape {
    uint height;
    uint width;

    constructor(uint _height, uint _width) {
        height = _height;
        width = _width;
    }
}

contract Square is Shape {
    constructor(uint h, uint w) Shape(h, w) {}

    function getHeight() public view returns(uint) {
        return height;
    }

    function getArea() public view returns(uint) {
        return height * width;
    }
}
```
> When using Remix, assigning height and width is needed before deployment.


#### Example-3
Owner & Purchase
```solidity
// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/utils/Strings.sol";

contract Owner {
    address owner;
    constructor() {owner = msg.sender;}

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }
}

contract Purchase is Owner {
    mapping(address => bool) purchasers;
    uint price;
    constructor(uint _price) {
        price = _price;
    }

    function purchase() public payable {
        purchasers[msg.sender] = true;
    }

    function setPrice(uint _price) public onlyOwner {
        price = _price;
    }
    function getPrice() public view returns(uint) {
        return price;
    }
}
```
#### Example-4
Simple Storage for unsigned integer and string data type

```solidity
// SPDX-License-Identifier:GPL-3.0

pragma solidity >=0.4.16 < 0.9.0;

contract SimpleStorage {
    uint storedData;

    function setData(uint x) public {
        storedData = x;
    }
    function getData() public view returns (uint) {
        return storedData;
    }
}


contract StringStorage {
    string storedString;

    function setString(string memory x) public {
        storedString = x;
    }
    function getString() public view returns (string memory) {
        return storedString;
    }
}
```

#### Example-5

Struct example

```solidity
 // SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0; 

contract Storage1{
    
    struct People {
        string name;
        uint256 favoriteNumber;

    }

    People[] public people;
    mapping(string => uint256) public nameToFavoriteNumber;

    function appPerson(string memory _name, uint256 _favoriteNumber) public {
        people.push(People(_name, _favoriteNumber));
        nameToFavoriteNumber[_name] = _favoriteNumber;
    }

}
```

#### Example-6
Smart Funding...
```solidity
// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.7;

contract CryptoKids {
    // owner DAD
    address owner;

    event LogKidFundingReceived(address addr, uint amount, uint contractBalance);

    constructor() {
        owner = msg.sender;
    }
    // define Kid
    struct Kid {
        address payable walletAddress;
        string firstName;
        string lastName;
        uint releaseTime;
        uint amount;
        bool canWithdraw;
    }

    // add kid to contract
    Kid[] public kids;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can add kids");
        _;
    }

    function addKid(address payable walletAddress, string memory firstName, string memory lastName, uint releaseTime, uint amount, bool canWithdraw) public onlyOwner {
        kids.push(Kid(
            walletAddress, 
            firstName,
            lastName,
            releaseTime,
            amount,
            canWithdraw
        ));
    }

    function balanceOf() public view returns(uint) {
        return address(this).balance;
    }

    // deposit funds to contract, especially to a kid's account
    function deposit(address walletAddress) payable public {
        addToKidsBalance(walletAddress);
    }
    function addToKidsBalance(address walletAddress) private {
        for(uint i = 0; i < kids.length; i++) {
            if(kids[i].walletAddress == walletAddress) {
                kids[i].amount += msg.value;
                emit LogKidFundingReceived(walletAddress, msg.value, balanceOf());
            }
        }
    }

    function getIndex(address walletAddress) view private returns(uint) {
        for(uint i = 0; i < kids.length; i++) {
            if (kids[i].walletAddress == walletAddress) {
                return i;
            }
        }
        return 999;
    }
    // kid checks if able to withdraw
    function availableToWithdraw(address walletAddress) public returns(bool) {
        uint i = getIndex(walletAddress);
        if (block.timestamp > kids[i].releaseTime) {
            kids[i].canWithdraw = true;
            return true;
        }
        return false;
    }

    // withdraw the money
    function withdraw(address walletAddress) payable public {
        uint i = getIndex(walletAddress);
        require(msg.sender == kids[i].walletAddress, "You must be the very kid to withdraw ETH");
        require(kids[i].canWithdraw == true, "You are not be able to withdraw at this time");
        kids[i].walletAddress.transfer(kids[i].amount);
    }
}
```
