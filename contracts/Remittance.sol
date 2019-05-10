pragma solidity 0.5.0;
import "./Running.sol";

contract Remittance is Running
{
    bytes32 public password1;
    bytes32 public password2;
    bool locked;

    event LogDeposit(address owner, bytes32 password1, bytes32 password2, uint256 amount);
    event LogTransfer(address owner, address remittant, bytes32 password1, bytes32 password2, uint256 amount);

    constructor()
        public
    {
        setRunning(true);
    }

    modifier isUnlocked()
    {
        require(!locked, 'Remittance is locked');
        _;
    }

    modifier isLocked()
    {
        require(locked, 'Remittance is unlocked');
        _;
    }

    function getLocked()
        public
        view
        returns(bool)
    {
        return locked;
    }

    function deposit(bytes32 _password1, bytes32 _password2)
        public
        isOwner
        isUnlocked
        payable
    {
        // Amount deposited to contract, we need something
        require(msg.value > 0, 'Need to deposit something');

        // Store the puzzle
        password1 = _password1;
        password2 = _password2;

        // Lock contract to avoid more deposits
        locked = true;

        emit LogDeposit(getOwner(), password1, password2, msg.value);
    }

    function withdraw(bytes memory _password1, bytes memory _password2)
        public
        isLocked
    {
        require(keccak256(_password1) == password1 &&
                keccak256(_password2) == password2, 'Invalid answer');

        uint balance = address(this).balance;
        require(balance > 0, 'No balance available');
        msg.sender.transfer(balance);

        emit LogTransfer(getOwner(), msg.sender, password1, password2, balance);
    }

    function test(bytes memory str1) public pure returns(bytes32)
    {
        return keccak256(str1);
    }
}