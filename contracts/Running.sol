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

    modifier isPaused
    {
        require(!running, "We are paused");
        _;
    }

    constructor(bool _running) public
    {
        running = _running;
    }

    function getRunning() public view returns(bool)
    {
        return running;
    }

    function pause() public isOwner
        isRunning
    {
        setRunning(false);
    }

    function resume() public isOwner
        isPaused
    {
        setRunning(true);
    }

    function setRunning(bool newRunning)
        public
        isOwner
    {
        emit LogRunningChanged(running, newRunning);
        running = newRunning;
    }

    function kill()
        public
        isOwner
    {
        selfdestruct(msg.sender);
    }
}