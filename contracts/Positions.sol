// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;
import "./AggregatorV3Interface.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
contract Positions {
    AggregatorV3Interface public dataFeed;
    uint private maxLeverage;
    uint internal Pos;
    uint internal shortOpenings;
    uint internal longOpenings;
    uint internal shortOpenIntrest;
    uint internal shortOpenIntrestInTokens;
    uint internal longOpenIntrest;
    uint internal longOpenIntrestInTokens;
    uint8 internal maxUtilizationPercentage;
    address public Vault;
    IERC20 public AssetUnderCollateral;
    enum Position_type{long,short}
    struct Position{
        Position_type pos_type;
        address owner;
        uint size;
        uint collateral;
        uint BTCPrice;
        uint bal;
    }
    mapping(uint => Position) _Positions;
    constructor(address _dataFeed,uint _maxLeverge,address _Vault,address _AssetUnderCollateral,uint8 _maxUtilizationPercentage){
        dataFeed=AggregatorV3Interface(_dataFeed);
        maxLeverage=_maxLeverge;
        Vault=_Vault;
        AssetUnderCollateral=IERC20(_AssetUnderCollateral);
        maxUtilizationPercentage=_maxUtilizationPercentage;
    }
    modifier checkLiquidityAvailability(){
        _;
        _checkLiquidityAvailability();
    }
    function openLongPosition(uint _size,uint _collateral) external checkLiquidityAvailability() returns(uint){
        require(_size/_collateral<=maxLeverage);
        Position memory _pos= Position({
            pos_type:Position_type.long,
            owner:msg.sender,
            size:_size,
            collateral:_collateral,
            BTCPrice:getBTCPrice(),
            bal:getBTC(_size)
        });
        _Positions[Pos]=_pos;
        longOpenIntrest+=(_size*1e16);
        longOpenIntrestInTokens+=_pos.bal;
        AssetUnderCollateral.transferFrom(msg.sender,address(this),_collateral);
        longOpenings++;
        return Pos++;
    }
    function increaseSize(uint _id,uint _size) external returns(bool){
        Position memory _position =_Positions[_id];
        if(_position.pos_type == Position_type.long){
             return increaseLongPositionSize(_position,_size,_id);
        }
        else{
            return increaseShortPositionSize(_position,_size,_id);
        }
    }
    function increaseCollateral(uint _id,uint _collateral) external returns(bool){
        Position memory _position = _Positions[_id];
        if(_position.pos_type == Position_type.long){
             return increaseLongPositionCollateral(_position, _collateral,_id);
        }
        else{
            return increaseShortPositionCollateral( _position, _collateral,_id);
        }
    }
    function increaseLongPositionSize(Position memory _pos,uint _size,uint _id) internal checkLiquidityAvailability() returns(bool){
       require(msg.sender == _pos.owner,"only the owner call the function");
       require(_pos.size<_size,"new size should be greater than the older amount");
       longOpenIntrestInTokens-=_pos.bal;
        longOpenIntrest-= (_pos.bal * _pos.BTCPrice);
         _pos.size=_size ;
       _pos.bal=((_pos.size*1e16) / _pos.BTCPrice);
       longOpenIntrest+= (_pos.bal * _pos.BTCPrice);
        longOpenIntrestInTokens+=(_size/_pos.BTCPrice);
        _Positions[_id]=_pos;
        _getLeverage(_pos);
        return true;
    }
    function increaseLongPositionCollateral(Position memory _pos,uint _collateral,uint _id) internal checkLiquidityAvailability() returns(bool){
        require(msg.sender == _pos.owner,"only the owner can call the function");
        require(_pos.collateral < _collateral,"new collateral should be greater than the older one");
        _pos.collateral=_collateral;
        AssetUnderCollateral.transferFrom(msg.sender,address(this),(_collateral-_pos.collateral));
        _Positions[_id]=_pos;
        _getLeverage(_pos);
        return true;
    }
    function openShortPosition(uint _size,uint _collateral) external checkLiquidityAvailability() returns(uint){
        require(_size/_collateral<=maxLeverage);
        Position memory _pos= Position({
            pos_type:Position_type.short,
            owner:msg.sender,
            size:_size,
            collateral:_collateral,
            BTCPrice:getBTCPrice(),
            bal:getBTC(_size)
        });
        _Positions[Pos]=_pos;
        shortOpenIntrest+=_size*1e16;
        shortOpenIntrestInTokens+=_pos.bal;
        AssetUnderCollateral.transferFrom(msg.sender,Vault,_collateral);
        _checkLiquidityAvailability();
        shortOpenings++;
        return Pos++    ;
    }
    function increaseShortPositionSize(Position memory _pos,uint _size,uint _id) internal checkLiquidityAvailability() returns(bool){
        require(_pos.owner==msg.sender && _pos.size<=_size,"invalid");
        _pos.size=_size;
        shortOpenIntrestInTokens-=_pos.bal;
        shortOpenIntrest-=(_pos.bal * _pos.BTCPrice);
        _pos.bal= (_size * 1e16 /_pos.BTCPrice);
        shortOpenIntrestInTokens+=_pos.bal;
        shortOpenIntrest+=(_pos.bal * _pos.BTCPrice);
        _Positions[_id]=_pos;
        _getLeverage(_pos);
        return true;
    }
    function increaseShortPositionCollateral(Position memory _pos,uint _collateral , uint _id) internal checkLiquidityAvailability() returns(bool){
        require(msg.sender == _pos.owner,"only the owner can call the function");
        require(_pos.collateral < _collateral,"new collateral should be greater than the older one");
        _pos.collateral=_collateral;
        AssetUnderCollateral.transferFrom(msg.sender,address(this),(_collateral-_pos.collateral));
        _Positions[_id]=_pos;
        _getLeverage(_pos);
        return true;
    }
   
    function getBTC(uint amount) public view returns(uint){
        uint price=getBTCPrice();
        return (amount*1e16 / price);
    }
    function _checkLiquidityAvailability() internal returns(bool){
        require(totalOpenIntrest() < getLiquidityAvailable(),"not enough liquidity");
        return true;
    }
    function getLiquidityAvailable() internal returns(uint){
        (,bytes memory data)= Vault.call(abi.encodeWithSignature("totalAvailableLiquidity()"));
        uint liquidity=abi.decode(data,(uint256));
        return liquidity*1e16;
    }
    function totalOpenIntrest() public view returns(uint){
        return ((shortOpenIntrest) + (longOpenIntrestInTokens * getBTCPrice())); 
    }
    function getBTCPrice() internal view returns(uint256){
        (,int answer,,,)= dataFeed.latestRoundData();
        return uint(answer);
    }
    function _getLeverage(Position memory _pos) internal view returns(bool){
        uint latestBTCPrice=getBTCPrice();
        uint latestCollateral;
        if(_pos.pos_type==Position_type.long){
            if(latestBTCPrice < _pos.BTCPrice){
                latestCollateral=_pos.collateral -(((_pos.bal * _pos.BTCPrice)-(_pos.bal * latestBTCPrice))/1e16); 
                require(_pos.size/latestCollateral < maxLeverage,"Leverage limit crossed");
            }
        }
        else{
            if(_pos.BTCPrice < latestBTCPrice){
                latestCollateral=_pos.collateral -(((_pos.bal * latestBTCPrice)-(_pos.bal * _pos.BTCPrice))/1e16);
                require(_pos.size/latestCollateral < maxLeverage,"Leverage limit crossed");
            }
        }
        return true;
    }

}
