// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IAuthorBook1155 {
    function balanceOf(address account, uint256 id) external view returns (uint256);

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;

    function owner() external view returns (address);
}

interface IBookTokenERC20Wrapper {
    function initialize(
        address book1155,
        uint256 bookId,
        string memory name,
        string memory symbol
    ) external;
}

contract BookTokenERC20Wrapper is Context, IERC20, IERC20Metadata, IERC20Permit {
    IAuthorBook1155 public book1155;
    uint256 public bookId;

    string private _name;
    string private _symbol;
    bool private initialized;

    mapping(address => mapping(address => uint256)) private _allowances;

    bytes32 public immutable DOMAIN_SEPARATOR;
    mapping(address => uint256) public nonces;

    event Initialized(address indexed wrapper, address indexed book1155, uint256 indexed bookId);

    constructor() {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("BookTokenERC20Wrapper")),
                keccak256(bytes("1")),
                chainId,
                address(this)
            )
        );
    }

    function initialize(
        address _book1155,
        uint256 _bookId,
        string memory name_,
        string memory symbol_
    ) external {
        require(!initialized, "Already initialized");
        initialized = true;

        book1155 = IAuthorBook1155(_book1155);
        bookId = _bookId;
        _name = name_;
        _symbol = symbol_;

        emit Initialized(address(this), _book1155, _bookId);
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    function totalSupply() public view override returns (uint256) {
        return book1155.balanceOf(address(this), bookId);
    }

    function balanceOf(address account) public view override returns (uint256) {
        return book1155.balanceOf(account, bookId);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        book1155.safeTransferFrom(_msgSender(), recipient, bookId, amount, "");
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _allowances[_msgSender()][spender] = amount;
        emit Approval(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            _allowances[sender][_msgSender()] = currentAllowance - amount;
        }
        book1155.safeTransferFrom(sender, recipient, bookId, amount, "");
        emit Approval(sender, _msgSender(), _allowances[sender][_msgSender()]);
        return true;
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {
        require(block.timestamp <= deadline, "Permit expired");

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        owner,
                        spender,
                        value,
                        nonces[owner]++,
                        deadline
                    )
                )
            )
        );

        address recovered = ecrecover(digest, v, r, s);
        require(recovered != address(0) && recovered == owner, "Invalid signature");

        _allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }
}
