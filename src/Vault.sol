// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IPosition{
    function setLiquidatorFeePercentage(uint8 _percentage) external returns(bool);
    function openLongPosition(uint _size,uint _collateral) external returns(uint);
    function increasePositionSize(uint _id,uint _size) external returns(bool);
    function increasePositionCollateral(uint _id,uint _collateral) external  returns(bool);
    function openShortPosition(uint _size,uint _collateral) external  returns(uint);
    function decreaseSize(uint _id,uint _size) external returns(bool);
    function decreaseCollateral(uint _id,uint _collateral) external returns(bool);
    function totalOpenIntrest() external view returns(uint);
    function liquidate(uint _id) external returns(bool);   
}
contract Vault is IERC4626, ERC20, Ownable {
    IERC20  immutable _Asset;
    address internal Positions;
    uint public maxUtilityPercentage;

    constructor(
        IERC20 _asset,
        string memory _name,
        string memory _symbol,
        uint _maxUtilityPercentage
    ) ERC20(_name, _symbol) Ownable(msg.sender){
        _Asset = _asset;
        maxUtilityPercentage = _maxUtilityPercentage;
    }

    modifier ValidAddress(address receiver) {
        require(receiver != address(0));
        _;
    }

    function deposit(
        uint256 assets,
        address receiver
    ) external returns (uint) {
        uint _shares = previewDeposit(assets);
        _deposit(msg.sender, receiver, _shares, assets);
        return _shares;
    }

    function _deposit(
        address sender,
        address reciever,
        uint shares,
        uint assets
    ) internal ValidAddress(reciever) {
        _Asset.transferFrom(sender, address(this), assets);
        _mint(reciever, shares);
        emit Deposit(msg.sender, reciever, assets, shares);
    }

    function mint(
        uint shares,
        address receiver
    ) external returns (uint256) {
        uint _assets = previewMint(shares);
        _deposit(msg.sender, receiver, shares,_assets);
        return _assets;
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address _owner
    ) external returns (uint256) {
        uint shares = previewWithdraw(assets);
        _withdraw(msg.sender, receiver,_owner, shares, assets);
        return shares;
    }

    function redeem(
        uint256 shares,
        address reciever,
        address _owner
    ) external returns (uint256) {
        uint _assets = previewRedeem(shares);
        _withdraw(msg.sender, reciever, _owner, shares, _assets);
        return _assets;
    }

    function _withdraw(
        address caller,
        address receiver,
        address _owner,
        uint shares,
        uint assets
    ) internal ValidAddress(receiver) returns (uint) {
        if (caller != _owner) {
            _spendAllowance(_owner, caller, shares);
        }
        _burn(_owner, shares);
        _Asset.transfer(receiver, assets);
        emit Withdraw(caller, receiver, _owner, assets, shares);
        _checkWithdraw();
        return shares;
    }

    function asset() public view returns (address) {
        return address(_Asset);
    }

    function totalAssets() public view returns (uint256) {
        return _Asset.balanceOf(address(this));
    }

    function convertToShares(uint256 Assets) public view returns (uint256) {
        return _convertToShares(Assets, 0);
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        return _convertToAssets(shares, 0);
    }

    function maxDeposit(address receiver) public view returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address receiver) external view returns (uint256) {
        return type(uint256).max;
    }

    function maxWithdraw(
        address _owner
    ) external view returns (uint256 ) {
        return _convertToShares(balanceOf(_owner), 0);
    }

    function maxRedeem(
        address _owner
    ) external view returns (uint256) {
        return balanceOf(_owner);
    }

    function previewDeposit(uint _asset) public view returns (uint) {
        return _convertToShares(_asset, 0);
    }

    function previewMint(uint shares) public view returns (uint) {
       return  _convertToAssets(shares, 1);
    }

    function previewWithdraw(uint assets) public view returns (uint) {
       return  _convertToShares(assets, 0);
    }

    function previewRedeem(uint shares) public view returns (uint) {
       return _convertToAssets(shares, 1);
    }

    function _convertToShares(
        uint assets,
        uint8 rounding
    ) internal view returns (uint) {
        uint prod = assets * totalSupply();
        uint bal = totalAssets();
        if (prod == 0) {
            return assets * 1e8;
        }
        if (prod % bal > 0) return (prod / bal) + 1;
        return prod / bal;
    }

    function _convertToAssets(
        uint shares,
        uint8 rounding
    ) internal view returns (uint) {
        uint prod = (shares * totalAssets());
        if (prod % totalSupply() > 0) return (prod / totalSupply()) + 1;
        return prod / totalSupply();
        
    }

    function set_Position(address _Positions) external onlyOwner {
        Positions = _Positions;
        approve(Positions, type(uint256).max);
    }

    function totalAvailableLiquidity() external view returns (uint) {
        return (totalAssets()* maxUtilityPercentage) / 100;
    }

    function _checkWithdraw() public returns (bool) {
        uint totalOpenIntrest = 0;
        totalOpenIntrest=IPosition(Positions).totalOpenIntrest();
        uint _totalAssets=totalAssets();
        require(
            ((_totalAssets * maxUtilityPercentage) / 100) >=
                totalOpenIntrest
         ,"insufficent funds to withdraw");
        return true;
    }
}
