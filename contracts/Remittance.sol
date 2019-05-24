pragma solidity 0.5.0;
import "./Running.sol";
import "./SafeMath.sol";

contract Remittance is Running
{
    using SafeMath for uint256;
    uint public depositFee;
    mapping(address => uint) public fees;
    uint constant MONTH_IN_SECS = 1 * 28 days;
    mapping(bytes32 => Deposit) public deposits;
    
    event LogDeposit(address indexed remiter, bytes32 puzzle, uint indexed expires, uint value, uint depositFee);
    event LogTransfer(bytes32 puzzle, address indexed remittant, uint256 amount);
    event LogWithdraw(address indexed remitter, uint amount);
    event LogDepositFee(address indexed remitter, uint oldFee, uint newFee);
    
    struct Deposit
    {
        address remitter;
        bytes32 puzzle;
        uint expires;
        uint value;
    }

    constructor()
        Running(true)
        public
    {
    }

    modifier depositDoesNotExist(bytes32 puzzle)
    {
        require(deposits[puzzle].expires == 0, 'Deposit exists');
        _;
    }

    modifier depositExists(bytes32 puzzle)
    {
        require(deposits[puzzle].expires > 0, 'Invalid deposit');
        _;
    }

    function createPuzzle(address recipient, bytes32 password1) public pure returns (bytes32)
    {
        require(recipient != address(0x0), 'Invalid address');
        require(password1 != "", 'Invalid password');

        return keccak256(abi.encodePacked(recipient, password1));
    }

    function setDepositFee(uint _depositFee)
        public
        isOwner
    {
        require(depositFee != _depositFee, 'Values are equal');
        emit LogDepositFee(msg.sender, depositFee, _depositFee);

        depositFee = _depositFee;
    }

    function isExpired(bytes32 puzzle)
        public
        view
        depositExists(puzzle)
        returns(bool)
    {
        Deposit storage deposit = deposits[puzzle];
        return now > deposit.expires;
    }

    function deposit(bytes32 puzzle, uint timeout)
        public
        payable
        depositDoesNotExist(puzzle)
    {
        // Amount deposited to contract, we need something
        require(msg.value > 0, 'Need to deposit something');
        require(timeout > 0 && timeout < MONTH_IN_SECS, 'Timeout needs to be valid');
        require(puzzle != "", 'Invalid puzzle');

        uint depositValue = msg.value;
        if (depositFee < msg.value)
        {
            depositValue = msg.value.sub(depositFee);
            address owner = getOwner();
            fees[owner] = fees[owner].add(depositFee);
        }

        deposits[puzzle] = Deposit(
                                        {
                                            remitter: msg.sender,
                                            puzzle: puzzle,
                                            expires: timeout + now,
                                            value: depositValue
                                        }
                                    );

        emit LogDeposit(msg.sender,
                        puzzle,
                        timeout + now,
                        depositValue,
                        depositFee);
    }

    function remitterWithdraw(bytes32 puzzle)
        public
        depositExists(puzzle)
    {
        require(isExpired(puzzle), 'Deposit is not expired');

        uint valueToSend = deposits[puzzle].value;
        require(valueToSend > 0, 'Nothing to withdraw');

        delete deposits[puzzle];
        emit LogTransfer(   puzzle,
                            msg.sender,
                            valueToSend);

        msg.sender.transfer(valueToSend);
    }

    function withdraw(bytes32 puzzle, bytes32 _password1)
        public
        depositExists(puzzle)
    {
        uint valueToSend = deposits[puzzle].value;
        require(valueToSend > 0, 'No balance available');
        require(createPuzzle(msg.sender, _password1) == deposits[puzzle].puzzle, 'Invalid answer');

        delete deposits[puzzle];
        emit LogTransfer(   puzzle,
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