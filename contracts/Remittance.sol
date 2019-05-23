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

    event LogDeposit(address indexed remiter, bytes32 password, uint indexed expires, uint value, uint depositFee);
    event LogTransfer(address indexed remiter, address indexed remittant, uint256 amount);
    event LogWithdraw(address indexed remitter, uint amount);
    event LogDepositFee(address indexed remitter, uint oldFee, uint newFee);
    
    struct Deposit
    {
        address remitter;
        bytes32 secret;
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

    function encode(address recipient, bytes32 password1, bytes32 password2) public pure returns (bytes32)
    {
        return keccak256(abi.encodePacked(recipient, password1, password2));
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
        return now > deposit.expires;
    }

    function deposit(bytes32 secret, uint timeout)
        public
        payable
        depositDoesNotExist(msg.sender)
    {
        // Amount deposited to contract, we need something
        require(msg.value > 0, 'Need to deposit something');
        require(timeout > 0 && timeout < MONTH_IN_SECS, 'Timeout needs to be valid');
        require(uint(secret) > 0, 'Invalid hash');

        uint depositValue = msg.value;
        if (depositFee < msg.value)
        {
            depositValue = msg.value.sub(depositFee);
            address owner = getOwner();
            fees[owner] = fees[owner].add(depositFee);
        }

        deposits[msg.sender] = Deposit(
                                        {
                                            remitter: msg.sender,
                                            secret: secret,
                                            expires: timeout + now,
                                            value: depositValue
                                        }
                                    );

        emit LogDeposit(msg.sender,
                        secret,
                        timeout + now,
                        depositValue,
                        depositFee);
    }

    function remitterWithdraw()
        public
        depositExists(msg.sender)
    {
        require(isExpired(msg.sender), 'Deposit is not expired');

        uint valueToSend = deposits[msg.sender].value;
        delete deposits[msg.sender];
        emit LogTransfer(   msg.sender,
                            msg.sender,
                            valueToSend);

        msg.sender.transfer(valueToSend);
    }

    function withdraw(address remitter, bytes32 _password1, bytes32 _password2)
        public
        depositExists(remitter)
    {
        Deposit memory d = deposits[remitter];
        require(d.value > 0, 'No balance available');
        require(encode(msg.sender, _password1, _password2) == d.secret, 'Invalid answer');

        uint valueToSend = d.value;
        delete deposits[remitter];
        emit LogTransfer(   remitter,
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