# Solidity-Baby Steps...


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


#### Example-9 
> increment: transactions will be made when clicking 'increment'; result will be shown when clicking 'getIterration'.
```solidity
// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;
contract Increment {
    address creator;
    uint iteration;

    constructor() {
        creator = msg.sender;
        iteration = 0;
    }

    function increment() public {
        iteration += 1;
    }

    function getIteration() public view returns (uint) {
        return iteration;
    }

    function ContractBal() public view returns (uint) {
        return address(this).balance / 1e18;
    }

    function getBalance() public view returns (uint) {
        return creator.balance / 1e18;
    }

    function valueToContract() public payable returns (uint) {
        return msg.value;
    }
}
```

#### Example-10

> increment2: increment (integer) number can be defined by user

```solidity
// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract Increment2 {
    address owner;
    int iteration;
    string whatHappened;

    constructor() {
        owner = msg.sender;
        iteration = 0;
        whatHappened = "constructor executed";
    }

    function increment(int howmuch) public {
        if (howmuch == 0) {
            iteration += 1;
            whatHappened = "howmuch was 0. Incremented by 1.";
        }
        else {
            iteration += howmuch;
            whatHappened = "howmuch was not 0. Incremented by its value";
        }
        return;
    }

    function getWhatHappened() public view returns (string memory) {
        return whatHappened;
    }

    function getIteration() public view returns (int) {
        return iteration;
    }
}
```
	
#### Example-11
	
Increment3

```solidity
// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract Increment3 {
    address creator;
    int iteration;
    string whatHappened;
    int customValue;

    constructor () {
        creator = msg.sender;
        iteration = 0;
        whatHappened = "constructor initialized";
    }

    function increment(int incre, int _customValue) public {
        customValue = _customValue;
        if (incre == 0) {
            iteration += 1;
            whatHappened = "Increment was 0, Incremented by 1. Custom Value also set";
        }
        else {
            iteration += incre;
            whatHappened = "Increment was not 0, Incremented by its value. Custom Value also set";
        }
        return;
    }

    function getInfo() public view returns (string memory) {
        return whatHappened;
    }
    function getTotalIter() public view returns (int) {
        return iteration;
    }
}
```
#### Example-12

```solidity
// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract msgExaminer {
    address  owner;
    address  miner;

    constructor() {
         owner = msg.sender;
         miner = 0x8945A1288dc78A6D8952a92C77aEe6730B414778;
    }

    function getMsgData() public pure returns (bytes calldata) {
        return msg.data;
    }
    function getMsgGas() public view returns (uint) {
        return gasleft();
    }
    function getMsgVal() public payable returns (uint) {
        return msg.value;
    }

    	function txGasprice() public view returns (uint) 	// "gasprice" is the amount of gas the sender was *willing* to pay. 50000000 for me. (geth default)
    {											     	
    	return tx.gasprice;
    }
    
    function txOrigin() public view returns (address) 	// returns sender of the transaction
    {											   		// What if there is a chain of calls? I think it returns the first sender, whoever provided the gas.
    	return tx.origin;
    }

    function minerAddress() public view returns (address) // get CURRENT block miner's address, 
	{														     // not necessarily the address of the miner when this block was born
		return block.coinbase;
	}

}
```


#### Example-13

Add, update and delete student struct type

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract StudentList {
    struct Student{
        string name;
        uint age;
    }
    // 
    Student[] public students;

    function create(string memory _name, uint _age) public {
        students.push(Student({name:_name, age:_age}));
    }

    function updateAge(uint _index, uint _age) public {
        Student storage studentUpdate = students[_index];
        studentUpdate.age = _age;
    }

    function updateName(uint _index, string memory _name) public {
        Student storage studentUpdate = students[_index];
        studentUpdate.name = _name;
    }

    function getLength() public view returns (uint) {
        return students.length;
    }


    function getStudent(uint _index) public view returns (string memory name, uint age)  {
            Student storage studentEvr = students[_index];
            return (studentEvr.name, studentEvr.age);
    }


    // delete the last student
    function delLast() public {
        students.pop();
    }

    // delete student using index
    function remove(uint _index) public {
        require(_index < students.length, "index out of bound");
        for (uint i = _index; i < students.length - 1; i++) {
            students[i] = students[i + 1];
        }
        students.pop();
    }
}
```

#### Example-14

Balance 

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract Account {
    uint public balance;
    uint public constant MAX_UINT = 2**256 - 1;

    function deposit(uint _amount) public {
        uint oldBalance = balance;
        uint newBalance = balance + _amount;

        // balance + _amount does not overflow if balance + _amount >= balance
        require(newBalance >= oldBalance, "Overflow");

        balance = newBalance;

        assert(balance >= oldBalance);
    }

    function withdraw(uint _amount) public {
        uint oldBalance = balance;

        // balance - _amount does not underflow if balance >= _amount
        require(balance >= _amount, "Underflow");

        if (balance < _amount) {
            revert("Underflow");
        }

        balance -= _amount;

        assert(balance <= oldBalance);
    }
}

```


