// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BookTokenWrapperCloneFactory is Ownable {
    address public immutable wrapperImplementation;
    event WrapperCreated(address indexed creator, address indexed wrapper, uint256 indexed bookId);

    constructor(address _wrapperImplementation) {
        wrapperImplementation = _wrapperImplementation;
    }

    function createAndBindBookWrapper(
        address book1155,
        uint256 bookId,
        string memory name,
        string memory symbol
    ) external returns (address wrapper) {
        require(IAuthorBook1155(book1155).owner() == msg.sender, "Not book contract owner");
        wrapper = Clones.clone(wrapperImplementation);
        IBookTokenERC20Wrapper(wrapper).initialize(book1155, bookId, name, symbol);
        emit WrapperCreated(msg.sender, wrapper, bookId);
    }
}
