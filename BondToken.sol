// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";

library SafeMath {
    /**
     * @dev Multiplies two numbers, throws on overflow.
     */
    function mul(uint256 _a, uint256 _b) internal pure returns (uint256 c) {
        // Gas optimization: this is cheaper than asserting 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (_a == 0) {
            return 0;
        }

        c = _a * _b;
        assert(c / _a == _b);
        return c;
    }

    /**
     * @dev Integer division of two numbers, truncating the quotient.
     */
    function div(uint256 _a, uint256 _b) internal pure returns (uint256) {
        // assert(_b > 0); // Solidity automatically throws when dividing by 0
        // uint256 c = _a / _b;
        // assert(_a == _b * c + _a % _b); // There is no case in which this doesn't hold
        return _a / _b;
    }

    /**
     * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
     */
    function sub(uint256 _a, uint256 _b) internal pure returns (uint256) {
        assert(_b <= _a);
        return _a - _b;
    }

    /**
     * @dev Adds two numbers, throws on overflow.
     */
    function add(uint256 _a, uint256 _b) internal pure returns (uint256 c) {
        c = _a + _b;
        assert(c >= _a);
        return c;
    }
}

contract ERC20Token is Context, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    string private _name;
    string private _symbol;
    uint8 private _decimals;
    uint256 private _totalSupply;
    string public ISIN = "_ISIN";
    string public CUSIP = "_CUSIP";
    string public moodys = "_moodys";
    string public sp = "_sp";
    string public fitch = "_fitch";
    uint256 public maturityTime = 12345;
    uint256 public faceValue = 108;
    uint256 public amountOutstanding = 50000;
    uint256 public rate = 9;
    uint256 public minimum = 1000;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    IERC20 token;

    constructor(string memory name_, 
                string memory symbol_, 
                uint8 decimals_, 
                uint256 totalSupply_,
                IERC20 token_) {
        require(
            address(token_) != address(0),
            "Token Address cannot be address 0"
        );
        token = token_;
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        _totalSupply = totalSupply_;
        _balances[msg.sender] = totalSupply_;
        emit Transfer(address(0), msg.sender, totalSupply_);
    }

    struct Investor {
        address investorAddress;
        uint256 investedAmount;
        uint256 redemptionAmount;
        bool redeemed;
        bool exists;
    }

    mapping(address => Investor) public investors;
    mapping(address => bool) public addressInvested;
    address[] public investmentHolders;

    function transferToken(address to, uint256 amount) external onlyOwner {
        require(token.transfer(to, amount), "Token transfer failed!");
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender] - amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] - subtractedValue);
        return true;
    }

    function mint(address account, uint256 amount) public returns (bool) {
        require(account != address(0), "ERC20: mint to the zero address");
        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
        return true;
    }

    function burn(uint256 amount) public returns (bool) {
        require(_balances[msg.sender] >= amount, "ERC20: burn amount exceeds balance");
        _balances[msg.sender] -= amount;
        _totalSupply -= amount;
        emit Transfer(msg.sender, address(0), amount);
        return true;
    }

    function destroyToken() public {
        require(msg.sender == address(this), "ERC20: destroyToken can only be called by the token contract itself");
        selfdestruct(payable(msg.sender));
    }

    function _transfer(address sender, address recipient, uint256 amount) private {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(_balances[sender] >= amount, "ERC20: insufficient balance");

        _balances[sender] -= amount;
        _balances[recipient] += amount;
        emit Transfer(sender, recipient, amount);
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function getAllInvestors() public view returns (address[] memory) {
        return investmentHolders;
    }

    function invest(uint256 amount_) external {
        require(maturityTime >= block.timestamp, "Bond has maturated, can't invest now");
        require(amount_ >= minimum, "FXD: invalid amount");
        Investor memory investor = investors[_msgSender()];

        if(investor.exists == false) {
            investor.exists = true;
            investor.investorAddress = _msgSender();
            investmentHolders.push(_msgSender());
            investor.investedAmount = 0;
        }

        uint256 investmentAmount = amount_.sub((rate/100)*amount_);
        uint256 bondAmount = amount_ / faceValue;
        investor.investedAmount = investor.investedAmount.add(investmentAmount);
        investor.redemptionAmount = investor.redemptionAmount.add(bondAmount);

        investors[_msgSender()] = investor;
        
        token.safeTransferFrom(_msgSender(), address(this), investmentAmount);

        emit Invested(_msgSender(), investmentAmount, bondAmount);
    }

    function redeemInvestment() external {
        require(maturityTime >= block.timestamp, "BondToken hasn't maturated yet");
        Investor memory investor = investors[_msgSender()];
        (bool exists, uint256 investorIndex) = getInvestorIndex(_msgSender());
        require(exists, "Investor does not exist");
        require(investor.redeemed == false, "Investment already redeemed.");
        investor.redeemed = true;
        investors[_msgSender()] = investor;
        investmentHolders[investorIndex] = investmentHolders[investmentHolders.length - 1];
        delete investmentHolders[investmentHolders.length - 1];
        investmentHolders.pop();

        emit InvestmentRedeemed(_msgSender(), investor.redemptionAmount);
    }

    function getInvestorIndex(
        address investor
    ) public view returns (bool, uint256) {
        for (uint256 i = 0; i < investmentHolders.length; i++) {
            if (investmentHolders[i] == investor) return (true, i);
        }
        return (false, 0);
    }

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Invested(address investor, uint256 investedAmount, uint256 bondAmount);
    event InvestmentRedeemed(address investor, uint256 redeeemedAmount);
    event maturityTimeChanged(uint256 prevValue, uint256 newValue);
    event faceValueChanged(uint256 prevValue, uint256 newValue);
    event amountOutstandingChanged(uint256 prevValue, uint256 newValue);
    event rateChanged(uint256 prevValue, uint256 newValue);
    event minimumChanged(uint256 prevValue, uint256 newValue);

    function setMaturityTime(uint256 maturityTime_) public onlyOwner {
        uint256 prevValue = maturityTime;
        maturityTime = maturityTime_;
        emit maturityTimeChanged(prevValue, maturityTime);
    }

    function setAmountOutstanding(uint256 amountOutstanding_) public onlyOwner {
        uint256 prevValue = amountOutstanding;
        amountOutstanding = amountOutstanding_;
        emit amountOutstandingChanged(prevValue, amountOutstanding);
    }

    function setRate(uint256 rate_) public onlyOwner {
        uint256 prevValue = rate;
        rate = rate_;
        emit rateChanged(prevValue, rate);
    }

    function setMinimum(uint256 minimum_) public onlyOwner {
        uint256 prevValue = minimum;
        minimum = minimum_;
        emit minimumChanged(prevValue, minimum);
    }
}