#### Example-15 

ETH transfer example
> Reference : [HERE](https://solidity-by-example.org/payable)
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract Payable {
    address payable public owner;

    constructor() payable {
        owner = payable(msg.sender);
    }
    // Function to deposit Ether into this contract.
    // Call this function along with some Ether.
    // The balance of this contract will be automatically updated.
    function deposit() public payable {}

    // check the balance of current contract
    function balContract() public view returns (uint) {
        return address(this).balance / 1e18;
    }

    function balOwner() public view returns (uint) {
        return address(owner).balance / 1e18;
    }

    function withdraw() public {
        // get the amount of Ether stored in this contract
        uint amount = address(this).balance;

        // send all Ether to owner
        // Owner can receive Ether since the address of owner is payable
        (bool success, ) = owner.call{value: amount}("");
        require(success, "Failed to send Ether");
    }

    // Function to transfer Ether from this contract to address from input
    function transfer(address payable _to, uint _amount) public {
        // Note that "to" is declared as payable
        (bool success, ) = _to.call{value: _amount * 1e18}("");
        require(success, "Failed to send Ether");
    }
}
```


#### Example-16
> Version2. slight difference...
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract Payable {
    address payable public owner;

    constructor() payable {
        owner = payable(msg.sender);
    }
    // Function to deposit Ether into this contract.
    // Call this function along with some Ether.
    // The balance of this contract will be automatically updated.
    function deposit() public payable {

    }

    receive() external payable {}
    fallback() external payable {}

    function deposit2(uint _amount) public payable {
        // Call returns a boolean value indicating success or failure.
        // This is the current recommended method to use.
        (bool sent, ) = (address(this)).call{value: _amount *1 * 1e18}("");
        require(sent, "Failed to send Ether");
    }

    // check the balance of current contract
    function balContract() public view returns (uint) {
        return address(this).balance / 1e18;
    }

    function balOwner() public view returns (uint) {
        return address(owner).balance / 1e18;
    }

    function withdraw() public {
        // get the amount of Ether stored in this contract
        uint amount = address(this).balance;

        // send all Ether to owner
        // Owner can receive Ether since the address of owner is payable
        (bool success, ) = owner.call{value: amount}("");
        require(success, "Failed to send Ether");
    }

    // Function to transfer Ether from this contract to address from input
    function transfer(address payable _to, uint _amount) public {
        // Note that "to" is declared as payable
        (bool success, ) = _to.call{value: _amount * 1e18}("");
        require(success, "Failed to send Ether");
    }

    function getConAddr() public view returns (address) {
        return address(this);
    }
}
```

#### Example-17

> Default values
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract DefaultVals {
    bool public b;  // default is false;
    uint public u;  // default is 0;
    int  public i;  // default is 0;
    address public a;   // default : 0x0000000000000000000000000000000000000000
    bytes32 public b32; // default : 0x0000000000000000000000000000000000000000000000000000000000000000
}
```

#### Example-18

> Constant state variables with called gas value
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// spend less gas when deploy the contract using constant state variables
// 21442 gas
contract Constants {
    // define a constant state variable
    address public constant MY_ADDRESS = 0x0000000000000000000000000000000000000100;
    uint public constant MY_UINT = 124;
}
// 23575 gas
contract Variables {
    address public MY_ADDRESS = 0x0000000000000000000000000000000000000100;
    uint public MY_UINT = 124;
}
```


#### Example-19
> How Modifier works in the contract.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract FunctionModifier {
    bool public paused;
    uint public counter;

    constructor () {
        paused = true;
    }

    function setPause() external {
        paused = !paused;
    }

    modifier whenNotPaused() {
        require(paused == false, "Paused!");
        _;
    }

    modifier cap(uint _x) {
        require(_x < 100, "x >= 100");
        _;
    } 

    function inc() external whenNotPaused {
        counter += 1;
    }

    function dec() external whenNotPaused {
        counter -= 1;
    }

    // Two modifiers are added, and pay attention to the second one with parameter in side
    function incBy(uint _x) external whenNotPaused cap(_x){
        counter += _x;
    }
}
```

#### Example-20

> Simple Access control management / ownership management
```solidity
// SPDX-License-Identifier:MIT

pragma solidity ^0.8.13;

// In this example we will use state variables, global variables, function modifier, function and error handling
// we will claim the ownership of the contract, so that the access control of functions have been made.

contract ownable {
    address public owner;

    constructor () {
        owner = msg.sender;
    }

    // access control 
    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    // set ownership of the contract
    function setOwner(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "invalid address");
        owner = _newOwner;
    }

    // only the current owner of the contract can call this function
    function onlyOwnerCanCall() external onlyOwner {
    }

    // every one can have access to this function
    function anyOneCanCall() external {
    }
}
```

#### Example-21

> Function outputs
```solidity
// SPDX-License-Identifier:MIT

