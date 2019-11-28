pragma solidity ^0.5.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {

    uint private MAX_TOKEN = 1000000000; //1 000 000 000
    address public owner;

    constructor() public{
        owner = msg.sender;
        _mint(address(this), MAX_TOKEN);
    }

    function BuyToken(address buyer, uint256 amount) public{
        assert(msg.sender == owner);
        _transfer(address(this), buyer, amount);
    }

    function SellToken(uint256 amount) public {
        require(balanceOf(msg.sender) >= amount, "You haven't token");
        _transfer(msg.sender, address(this), amount);
    }
}