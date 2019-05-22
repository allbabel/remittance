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

    event LogDeposit(address indexed owner, bytes32 password, uint indexed expires, uint value, uint depositFee);
    event LogTransfer(address indexed owner, address indexed remittant, uint256 amount);
    event LogTimeoutChanged(address indexed owner, uint newTime, uint oldTime);
    event LogWithdraw(address indexed owner, uint amount);
    event LogDepositFee(address indexed owner, uint oldFee, uint newFee);

    struct Deposit
    {
        address owner;
        bytes32 hashPassword;
        uint expires;
        uint value;
    }

    constructor()
        Running(true)
        public
    {
    }

    modifier depositDoesNotExist(address addr)
    {
        require(deposits[addr].expires == 0, 'Deposit exists');
        _;
    }

    modifier depositExists(address addr)
    {
        require(deposits[addr].expires > 0, 'Invalid deposit');
        _;
    }

    function encode(bytes16 password1, bytes16 password2) public pure returns (bytes32)
    {
        return keccak256(abi.encode(password1, password2));
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
        uint expires = deposit.expires;
        return now > expires;
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
            address owner = getOwner();
            fees[owner] = fees[owner].add(depositFee);
        }

        deposits[msg.sender] = Deposit( msg.sender,
                                        hashPassword,
                                        timeout + now,
                                        depositValue);

        emit LogDeposit(msg.sender,
                        hashPassword,
                        timeout + now,
                        depositValue,
                        depositFee);
    }

    function withdraw(address depositOwner, bytes16 _password1, bytes16 _password2)
        public
        depositExists(depositOwner)
    {
        require(encode(_password1, _password2) == deposits[depositOwner].hashPassword, 'Invalid answer');
        require(deposits[depositOwner].value > 0, 'No balance available');
        if (getOwner() == msg.sender)
            require(isExpired(depositOwner), 'Deposit is not expired');

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
        uint toSend = fees[msg.sender];
        require(toSend > 0, 'No balance to withdraw');
        delete fees[msg.sender];
        emit LogWithdraw(msg.sender, toSend);
        msg.sender.transfer(toSend);
    }
}