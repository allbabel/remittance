pragma solidity 0.5.0;
import "./Owned.sol";

contract Running is Owned
{
    bool private running;

    event LogRunningChanged(bool oldRunning, bool newRunning);

    modifier isRunning
    {
        require(running, "We have stopped");
        _;
    }

    constructor() public
    {
    }

    function getRunning() public view returns(bool)
    {
        return running;
    }

    function setRunning(bool newRunning) public isOwner
    {
        emit LogRunningChanged(running, newRunning);
        running = newRunning;
    }
}