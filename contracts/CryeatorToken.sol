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

contract Token is IERC20 {
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
        _burn(msg.sender, value);
        return true;
    }

    function transfer(address _to, uint256 _value) public returns (bool) {
        _transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) public returns (bool) {
        uint256 _allowed = allowance(_from, msg.sender);
        if (_allowed < _value) revert AllowanceTooLow({allowed: _allowed});
        uint256 balance = balanceOf(_from);
        if (_value > balance) revert BalanceTooLow({balance: balance, spending: _value});
        _approve(_from, msg.sender, _allowed - _value);
        _transfer(_from, _to, _value);
        return true;
    }

    function _updateAllowance(
        address _owner,
        address _spender,
        uint256 _value
    ) internal {
        _allowances[_owner][_spender] = _value;
    }

    function _approve(
        address _owner,
        address _spender,
        uint256 _value
    ) internal {
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
        _updateAllowance(msg.sender, _spender, allowance(msg.sender, _spender) + _value);
        return true;
    }

    function decreaseAllowance(
        address _spender,
        uint256 _value
    ) public returns (bool) {
        _updateAllowance(msg.sender, _spender, allowance(msg.sender, _spender) - _value);
        return true;
    }
}

contract CryeatorTax {
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
    error TaxIsToHigh(uint256 maxTax, uint256 tax);
    error TaxSettingIsTheSame();

    constructor() {
        taxWallet = 0x906D5807fCd1c19FA8797a558c264c33cB29e7fD;
        owner = msg.sender;
        taxPercent = 6;
        addTaxFree(owner);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "!owner");
        _;
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
        if (percent > 10) revert TaxIsToHigh({maxTax: 10, tax: percent});
        if (percent == taxPercent) revert TaxSettingIsTheSame();
        taxPercent = percent;
        emit UpdatedTax(percent);
    }

    function toggleTaxStatus() public onlyOwner {
        taxStatus = !taxStatus;
        emit ToggleTaxStatus(taxStatus);
    }
}

contract CryeatorToken is Token, CryeatorTax {
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

        super._transfer(_from, address(this), _taxAmount);
        super._transfer(_from, _to, _value - _taxAmount);
    }

    function removeToken(address token) public onlyOwner {
        if (token != address(0)) {
            payable(msg.sender).transfer(address(this).balance);
            return;
        }
        if (token != address(this)) revert RoughPlayActionNotAllow();

        IERC20 erc20 = IERC20(token);

        erc20.transfer(msg.sender, erc20.balanceOf(address(this)));
    }
}
