# solidity-essentials. Baby Steps...


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

#### Example-7

```solidity
// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.7;

contract Greeter {

    address creator;
    string greeting;

    constructor(string memory _greeting) {
        creator = msg.sender;
        greeting = _greeting;
    }

    function greet() public view returns (string memory) {
        return greeting;
    }

    function getBlockNumber() public view returns (uint) {
        return block.number;
    }

    function setGreeting(string memory _newgreeting) public {
        greeting = _newgreeting;
    }
    function getCreatorBalance() public view returns (uint) {
        return creator.balance;
    }
}
```

#### Example-8

basic messages

```solidity
// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;
contract basicInfoGetter {

    address creator;

    constructor()
    {
        creator = msg.sender; 								    
    }
	
	function minerAddress() public view returns (address) // get CURRENT block miner's address, 
	{														     // not necessarily the address of the miner when this block was born
		return block.coinbase;
	}
	
	function difficulty() public view returns (uint)
	{
		return block.difficulty;
	}
	
	function gaslimit() public view returns (uint)  // the most gas that can be spent on any given transaction right now
	{													  
		return block.gaslimit;
	}
	
	function blockNumber() public view returns (uint)
	{
		return block.number;
	}
    
    function timestamp() public view returns (uint) // returns current block timestamp in SECONDS (not ms) from epoch
    {													
    	return block.timestamp; 						 // also "now" == "block.timestamp", as in "return now;"
    }
    
    function msgData() public pure returns (bytes memory) 		// The data of a call to this function. Always returns "0xc8e7ca2e" for me.
    {										            // adding an input parameter would probably change it with each diff call?
    	return msg.data;
    }
    
    function msgSender() public view returns (address)  // Returns the address of whomever made this call
    {													// (i.e. not necessarily the creator of the contract)
    	return msg.sender;
    }
    
    function msgValue() public payable returns (uint)		// returns amt of wei sent with this call
    {
    	return msg.value;
    }

    // check balance of the contract
    function balanceOf() public view returns(uint) {
        return address(this).balance / 1e18;
    }

    
    /***  A note about gas and gasprice:
     
     Every transaction must specify a quantity of "gas" that it is willing to consume (called startgas), 
     and the fee that it is willing to pay per unit gas (gasprice). At the start of execution, 
     startgas * gasprice ether are removed from the transaction sender's account. 
     Whatever is not used is immediately refunded.
     
     */
    
    function msgGas() public view returns (uint)        
    {													
    	return gasleft();
    }
    
	function txGasprice() public view returns (uint) 	// "gasprice" is the amount of gas the sender was *willing* to pay. 50000000 for me. (geth default)
    {											     	
    	return tx.gasprice;
    }
    
    function txOrigin() public view returns (address) 	// returns sender of the transaction
    {											   		// What if there is a chain of calls? I think it returns the first sender, whoever provided the gas.
    	return tx.origin;
    }
    
	function contractAddress() public view returns (address) 
	{
		return creator;
	}
    
    function contractBalance() public view returns (uint) 
    {
    	return creator.balance;
    }
    
}
```
