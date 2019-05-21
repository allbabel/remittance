pragma solidity 0.5.0;
import "./Running.sol";
import "./SafeMath.sol";

contract Remittance is Running
{
    using SafeMath for uint256;
    uint public depositFee;
    mapping(address => uint) fees;
    uint constant MONTH_IN_SECS = 1 * 28 days;
    mapping(address => Deposit) public deposits;

    event LogDeposit(address indexed owner, bytes32 password, uint timeout, uint indexed created, uint value, uint depositFee);
    event LogTransfer(address indexed owner, address indexed remittant, uint256 amount);
    event LogTimeoutChanged(address indexed owner, uint newTime, uint oldTime);
    event LogWithdraw(address indexed owner, uint amount);
    event LogDepositFee(address indexed owner, uint oldFee, uint newFee);

    struct Deposit
    {
        address owner;
        bytes32 hashPassword;
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
        emit LogDepositFee(msg.sender, depositFee, _depositFee);

        depositFee = _depositFee;
    }

    function isExpired(address addr)
        public
        view
        depositExists(addr)
        returns(bool)
    {
        Deposit storage deposit = deposits[addr];
        if (now > deposit.created)
        {
            return now - deposit.created > deposit.timeout;
        }

        return false;
    }

    function setTimeoutInSeconds(uint timeout)
        public
        depositExists(msg.sender)
    {
        require(timeout > 0 && timeout < MONTH_IN_SECS, 'Timeout needs to be valid');
        emit LogTimeoutChanged(msg.sender, deposits[msg.sender].timeout, timeout * 1 days);

        deposits[msg.sender].timeout = timeout;
    }

    function deposit(bytes32 hashPassword, uint timeout)
        public
        payable
        depositDoesNotExist(msg.sender)
    {
        // Amount deposited to contract, we need something
        require(msg.value > 0, 'Need to deposit something');
        require(timeout > 0 && timeout < MONTH_IN_SECS, 'Timeout needs to be valid');
        require(uint(hashPassword) > 0, 'Invalid hash');

        uint depositValue = msg.value;
        if (depositFee < msg.value)
        {
            depositValue = msg.value.sub(depositFee);
            fees[getOwner()] = fees[getOwner()].add(depositFee);
        }

        deposits[msg.sender] = Deposit( msg.sender,
                                        hashPassword,
                                        timeout,
                                        now,
                                        depositValue);

        emit LogDeposit(msg.sender,
                        hashPassword,
                        timeout,
                        now,
                        depositValue,
                        depositFee);
    }

    function withdraw(address depositOwner, bytes memory _password1, bytes memory _password2)
        public
        depositExists(depositOwner)
    {
        require(msg.sender != getOwner(), 'Contract owner not allowed');
        require(keccak256(abi.encode(_password1, _password2)) == deposits[depositOwner].hashPassword, 'Invalid answer');
        require(deposits[depositOwner].value > 0, 'No balance available');

        uint valueToSend = deposits[depositOwner].value;
        delete deposits[depositOwner];
        emit LogTransfer(   depositOwner,
                            msg.sender,
                            valueToSend);
        msg.sender.transfer(valueToSend);
    }

    function ownerWithdraw(address depositOwner)
        public
        isOwner
    {
        require(isExpired(depositOwner), 'Deposit is not expired');
        require(deposits[depositOwner].value > 0, 'No balance available');

        uint valueToSend = deposits[depositOwner].value;
        delete deposits[depositOwner];
        emit LogTransfer(   depositOwner,
                            msg.sender,
                            valueToSend);
        msg.sender.transfer(valueToSend);
    }

    function withdrawDepositFees()
        public
    {
        require(fees[msg.sender] > 0, 'No balance to withdraw');
        uint toSend = fees[msg.sender];
        delete fees[msg.sender];
        emit LogWithdraw(msg.sender, toSend);
        msg.sender.transfer(toSend);
    }
}