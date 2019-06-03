pragma solidity 0.5.0;
import "./Owned.sol";

contract Running is Owned
{
    enum State {PAUSED, RUNNING, DEAD}
    State state;
    event LogRunningChanged(address sender, State newState);
    event LogKilled(address sender);

    modifier whenAlive
    {
        require(state != State.DEAD, "We are not alive");
        _;
    }

    modifier whenRunning
    {
        require(state == State.RUNNING, "We have stopped");
        _;
    }

    modifier whenPaused
    {
        require(state == State.PAUSED, "We are paused");
        _;
    }

    constructor(bool _running) public
    {
        state = (_running) ? State.RUNNING : State.PAUSED;
    }

    function isRunning() public view returns(bool)
    {
        return (state == State.RUNNING);
    }

    function pause() public
        onlyOwner
        whenRunning
        whenAlive
    {
        state = State.PAUSED;
        emit LogRunningChanged(msg.sender, state);
    }

    function resume() public
        onlyOwner
        whenPaused
        whenAlive
    {
        state = State.RUNNING;
        emit LogRunningChanged(msg.sender, state);
    }

    function kill()
        public
        onlyOwner
        whenPaused
        whenAlive
    {
        state = State.DEAD;
        emit LogKilled(msg.sender);
    }
}