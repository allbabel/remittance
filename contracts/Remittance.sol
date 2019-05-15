pragma solidity 0.5.0;
import "./Running.sol";

contract Remittance is Running
{
    bytes32 password1;
    bytes32 password2;
    uint timeout;
    uint created;
    uint constant DEFAULT_TIMEOUT = 7 days;
    bool locked;

    event LogDeposit(address owner, bytes32 password1, bytes32 password2, uint256 amount);
    event LogTransfer(address owner, address remittant, bytes32 password1, bytes32 password2, uint256 amount);
    event LogTimeoutChanged(address owner, uint newDays, uint oldDays);

    constructor()
        public
    {
        setRunning(true);
        timeout = DEFAULT_TIMEOUT;
        created = now;
    }

    function isItTime()
        private
        view
        returns(bool)
    {
        return (now - created) > timeout;
    }

    function setTimeoutInDays(uint8 _timeout)
        public
        isOwner
    {
        require(_timeout > 0, 'Timeout needs to be valid');

        uint newDays = (_timeout) * 1 days;
        uint oldDays = _timeout;
        timeout = newDays;

        emit LogTimeoutChanged(getOwner(), newDays, oldDays);
    }

    function deposit(bytes32 _password1, bytes32 _password2)
        public
        isOwner
        payable
    {
        require(!locked, 'Remittance is locked');

        // Amount deposited to contract, we need something
        require(msg.value > 0, 'Need to deposit something');

        require(_password1.length > 0 || _password2.length > 0, 'Invalid password(s)');

        locked = true;

        // Store the puzzle
        password1 = _password1;
        password2 = _password2;

        emit LogDeposit(getOwner(), password1, password2, msg.value);
    }

    function withdraw(bytes memory _password1, bytes memory _password2)
        public
    {
        require(locked, 'Remittance is unlocked');

        require((getOwner() == msg.sender && isItTime()) ||
                msg.sender != getOwner(), 'Unable to withdraw');

        require(keccak256(_password1) == password1 &&
                keccak256(_password2) == password2, 'Invalid answer');

        locked = false;

        uint balance = address(this).balance;
        require(balance > 0, 'No balance available');
        msg.sender.transfer(balance);

        password1 = '';
        password2 = '';
        emit LogTransfer(getOwner(), msg.sender, password1, password2, balance);
    }

    function killMe()
        public
        isOwner
    {
        selfdestruct(msg.sender);
    }
}