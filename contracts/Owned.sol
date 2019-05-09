pragma solidity 0.5.0;

contract Owned
{
    address public owner;
    event LogOwnerChanged(address indexed oldOwner, address indexed newOwner);

    constructor () public
    {
        owner = msg.sender;
    }

    modifier isOwner
    {
        require(msg.sender == owner, "Owner permission required");
        _;
    }

    function changeOwner(address newOwner) public
        isOwner
        returns (bool success)
    {
        emit LogOwnerChanged(owner, newOwner);
        owner = newOwner;
        return true;
    }
}