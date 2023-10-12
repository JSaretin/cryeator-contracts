// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    /// @param _owner The address from which the balance will be retrieved
    /// @return balance the balance
    function balanceOf(address _owner) external view returns (uint256 balance);

    /// @notice send `_value` token to `_to` from `msg.sender`
    /// @param _to The address of the recipient
    /// @param _value The amount of token to be transferred
    /// @return success Whether the transfer was successful or not
    function transfer(
        address _to,
        uint256 _value
    ) external returns (bool success);

    /// @notice send `_value` token to `_to` from `_from` on the condition it is approved by `_from`
    /// @param _from The address of the sender
    /// @param _to The address of the recipient
    /// @param _value The amount of token to be transferred
    /// @return success Whether the transfer was successful or not
    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool success);

    /// @notice `msg.sender` approves `_addr` to spend `_value` tokens
    /// @param _spender The address of the account able to transfer the tokens
    /// @param _value The amount of wei to be approved for transfer
    /// @return success Whether the approval was successful or not
    function approve(
        address _spender,
        uint256 _value
    ) external returns (bool success);

    /// @param _owner The address of the account owning tokens
    /// @param _spender The address of the account able to transfer the tokens
    /// @return remaining Amount of remaining tokens allowed to spent
    function allowance(
        address _owner,
        address _spender
    ) external view returns (uint256 remaining);

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(
        address indexed _owner,
        address indexed _spender,
        uint256 _value
    );

    event Burn(address indexed _from, uint256 amount);
}

contract CryeatorTax {
    bool public taxStatus;
    address public taxWallet;
    uint256 public taxPercent;
    uint256 public burnTaxPercent;
    address public owner;

    mapping(address => bool) private _taxFree;
    event AddedNoTaxWallet(address indexed addr);
    event RemoveNoTaxWallet(address indexed addr);
    event UpdatedTax(uint256 indexed percent);
    event ToggleTaxStatus(bool status);
    event UpdatedBurnTaxPercent(uint256 percent);

    constructor() {
        taxWallet = 0x906D5807fCd1c19FA8797a558c264c33cB29e7fD;
        owner = msg.sender;
        taxPercent = 6;
        burnTaxPercent = 20;
        addTaxFree(owner);
    }

    modifier onlyOwer() {
        require(msg.sender == owner, "!owner");
        _;
    }

    function isTaxFree(address addr) public view returns (bool) {
        return _taxFree[addr];
    }

    // add new team member wallet
    function addTaxFree(address addr) public onlyOwer {
        require(!isTaxFree(addr));
        _taxFree[addr] = true;
        emit AddedNoTaxWallet(addr);
    }

    // remove team wallet
    function removeTaxFree(address addr) public onlyOwer {
        require(isTaxFree(addr));
        _taxFree[addr] = false;
        emit RemoveNoTaxWallet(addr);
    }

    function updateBurnTaxPercent(uint256 percent) public onlyOwer {
        burnTaxPercent = percent;
        emit UpdatedBurnTaxPercent(percent);
    }

    function updateTax(uint256 percent) public onlyOwer {
        taxPercent = percent;
        emit UpdatedTax(percent);
    }

    function toggleTaxStatus() public onlyOwer {
        taxStatus = !taxStatus;
        emit ToggleTaxStatus(taxStatus);
    }
}

contract Cryeator is IERC20, CryeatorTax {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowed;

    uint256 public totalSupply;
    string public name = "Cryeator";
    uint8 public decimals = 18;
    string public symbol = "CRYT";

    constructor() {
        _mint(_msgSender(), 100000 * 10 ** decimals);
    }

    function _msgSender() private view returns (address) {
        return msg.sender;
    }

    function _mint(address _to, uint256 _value) private {
        _balances[_to] += _value;
        totalSupply += _value;
        emit Transfer(address(0), _to, _value);
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        return _balances[_owner];
    }

    function _burn(address _from, uint256 _value) internal {
        require(balanceOf(_from) >= _value, "ERC20: balance too low");
        _balances[_from] -= _value;
        totalSupply -= _value;
        emit Transfer(_from, address(0), _value);
        emit Burn(_from, _value);
    }

    function _payTax(address _from, uint256 _value) private {
        // remove and burn X percent from the collected tax
        uint256 _burnAmount = (_value * burnTaxPercent) / 100;
        _value -= _burnAmount;
        _burn(_from, _burnAmount);
        _balances[_from] = balanceOf(_from) - _value;
        _balances[taxWallet] = balanceOf(taxWallet) + _value;
        emit Transfer(_from, taxWallet, _value);
    }

    function _transfer(address _from, address _to, uint256 _value) internal {
        require(
            _from != address(0) && _to != address(0),
            "Address unsupported"
        );
        require(balanceOf(_from) >= _value, "ERC20: balance too low");

        if (
            _value > 0 &&
            (_from != address(this) && address(this) != _to) &&
            (taxStatus && !isTaxFree(_from) && !isTaxFree(_to))
        ) {
            uint256 taxAmount = (_value * taxPercent) / 100;
            _value -= taxAmount;
            _payTax(_from, taxAmount);
        }

        _balances[_to] += _value;
        _balances[_from] -= _value;
        emit Transfer(_from, _to, _value);
    }

    function burn(uint256 value) public {
        _burn(_msgSender(), value);
    }

    function transfer(
        address _to,
        uint256 _value
    ) public returns (bool success) {
        _transfer(_msgSender(), _to, _value);
        return true;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) public returns (bool success) {
        address sender = _msgSender();
        uint256 canSpend = allowance(_from, sender);
        require(canSpend >= _value, "ERC20: allowance too low");

        // update allowance
        _allowed[_from][sender] -= _value;
        // make transfer
        _transfer(_from, _to, _value);
        return true;
    }

    function approve(
        address _spender,
        uint256 _value
    ) public returns (bool success) {
        address _sender = _msgSender();
        _allowed[_sender][_spender] = _value;
        emit Approval(_sender, _spender, _value);
        return true;
    }

    function allowance(
        address _owner,
        address _spender
    ) public view returns (uint256 remaining) {
        return _allowed[_owner][_spender];
    }
}
