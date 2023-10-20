// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function balanceOf(address _owner) external view returns (uint256 balance);

    function transfer(
        address _to,
        uint256 _value
    ) external returns (bool success);

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool success);

    function approve(
        address _spender,
        uint256 _value
    ) external returns (bool success);

    function allowance(
        address _owner,
        address _spender
    ) external view returns (uint256 remaining);

    function increaseAllowance(
        address _spender,
        uint256 _value
    ) external returns (bool);

    function decreaseAllowance(
        address _spender,
        uint256 _value
    ) external returns (bool);

    function burn(uint256 _value) external returns (bool);

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(
        address indexed _owner,
        address indexed _spender,
        uint256 _value
    );
    event Burn(address indexed _from, uint256 amount);
}

contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal pure virtual returns (bytes memory) {
        return msg.data;
    }

    function _getChainID() internal view virtual returns (uint256) {
        return block.chainid;
    }

    function _getBlockNumber() internal view virtual returns (uint256) {
        return block.number;
    }

    function _getBlockTimestamp() internal view virtual returns (uint256) {
        return block.timestamp;
    }
}

contract Token is IERC20, Context {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    error AllowanceTooLow(uint256 allowed);
    error AddressNotAllowed(address addr);
    error BalanceTooLow(uint256 balance, uint256 spending);

    uint256 private _totalSupply;
    string private _name;
    string private _symbol;

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 totalSupply_
    ) {
        _name = name_;
        _symbol = symbol_;
        _mint(msg.sender, totalSupply_ * 10 ** decimals());
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function decimals() public pure returns (uint8) {
        return 18;
    }

    function balanceOf(address _owner) public view returns (uint256) {
        return _balances[_owner];
    }

    function allowance(
        address _owner,
        address _spender
    ) public view returns (uint256) {
        return _allowances[_owner][_spender];
    }

    function _transfer(
        address _from,
        address _to,
        uint256 _value
    ) internal virtual {
        if (_to == address(0)) revert AddressNotAllowed({addr: _to});
        if (_from == address(0)) revert AddressNotAllowed({addr: _to});

        uint256 balance = balanceOf(_from);
        if (_value > balance) revert BalanceTooLow({balance: balance, spending: _value});
        
        _balances[_from] -= _value;
        _balances[_to] += _value;
        emit Transfer(_from, _to, _value);
    }

    function _burn(address _from, uint256 _value) internal virtual {
        uint256 balance = balanceOf(_from);
        if (_value > balance) revert BalanceTooLow({balance: balance, spending: _value});

        _balances[_from] -= _value;
        _totalSupply -= _value;
        emit Transfer(_from, address(0), _value);
        emit Burn(_from, _value);
    }

    function _mint(address _to, uint256 _value) internal virtual {
        if (_to == address(0)) revert AddressNotAllowed({addr: _to});
        _balances[_to] += _value;
        _totalSupply += _value;
        emit Transfer(address(0), _to, _value);
    }

    function burn(uint256 value) public returns (bool) {
        _burn(_msgSender(), value);
        return true;
    }

    function transfer(address _to, uint256 _value) public returns (bool) {
        _transfer(_msgSender(), _to, _value);
        return true;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) public returns (bool) {
        address _sender = _msgSender();
        uint256 _allowed = allowance(_from, _sender);
        if (_allowed < _value) revert AllowanceTooLow({allowed: _allowed});
        uint256 balance = balanceOf(_from);
        if (_value > balance) revert BalanceTooLow({balance: balance, spending: _value});
        _approve(_from, _sender, _allowed - _value);
        _transfer(_from, _to, _value);
        return true;
    }

    function _updateAllowance(
        address _owner,
        address _spender,
        uint256 _value
    ) private {
        _allowances[_owner][_spender] = _value;
    }

    function _approve(
        address _owner,
        address _spender,
        uint256 _value
    ) internal {
        require(_owner != address(0), "ERC20: approve from the zero address");
        require(_spender != address(0), "ERC20: approve to the zero address");

        _updateAllowance(_owner, _spender, _value);
        emit Approval(_owner, _spender, _value);
    }

    function approve(address _spender, uint256 _value) public returns (bool) {
        _updateAllowance(msg.sender, _spender, _value);
        return true;
    }

    function increaseAllowance(
        address _spender,
        uint256 _value
    ) public returns (bool) {
        address _sender = _msgSender();
        _approve(_sender, _spender, allowance(_sender, _spender) + _value);
        return true;
    }

    function decreaseAllowance(
        address _spender,
        uint256 _value
    ) public returns (bool) {
        address _sender = _msgSender();
        _approve(_sender, _spender, allowance(_sender, _spender) - _value);
        return true;
    }
}

