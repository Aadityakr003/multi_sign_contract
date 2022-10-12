// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract MultiSigWallet {

    event Deposit(address indexed sender, uint amount, uint balance);
    event SubmitTransaction(
        address indexed owner,
        uint indexed txIndex,
        address indexed to,
        uint value,

        bytes data
    );
    event ConfirmTransaction(address indexed owner, uint indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint indexed txIndex);

    address[] public  owners;
    uint256 public  txCounter;
    mapping(address => bool) public  isOwner;
    uint public  numConfirmationsRequired;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        mapping(address => bool) isConfirmed;
        uint8 numConfirmations;
    }

    mapping(uint256=>Transaction) public  transactions;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    modifier txExists(uint _txIndex) {
        require(_txIndex < txCounter, "tx does not exist");
        _;
    }

    modifier notExecuted(uint _txIndex) {
        require(!transactions[_txIndex].executed, "tx already executed");
        _;
    }

    modifier notConfirmed(uint _txIndex) {
        require(!transactions[_txIndex].isConfirmed[msg.sender], "tx already confirmed");
        _;
    }
    constructor(address[] memory _owners, uint _numConfirmationsRequired)  {
        require(_owners.length > 0, "owners required");
        require(
            _numConfirmationsRequired > 0 && _numConfirmationsRequired <= _owners.length,
            "invalid number of required confirmations"
        );

        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];

            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        numConfirmationsRequired = _numConfirmationsRequired;
    }

  

    receive()  external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }
  
    function submitTransaction(address _to, uint _value, bytes memory _data)
        external 
        onlyOwner
    {
        uint txIndex = txCounter;
        Transaction storage t= transactions[txIndex];
        t.to=_to;
        t.value= _value;
        t.data=_data;
        t.executed= false;
        t.numConfirmations=0;
        txCounter++;
        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }

    function confirmTransaction(uint _txIndex)
        external 
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];

        transaction.isConfirmed[msg.sender] = true;
        transaction.numConfirmations += 1;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    function executeTransaction(uint _txIndex)
        external
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];

        require(
            transaction.numConfirmations >= numConfirmationsRequired,
            "cannot execute tx"
        );

        transaction.executed = true;
        payable(transaction.to).transfer(transaction.value);
        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    // cancle transaction
    function revokeConfirmation(uint _txIndex)
        external
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];

        require(transaction.isConfirmed[msg.sender], "tx not confirmed");

        transaction.isConfirmed[msg.sender] = false;
        transaction.numConfirmations -= 1;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() external view returns (uint) {
        return txCounter;
    }


    function isConfirmed(uint _txIndex, address _owner)
        external 
        view
        returns (bool)
    {
        Transaction storage transaction = transactions[_txIndex];

        return transaction.isConfirmed[_owner];
    }
}
