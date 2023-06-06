// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

// Abstract contract
abstract contract abacAccessControl {
    struct Permissions {
        bool canRead;
        bool canWrite;
        uint256 remainingOperations;
    }

    mapping(address => Permissions) internal _permissions;

    string private result;

    constructor() {
        _permissions[msg.sender] = Permissions(true, true, 3);

    }

    // Function: Get the permissions for an address
    function getPermissions(address account) external view returns (Permissions memory) {
        return _permissions[account];
    }

    // Abstract function: Update the permissions for an address
    function updatePermissions(address account, bool canRead, bool canWrite, uint256 remainingOperations) external virtual;
}


contract MyContract is abacAccessControl {
    // Modifier: Only the contract owner can call the function
    address owner;
    bool public isExecuted;

    constructor() {
        owner = msg.sender;
        isExecuted = false;
    }

    event AccessStatus (address indexed user, string reason);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the contract owner can call this function");
        _;
    }

    // Override the abstract function and provide a concrete implementation
    function updatePermissions(address account, bool canRead, bool canWrite, uint256 remainingOperations) external override onlyOwner {
        _permissions[account] = Permissions({
            canRead: canRead,
            canWrite: canWrite,
            remainingOperations: remainingOperations
        });
    }

    function foo() public returns (bool){

        require (_permissions[msg.sender].canWrite, "Visitor does not have write permission");
        require(_permissions[msg.sender].remainingOperations > 0, "Visitor has no remaining operations"); 
        isExecuted = true;
        _permissions[msg.sender].remainingOperations --;
        return isExecuted;
    }

    function isFooExecuted() public {
        if (isExecuted) {
            emit AccessStatus(msg.sender, "true");
            isExecuted = false;
        } else {
            emit AccessStatus(msg.sender, "false");
        }
    }
}
