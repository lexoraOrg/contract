// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AuthorBookToken is ERC1155, Ownable {
    address public author;
    string public baseUri;
    mapping(uint256 => string) private _tokenURIs;

    constructor() ERC1155("") {}

    function initialize(address _author, string memory _baseUri) external {
        require(author == address(0), "Already initialized");
        author = _author;
        baseUri = _baseUri;
        _transferOwnership(_author);
    }

    function uri(uint256 id) public view override returns (string memory) {
        string memory custom = _tokenURIs[id];
        return bytes(custom).length > 0 ? custom : string(abi.encodePacked(baseUri, "/", _toString(id), ".json"));
    }

    function setTokenURI(uint256 id, string memory newUri) external onlyOwner {
        _tokenURIs[id] = newUri;
    }

    function mint(address to, uint256 id, uint256 amount) external onlyOwner {
        _mint(to, id, amount, "");
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts) external onlyOwner {
        _mintBatch(to, ids, amounts, "");
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
