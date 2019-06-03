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

    event LogDeposit(address indexed remiter, bytes32 indexed puzzle, uint expires, uint value, uint depositFee);
    event LogTransfer(bytes32 indexed puzzle, address indexed remittant, uint256 amount);
    event LogWithdraw(address indexed remitter, uint amount);
    event LogDepositFee(address indexed remitter, uint oldFee, uint newFee);

    struct Deposit
    {
        address remitter;
        uint expires;
        uint value;
    }

    constructor(uint _depositFee)
        Running(true)
        public
    {
        depositFee = _depositFee;
    }

    modifier depositIsValidAndFromRemitter(bytes32 puzzle)
    {
        require(puzzle != "", 'Invalid puzzle');
        require(deposits[puzzle].remitter == msg.sender, 'Deposit is not valid');
        _;
    }

    modifier depositIsValid(bytes32 puzzle)
    {
        require(puzzle != "", 'Invalid puzzle');
        require(deposits[puzzle].remitter != address(0x0), 'Deposit is not valid');
        _;
    }

    modifier depositIsEmpty(bytes32 puzzle)
    {
        require(puzzle != "", 'Invalid puzzle');
        require(    deposits[puzzle].remitter == address(0x0), 'Deposit is not empty');
        _;
    }

    function createPuzzle(address recipient, bytes32 password1) public view returns (bytes32)
    {
        require(recipient != address(0x0), 'Invalid address');
        require(password1 != "", 'Invalid password');

        return keccak256(abi.encodePacked(recipient, password1, address(this)));
    }

    function setDepositFee(uint _depositFee)
        public
        onlyOwner
        whenAlive
    {
        require(_depositFee > 0, 'Deposit needs to be greater than 0');
        require(depositFee != _depositFee, 'Values are equal');
        emit LogDepositFee(msg.sender, depositFee, _depositFee);

        depositFee = _depositFee;
    }

    function isExpired(bytes32 puzzle)
        public
        view
        depositIsValid(puzzle)
        returns(bool)
    {
        return now > deposits[puzzle].expires;
    }

    function deposit(bytes32 puzzle, uint timeout)
        public
        payable
        depositIsEmpty(puzzle)
        whenAlive
    {
        // Amount deposited to contract, we need something
        require(msg.value > 0, 'Need to deposit something');
        require(timeout > 0 && timeout < MONTH_IN_SECS, 'Timeout needs to be valid');

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
        depositIsValidAndFromRemitter(puzzle)
    {
        require(isExpired(puzzle), 'Deposit is not expired');

        uint valueToSend = deposits[puzzle].value;
        require(valueToSend > 0, 'Nothing to withdraw');

        deposits[puzzle].value = 0;

        emit LogTransfer(   puzzle,
                            msg.sender,
                            valueToSend);

        msg.sender.transfer(valueToSend);
    }

    function withdraw(bytes32 _password1)
        public
    {
        bytes32 puzzle = createPuzzle(msg.sender, _password1);
        uint valueToSend = deposits[puzzle].value;
        require(valueToSend > 0, 'No balance available');
        // Clear members except remitter which we use to track used puzzles.
        deposits[puzzle].value = 0;
        deposits[puzzle].expires = 0;

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