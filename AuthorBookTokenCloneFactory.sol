// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IAuthorBookToken {
    function initialize(
        address author,
        string memory baseUri
    ) external;
}

contract AuthorBookTokenCloneFactory is Ownable {
    address public immutable implementation;
    event CloneCreated(address indexed author, address indexed clone);

    IERC20 public immutable usdt;
    uint256 public registrationFee = 50 * 10 ** 6; // default 50 USDT (6 decimals)

    constructor(address _implementation, IERC20 _usdt) {
        implementation = _implementation;
        usdt = _usdt;
    }

    function setRegistrationFee(uint256 newFee) external onlyOwner {
        require(newFee > 0, "Fee must be > 0");
        registrationFee = newFee;
    }

    function withdrawUSDT(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Invalid address");
        require(usdt.transfer(to, amount), "Withdraw USDT failed");
    }

    function usdtBalance() external view returns (uint256) {
        return usdt.balanceOf(address(this));
    }

    function registerAuthor(
        string memory baseUri
    ) external returns (address proxy) {
        require(usdt.transferFrom(msg.sender, address(this), registrationFee), "Payment failed");

        proxy = Clones.clone(implementation);
        IAuthorBookToken(proxy).initialize(
            msg.sender,
            baseUri
        );
        emit CloneCreated(msg.sender, proxy);
    }
}
