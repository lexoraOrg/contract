// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BookToken is ERC20Permit, Ownable {
    constructor(uint256 initialSupply, address initialOwner)
        ERC20("BookToken", "BKT")
        ERC20Permit("BookToken")
        Ownable(initialOwner)
    {
        _mint(initialOwner, initialSupply);
    }
}

contract CreatorContractFactory is Ownable {
    constructor(address _usdt, address initialOwner) Ownable(initialOwner) {
        usdt = IERC20Metadata(_usdt);
    }

    IERC20Metadata public immutable usdt;
    uint256 public immutable serviceFee = 200 * 1e6; // 200 USDT with 6 decimals
    uint256 public projectCounter;

    struct PendingCreator {
        address token;
        BookToken tokenContract;
        uint256 price;
    }

    mapping(address => PendingCreator) public pending;
    mapping(uint256 => address) public projectIndex;

    event Deployed(
        address indexed creator,
        address bookToken,
        address staking,
        uint256 indexed projectId
    );
    event PaidAndClaimed(address indexed creator);

    function deployForCreator(
        address creator,
        uint256 initialSupply,
        address readerPurchase
    ) external onlyOwner {
        BookToken token = new BookToken(initialSupply, address(this));
        BookTokenStaking staking = new BookTokenStaking(
            address(token),
            address(usdt),
            readerPurchase
        );

        pending[creator] = PendingCreator(address(token), token, serviceFee);

        uint256 projectId = ++projectCounter;
        projectIndex[projectId] = creator;

        emit Deployed(creator, address(token), address(staking), projectId);
    }

    function payAndClaimOwnership() external {
        PendingCreator memory p = pending[msg.sender];
        require(p.token != address(0), "No pending token");

        require(
            usdt.transferFrom(msg.sender, address(this), p.price),
            "USDT payment failed"
        );

        p.tokenContract.transferOwnership(msg.sender);
        delete pending[msg.sender];

        emit PaidAndClaimed(msg.sender);
    }
}

contract BookTokenStaking {
    IERC20Metadata public immutable bookToken;
    IERC20Metadata public immutable usdt;
    address public immutable readerPurchase; // authorized source

    uint256 public totalStaked;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public userStaked;
    mapping(address => uint256) public userPaid;
    mapping(address => uint256) public rewards;

    constructor(
        address _bookToken,
        address _usdt,
        address _readerPurchase
    ) {
        bookToken = IERC20Metadata(_bookToken);
        usdt = IERC20Metadata(_usdt);
        readerPurchase = _readerPurchase;
    }

    modifier onlyAuthorized() {
        require(msg.sender == readerPurchase, "Not authorized");
        _;
    }

    function distribute(uint256 usdtAmount) external onlyAuthorized {
        require(totalStaked > 0, "No stakers");
        require(
            usdt.transferFrom(msg.sender, address(this), usdtAmount),
            "Transfer failed"
        );
        rewardPerTokenStored += (usdtAmount * 1e18) / totalStaked;
    }

    function earned(address user) public view returns (uint256) {
        return
            (userStaked[user] * (rewardPerTokenStored - userPaid[user])) / 1e18;
    }

    function updateReward(address user) internal {
        rewards[user] += earned(user);
        userPaid[user] = rewardPerTokenStored;
    }

    function stake(uint256 amount) public {
        require(amount > 0, "Zero stake");
        updateReward(msg.sender);
        require(
            bookToken.transferFrom(msg.sender, address(this), amount),
            "Token transfer failed"
        );
        userStaked[msg.sender] += amount;
        totalStaked += amount;
    }

    function stakeWithPermit(
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        ERC20Permit(address(bookToken)).permit(
            msg.sender,
            address(this),
            amount,
            deadline,
            v,
            r,
            s
        );
        stake(amount);
    }

    function unstake(uint256 amount) external {
        require(
            amount > 0 && userStaked[msg.sender] >= amount,
            "Invalid unstake"
        );
        updateReward(msg.sender);
        userStaked[msg.sender] -= amount;
        totalStaked -= amount;
        require(
            bookToken.transfer(msg.sender, amount),
            "Token transfer failed"
        );
    }

    function claim() external {
        updateReward(msg.sender);
        uint256 reward = rewards[msg.sender];
        require(reward > 0, "Nothing to claim");
        rewards[msg.sender] = 0;
        require(usdt.transfer(msg.sender, reward), "USDT transfer failed");
    }
}