contract CryeatorPanel {
    bool public taxStatus;
    address public taxWallet;
    uint256 public taxPercent;
    address public owner;

    mapping(address => bool) private _excludeTax;

    event AddedNoTaxWallet(address indexed addr);
    event RemoveNoTaxWallet(address indexed addr);
    event UpdatedTax(uint256 indexed percent);
    event ToggleTaxStatus(bool status);
    event UpdatedBurnTaxPercent(uint256 percent);

    error RoughPlayActionNotAllow();
    error TaxSettingIsTheSame();

    constructor() {
        owner = msg.sender;
        taxPercent = 5;
        taxStatus=true;
        setTaxWallet(owner);
        setTaxWallet(0x0E9b7CCA833F0E2AE7527b0d835022832E46218b);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "!owner");
        _;
    }

    function setTaxWallet(address _taxWallet) public onlyOwner {
        require(_taxWallet!=taxWallet, "tax wallet unchanged");
        taxWallet = _taxWallet;
        if (!_isTaxFree(_taxWallet)){addTaxFree(_taxWallet);}
    }

    function isTaxFree(address addr) public view returns (bool) {
        return _isTaxFree(addr);
    }

    function _isTaxFree(address addr) internal view returns (bool) {
        return _excludeTax[addr];
    }

    function addTaxFree(address addr) public onlyOwner {
        require(!_isTaxFree(addr));
        _excludeTax[addr] = true;
        emit AddedNoTaxWallet(addr);
    }

    function removeTaxFree(address addr) public onlyOwner {
        require(_isTaxFree(addr));
        _excludeTax[addr] = false;
        emit RemoveNoTaxWallet(addr);
    }

    function updateTax(uint256 percent) public onlyOwner {
        if (percent == taxPercent) revert TaxSettingIsTheSame();
        taxPercent = percent;
        emit UpdatedTax(percent);
    }

    function toggleTaxStatus() public onlyOwner {
        taxStatus = !taxStatus;
        emit ToggleTaxStatus(taxStatus);
    }
}

contract CryeatorToken is Token, CryeatorPanel {
    constructor() Token("Cryeator", "CR8", 8_000_000_000) {}

    function _transfer(
        address _from,
        address _to,
        uint256 _value
    ) internal override {
        require(_from != address(0) && _to != address(0), "Address unsupported" );
        
        if (!taxStatus || _value == 0 || taxWallet == address(0)) return super._transfer(_from, _to, _value);
        address _thisContract = address(this);
        if (_from == _thisContract || _to == _thisContract) return super._transfer(_from, _to, _value);
        if (_isTaxFree(_from) || _isTaxFree(_to)) return super._transfer(_from, _to, _value);

        require(balanceOf(_from) >= _value, "ERC20: balance too low");
        uint256 _taxAmount = (_value * taxPercent) / 100;
        _value = _value - _taxAmount;

        super._transfer(_from, taxWallet, _taxAmount);
        super._transfer(_from, _to, _value);
    }

    receive() external payable{}

    function removeToken(address token) public onlyOwner {
        if (token == address(0)) {
            payable(_msgSender()).transfer(address(this).balance);
            return;
        }
        if (token == address(this)) revert RoughPlayActionNotAllow();

        IERC20 erc20 = IERC20(token);
        erc20.transfer(_msgSender(), erc20.balanceOf(address(this)));
    }
}