pragma solidity ^0.8.13;

contract FunctionOutputs {
    function returnMany() public pure returns (uint, bool) {
        return (1, true);
    }
    // 0: uint256:  1
    // 1: bool:  true

    function named() public pure returns (uint x, bool b) {
        return (1, true);
    }
    // 0: uint256: x 1
    // 1: bool: b true

    function assigned() public pure returns (uint x, bool b) {
        x = 1;
        b = false;
    }
    // 0: uint256: x 1
    // 1: bool: b true

    function destructingAssignments() public pure returns (uint m, bool n, bool q) {
        (uint x, bool b) = returnMany();
        (, bool _b) = assigned();
        return (x, b, _b);
    }
}
```

#### Example-22

> Array basics

```solidity
// SPDX-License-Identifier:MIT

pragma solidity ^0.8.13;

// Array - dynamic or fixed size
// Initialization
// Insert (push) , get, update, delete, pop, length
// creating array in memory
// returning array from function

contract Array {
    uint[] public nums = [1,3,5];
    uint[3] public numsFixed = [4,5,6]; // you cannot push() to a fixed sized array.

    function examples(uint _x) external {
        nums.push(_x);
        uint x = nums[1];
        nums[2] = x;
        delete nums[0];  // replace the number that indicated with 0, 
        nums.pop(); // the last element of the array will be deleted.

        // create an array in memory
        // Array in memory has to be fixed sized
        // so a.pop() or a.push() cannot be used.
        uint[] memory a = new uint[] (5);

        // assign value to element
        a[1] = 23;
    }

    // not recommended because a lot of gas will be charged.
    function returnArray() external view returns (uint[] memory) {
        return nums;
    }
}
```

#### Example-23
```solidity
// SPDX-License-Identifier:MIT

pragma solidity ^0.8.14;

// Mapping 
// How to declare a mapping (simple and nested)
// set, get, and delete

// ["alice", "bob", "charlie"]
// {"alice": true, "bob":true, "charlie":true }

contract Mapping {
    mapping(address => uint) public balances;
    mapping(address => mapping(address => bool)) public isFriend;

    function examples() external {
        balances[msg.sender] = 123;
        // uint bal = balances[msg.sender];
        // uint bal2 = balances[address(1)]; // 0
        balances[msg.sender] += 456; // 123 +456 
        //delete balances[msg.seder]; // 0
        isFriend[msg.sender][address(this)] = true;
    }
}

contract IterableMapping {
    mapping (address => uint) public balances;
    mapping (address => bool) public inserted;

    address[] public keys;

    // assign value to address and push into array.
    // one address can only be pushed once;
    function set(address _key, uint _val) external {
        require(!inserted[_key], "Value has been assigned to this address!");
        inserted[_key] =true;
        balances[_key] = _val;
        keys.push(_key);
    }
    function getSize() external view returns (uint) {
        return keys.length;
    }
    function first() external view returns (uint) {
        return balances[keys[0]];
    }
    function last() external view returns (uint) {
        return balances[keys[keys.length-1]];
    }
    function get(uint _i) external view returns (uint) {
        return balances[keys[_i]];
    }
}
```

#### Example-24
> Learning struct

```solidity
// SPDX-License-Identifier:MIT

pragma solidity ^0.8.14;

contract Structs {
    struct Car {
        string model;
        uint year;
        address owner;
    }

    Car public car;
    Car[] public cars;
    mapping(address => Car[]) public carsByOwner;

    function examples() external {
        Car memory toyota = Car("Toyota", 1990, msg.sender);
        Car memory lambo  = Car({year: 1980, model: "Lamborghini", owner: msg.sender});
        Car memory tesla;
        tesla.model = "Tesla";
        tesla.year  = 2000;
        tesla.owner = msg.sender;

        cars.push(toyota);
        cars.push(lambo);
        cars.push(tesla);
        cars.push(Car("Ferrari", 2022, msg.sender));

        // Car memory _car = cars[0];
        // _car.model;
        // _car.year;
        // _car.owner;

        // modify the data cars[0] that is stored in the memory. 
        // that is why we use 'storage' rather than 'memory';
        Car storage _car = cars[0]; //modify the attributes of cars[0];
        _car.year = 1999;
        delete _car.owner;  // set to the default value;
        delete cars[1];     // reset to default value;

    }
}
```
#### Example-25

> Learning enum 



```solidity
// SPDX-License-Identifier:MIT

pragma solidity ^0.8.14;

contract Enum {
    enum Status {
        None,       //0
        Pending,    //1
        Shipped,    //2
        Rejected,   //3
        Canceled    //4
    }

    Status public status;
    string strtusToString;

    struct Order {
        address buyer;
        Status status;
    }

    Order[] public orders;

    function get()  external view returns (Status) {
        return status; 
    }

    function set(Status _status) external {
        status = _status;
    }

    function ship() external {
        status = Status.Shipped;
    }

    function reset() external {
        delete status;
    }
}
```
