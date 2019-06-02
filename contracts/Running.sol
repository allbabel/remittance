pragma solidity 0.5.0;
import "./Owned.sol";

contract Running is Owned
{
    bool private running;
    bool private alive;

    event LogRunningChanged(address sender, bool newRunning);

    modifier whenAlive
    {
        require(alive, "We are not alive");
        _;
    }

    modifier whenRunning
    {
        require(running, "We have stopped");
        _;
    }

    modifier whenPaused
    {
        require(!running, "We are paused");
        _;
    }

    constructor(bool _running) public
    {
        alive = true;
        running = _running;
    }

    function isRunning() public view returns(bool)
    {
        return running;
    }

    function pause() public
        onlyOwner
        whenRunning
    {
        running = false;
        emit LogRunningChanged(msg.sender, running);
    }

    function resume() public
        onlyOwner
        whenPaused
    {
        running = true;
        emit LogRunningChanged(msg.sender, running);
    }

    function kill()
        public
        onlyOwner
        whenPaused
        whenAlive
    {
        alive = false;
    }
}