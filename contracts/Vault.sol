// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract  Vault is IERC4626,ERC20,Ownable{
    IERC20 public immutable asset;
    address internal Positions;
    uint internal  totalAssetsLocked;
    uint public maxUtilityPercentage;
    constructor(IERC20 _asset,
    string memory _name,
    string memory _symbol,uint _maxUtilityPercentage) ERC20(_name,_symbol) {
        asset=_asset;
        maxUtilityPercentage=_maxUtilityPercentage;
    }
    modifier validAddress(address receiver){
        require(receiver != address(0));
        _;
    }
    function deposit(uint256 assets,address receiver) external  returns(uint shares){
        uint shares= previewDeposit(assets);
        _deposit(msg.sender,receiver,shares,assets);
        return shares;
        }
    function _deposit(address sender,address reciever, uint shares,uint assets) internal ValidAddress(receiver) {
        asset.TransferFrom(sender,address(this),assets);
        totalAssetsLocked+=assets;
        _mint(reciever,shares);
         emit Deposit(msg.sender,receiver,assets,shares); 
    }
        function mint(uint shares,address receiver) external  returns (uint256 assets) {
        uint _assets= previewMint(shares);
        _deposit(msg.sender,receiver,_owner,shares_assets);
        return _assets;
    }
    function withdraw(uint256 assets,address receiver,address _owner) external  returns(uint256 shares){
        uint shares=previewWithdraw(assets);
        _withdraw(msg.sender,receiver,shares,assets);
        return shares;
    }
    function redeem(uint256 shares, address receiver, address _owner) external returns (uint256 assets){
            uint _assets= previewRedeem(shares);
            _withdraw(msg.sender,reciever,_owner,shares,_assets);
            return _assets;
        }
    function _withdraw(address caller, address receiver,address _owner,uint shares,uint assets) internal ValidAddress(receiver) returns(uint shares){
        if(caller != _owner){
            _spendeAllownace(_owner,caller,shares);
        }
        _burn(_owner,shares);
        asset.transfer(address(this),receiver,assets);
        totalAssetsLocked-=assets;
        emit Withdraw(caller,receiver,_owner,assets,shares);
        _checkWithdraw();
        return shares;
    }
    function asset() public view  returns(address){
        return address(asset);
    }
    function totalAssets() public view returns(uint256){
      return address(this).balance;
    
    }
    function convertToShares(uint256 Assets) public view returns(uint256){
        return _convertToShares(Assets,0);
    }
    function convertToAssets(uint256 shares) public view returns(uint256){
        return _convertToAssets(shares,0);

    }
    function maxDeposit(address receiver) public view returns (uint256){
        return type(uint256).max;
    }
    function maxMint(address receiver) external view returns(uint256){
        return type(uint256).max;
    }
    function maxWithdraw(address _owner) external view returns (uint256 maxAssets){
        return _covertToShares(balanceOf(_owner),0);
    }
    function maxRedeem(address _owner) external view returns(uint256 maxShares){
        return balanceOf(_owner);
    }
    function previewDeposit(uint _asset) public view returns(uint){
        _convertToShares(_assets,0);
    }
    function previewMint(uint shares) public view returns(uint){
        _convertToAssets(shares,1);

    }
    function previewWithdraw(uint assets) public view returns(uint){
        _convertToShares(Assets,0);
    }
    function previewRedeem(uint shares) public view returns(uint){
        _convertToAssets(shares,1);     
    }

    function _convertToShare(uint assets,uint8 rounding) internal returns(uint){
        uint prod=assets*totalSupply();
        uint bal= totalAssets();
        if(rounding == 0){
            if(prod % bal >0) return (prod/bal)+1;
            return prod/bal;
        }
        return prod/bal+1;
    }
    function _convertToAssets(uint shares,uint8 rounding ) internal returns(uint){
         uint prod=shares*totalAssets();
        if(rounding == 0){
            if(prod % totalSupply() >0) return (prod/totalSupply())+1;
            return prod/totalSupply();
        }
        return prod/totalSupply()+1;
    }
    function set_Position(address _Positions) external onlyOwner {
        Positions = _Positions;
        approve(Positons,type(uint256).max);
    }
    function totalAvailableLiquidity() external view returns(uint){
        return (totalAssetsLocked * maxUtilityPercentage)/100;
    }
    function _checkWithdraw() internal view returns(bool){
        (,bytes memory data)=Positions.call(abi.encodeWithSelector("totalOpenIntrest()"));
        uint totalOpenIntrest= (abi.decode(data,(uint)))/1e16;
        require(((totalAssetsLocked * maxUtilityPercentage)/100) > totalOpenIntrest );
    }
}