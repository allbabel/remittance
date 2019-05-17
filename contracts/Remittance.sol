pragma solidity 0.5.0;
import "./Running.sol";
import "./SafeMath.sol";

contract Remittance is Running
{
    using SafeMath for uint256;
    uint constant DEFAULT_TIMEOUT = 7 days;
    uint public depositFee;

    mapping(address => Deposit) public deposits;

    event LogDeposit(address indexed owner, bytes32 password1, bytes32 password2, uint timeout, uint indexed created, uint value);
    event LogTransfer(address indexed owner, address indexed remittant, uint256 amount);
    event LogTimeoutChanged(address indexed owner, uint newDays, uint oldDays);
    event LogWithdraw(address indexed owner, uint amount);

    struct Deposit
    {
        address owner;
        bytes32 hashPassword1;
        bytes32 hashPassword2;
        uint timeout;
        uint created;
        uint value;
    }

    constructor()
        Running(true)
        public
    {
    }

    modifier depositDoesNotExist(address addr)
    {
        require(deposits[addr].created == 0, 'Deposit exists');
        _;
    }

    modifier depositExists(address addr)
    {
        require(deposits[addr].created > 0, 'Invalid deposit');
        _;
    }

    function setDepositFee(uint _depositFee)
        public
        isOwner
    {
        require(depositFee != _depositFee, 'Values are equal');
        depositFee = _depositFee;
    }

    function isItTime(address addr)
        public
        view
        depositExists(addr)
        returns(bool)
    {
        Deposit storage deposit = deposits[addr];
        return now.sub(deposit.created) > deposit.timeout;
    }

    function setTimeoutInDays(uint timeout)
        public
        depositExists(msg.sender)
    {
        require(timeout > 0 && timeout < 28, 'Timeout needs to be valid');
        emit LogTimeoutChanged(msg.sender, deposits[msg.sender].timeout, timeout * 1 days);

        deposits[msg.sender].timeout = timeout * 1 days;
    }

    function deposit(bytes32 hashPassword1, bytes32 hashPassword2)
        public
        payable
        depositDoesNotExist(msg.sender)
    {
        // Amount deposited to contract, we need something
        require(msg.value > 0, 'Need to deposit something');

        require(hashPassword1.length > 0 || hashPassword2.length > 0, 'Invalid password(s)');

        uint depositValue = msg.value;
        if (depositFee < msg.value)
        {
            depositValue = msg.value - depositFee;
        }

        deposits[msg.sender] = Deposit( msg.sender,
                                        hashPassword1,
                                        hashPassword2,
                                        DEFAULT_TIMEOUT,
                                        now,
                                        depositValue);

        emit LogDeposit(msg.sender,
                        deposits[msg.sender].hashPassword1,
                        deposits[msg.sender].hashPassword2,
                        deposits[msg.sender].timeout,
                        deposits[msg.sender].created,
                        deposits[msg.sender].value);
    }

    function withdraw(address owner, bytes memory _password1, bytes memory _password2)
        public
        depositExists(owner)
    {
        require(keccak256(_password1) == deposits[owner].hashPassword1 &&
                keccak256(_password2) == deposits[owner].hashPassword2, 'Invalid answer');

        require(deposits[owner].value > 0, 'No balance available');

        uint valueToSend = deposits[owner].value;
        delete deposits[owner];
        msg.sender.transfer(valueToSend);
        emit LogTransfer(   owner,
                            msg.sender,
                            valueToSend);
    }

    function withdrawFromContract()
        public
        isOwner
    {
        msg.sender.transfer(address(this).balance);
        emit LogWithdraw(msg.sender, address(this).balance);
    }
}