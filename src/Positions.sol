// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;
import "./AggregatorV3interface.sol";
import "lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
contract Positions {
    struct Position{
        Position_type pos_type;
        address owner;
        uint size;
        uint collateral;
        uint BTCPrice;
        uint bal;
        uint timeStamp;
        bool isOpen;
    }
    struct totalPositionSummary{
        uint openings;
        uint openIntrest;
        uint openIntrestInTokens;
    }
    enum Position_type{long,short}
    totalPositionSummary internal Long;
    totalPositionSummary internal Short;
    AggregatorV3Interface public dataFeed;
    uint private maxLeverage;
    uint internal Pos;
    uint8 internal maxUtilizationPercentage;
    uint8 internal liquidatorFeePercentage;
    uint80 internal constant  borrowerFeePerSharePerSecond = 31709792;
    address public Vault;
    address public Keeper;
    IERC20 public AssetUnderCollateral;
    mapping(uint => Position) _Positions;
    constructor(address _dataFeed,uint _maxLeverge,address _Vault,address _AssetUnderCollateral,uint8 _maxUtilizationPercentage){
        Keeper =msg.sender;
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
    modifier isopen(Position memory _pos){
        require(_pos.isOpen,"Position is closed");
        _;
    }
    modifier isOwner(Position memory _pos){
        require(msg.sender == _pos.owner,"only owner can call this function");
        _;
    }
    function setLiquidatorFeePercentage(uint8 _percentage) external returns(bool){
        require(msg.sender == Keeper);
        liquidatorFeePercentage=_percentage;
        return true;
    }
    function openLongPosition(uint _size,uint _collateral) external checkLiquidityAvailability() returns(uint){
        require(_size/_collateral<=maxLeverage);
        Position memory _pos= Position({
            pos_type:Position_type.long,
            owner:msg.sender,
            size:_size,
            collateral:_collateral,
            BTCPrice:getBTCPrice(),
            bal:getBTC(_size),
            timeStamp:block.timestamp,
            isOpen:true
        });
        _Positions[Pos]=_pos;
        Long.openIntrest+=(_size*1e16);
        Long.openIntrestInTokens+=_pos.bal;
        AssetUnderCollateral.transferFrom(msg.sender,address(this),_collateral);
        Long.openings++;
        return Pos++;
    }
    function increasePositionSize(uint _id,uint _size) external checkLiquidityAvailability() returns(bool){
        Position memory _pos=_Positions[_id];
       require(_pos.size<_size,"new size should be greater than the older amount");
       uint latestBTCPrice=getBTCPrice();
       if(_pos.pos_type == Position_type.long){
            Long.openIntrestInTokens-=_pos.bal;
            Long.openIntrest-= (_pos.bal * _pos.BTCPrice);
            _pos.size=_size ;
            _pos.bal+=(((_size - _pos.size) *1e16) / latestBTCPrice);
            Long.openIntrest+= (_pos.bal * _pos.BTCPrice);
            Long.openIntrestInTokens+=(_size/_pos.BTCPrice);
            _pos.BTCPrice = (_pos.BTCPrice + latestBTCPrice)/2;
       }
       else{
            _pos.size=_size;
            Short.openIntrestInTokens-=_pos.bal;
            Short.openIntrest-=(_pos.bal * _pos.BTCPrice);
            _pos.bal+=(((_size - _pos.size) *1e16) / latestBTCPrice);
            Short.openIntrestInTokens+=_pos.bal;
            Short.openIntrest+=(_pos.bal * _pos.BTCPrice);
       }
        _Positions[_id]=_pos;  
        _getLeverage(_pos,_id);
        return true;
    }
    function increasePositionCollateral(uint _id,uint _collateral) external checkLiquidityAvailability() returns(bool){
        Position memory _pos=_Positions[_id];
        require(_pos.collateral < _collateral,"new collateral should be greater than the older one");
        _pos.collateral=_collateral;
        AssetUnderCollateral.transferFrom(msg.sender,address(this),(_collateral-_pos.collateral));
        _Positions[_id]=_pos;
        _getLeverage(_pos,_id);
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
            bal:getBTC(_size),
            timeStamp:block.timestamp,
            isOpen:true
        });
        _Positions[Pos]=_pos;
        Short.openIntrest+=_size*1e16;
        Short.openIntrestInTokens+=_pos.bal;
        AssetUnderCollateral.transferFrom(msg.sender,Vault,_collateral);
        _checkLiquidityAvailability();
        Short.openings++;
        return Pos++    ;
    }
    function decreaseSize(uint _id,uint _size) external returns(bool){
        Position memory _pos=_Positions[_id];
        if(_size == 0){
            return _liquidate(_pos, _id);
        }
        require(_pos.owner == msg.sender,"only owner can call this function");
        require(_pos.size > _size,"size should be lesser than the previous one");
        if(_pos.pos_type==Position_type.long){
            return decreaseLongPositionSize(_pos,_size,_id);
        }
        else{
            return decreaseShortPositionSize(_pos,_size,_id);
        }
    } 
    function decreaseLongPositionSize(Position memory _pos,uint _size,uint _id) internal  returns(bool){
        int Pnl=_calculatePnL(_pos);
        int SizeDrecrease= ((int(_pos.size) - int(_size))*1e2)/int(_pos.size);
        Pnl= (Pnl *((SizeDrecrease)/int(_pos.size)))/1e2;
        Long.openIntrest-=_pos.size *1e16;
        Long.openIntrest+=_size *1e16;
        Long.openIntrestInTokens-=_pos.bal;
        _pos.size=_size;
        _pos.bal=(_size*1e16/_pos.BTCPrice);
        Long.openIntrestInTokens+=_pos.bal;
        if(Pnl<0){
            AssetUnderCollateral.transfer(Vault,uint(Pnl));
            _pos.collateral-=uint(Pnl);
        }
        else{
            AssetUnderCollateral.transfer(msg.sender,uint(Pnl));
        }
        _Positions[_id]=_pos;
        _getLeverage(_pos,_id);
        return true;
    }
    function decreaseShortPositionSize(Position memory _pos,uint _size,uint _id) internal  returns(bool){
        int Pnl=_calculatePnL(_pos);
        int SizeDrecrease= ((int(_pos.size) - int(_size))*1e2)/int(_pos.size);
        Pnl= (Pnl *((SizeDrecrease)/int(_pos.size)))/1e2;
        Short.openIntrest-=_pos.size *1e16;
        Short.openIntrest+=_size *1e16;
        Short.openIntrestInTokens-=_pos.bal;
        _pos.size=_size;
        _pos.bal=(_size*1e16/_pos.BTCPrice);
        Short.openIntrestInTokens+=_pos.bal;
        if(Pnl>0){
            AssetUnderCollateral.transfer(Vault,uint(Pnl));
        }
        else{
            AssetUnderCollateral.transfer(msg.sender,uint(Pnl));
        }
        _Positions[_id]=_pos;
        _getLeverage(_pos,_id);
        return true;
    }
    function decreaseCollateral(uint _id,uint _collateral) external returns(bool){
        Position memory _pos=_Positions[_id];
        require(_pos.collateral > _collateral,"collateral should be lesser than the previous one");
        uint bal = _pos.collateral - _collateral;
        _pos.collateral=_collateral;
        _getLeverage(_pos,_id);
        AssetUnderCollateral.transfer(msg.sender,bal);
        _Positions[_id]=_pos;
        return true;
    }
    function _calculatePnL(Position memory _pos) internal view returns(int256) {
        int latestBTCPrice= int(getBTCPrice());
        int256 PriceDiffer=latestBTCPrice - int(_pos.BTCPrice);
        return int(int(_pos.bal) * PriceDiffer);
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
        return ((Short.openIntrest) + (Long.openIntrestInTokens * getBTCPrice())); 
    }
    function getBTCPrice() internal view returns(uint256){
        (,int answer,,,)= dataFeed.latestRoundData();
        return uint256(answer);
    }
    function liquidate(uint _id) external returns(bool){
        Position memory _pos = _Positions[_id];
        if(msg.sender == _pos.owner){
            return _liquidate(_pos,_id);
        }
        return _getLeverage(_pos, _id); 
    }
    function _liquidate(Position memory _pos,uint _id) internal isopen(_pos) isOwner(_pos) returns(bool){
       int pnl= _calculatePnL(_pos);
       uint bal;
       if(pnl<0){
        bal = _pos.collateral - uint(pnl/1e16);
        if(bal<0){
            AssetUnderCollateral.transfer(Vault,_pos.collateral);
            _liquidatorFee(_pos);
        }
        else{
            AssetUnderCollateral.transfer(_pos.owner,bal);
            AssetUnderCollateral.transfer(Vault,(_pos.collateral-bal));
            _pos.collateral-=bal;
            borrowerFee(_pos);
            _liquidatorFee(_pos);
        }
       }
       else{
        bal=uint(pnl/1e8);
        AssetUnderCollateral.transfer(_pos.owner,_pos.collateral);
        AssetUnderCollateral.transferFrom(Vault,_pos.owner,bal);
        _liquidatorFee(_pos);
        borrowerFee(_pos);
       }
        if(_pos.pos_type == Position_type.long){
            Long.openIntrest-=_pos.size *1e16;
            Long.openIntrestInTokens-=_pos.bal;
        }
        else{
            Short.openIntrest-=_pos.size *1e16;
            Short.openIntrestInTokens-=_pos.bal;
        }
        _pos.size=0;
        _pos.collateral=0;
        _pos.isOpen=false;
        _Positions[_id]=_pos;
        return true;
    }   
    function _liquidatorFee(Position memory _pos) internal returns(bool){
        uint fee = (liquidatorFeePercentage * _pos.collateral)/1e2;
        if(msg.sender == _pos.owner){
            AssetUnderCollateral.transfer(Vault,fee);
        }
        else{
            AssetUnderCollateral.transfer(msg.sender,fee);
        }
        _pos.collateral-=fee;
        return true;
    }
    function borrowerFee(Position memory _pos) internal returns(bool){
        uint fee = _getBorrowerFee(_pos);
        AssetUnderCollateral.transfer(Vault,fee);
        _pos.collateral-=fee;
        _pos.timeStamp=block.timestamp;
        return true;
    }
    function _getBorrowerFee(Position memory _pos) public view returns(uint){
        uint time = block.timestamp - _pos.timeStamp;
        uint fee = _pos.size * 1e16 * time *  borrowerFeePerSharePerSecond;
        return fee/1e32;
    }
    function _getLeverage(Position memory _pos,uint _id) internal isopen(_pos) isOwner(_pos) returns(bool){
        uint latestBTCPrice=getBTCPrice();
        uint latestCollateral;
        if(_pos.pos_type==Position_type.long){
            if(latestBTCPrice < _pos.BTCPrice){
                latestCollateral=_pos.collateral -(((_pos.bal * _pos.BTCPrice)-(_pos.bal * latestBTCPrice))/1e16); 
                if(_pos.size/latestCollateral < maxLeverage){
                    _liquidate(_pos,_id);
                    return false;
                }
            }
        }
        else{
            if(_pos.BTCPrice < latestBTCPrice){
                latestCollateral=_pos.collateral -(((_pos.bal * latestBTCPrice)-(_pos.bal * _pos.BTCPrice))/1e16);
                if(_pos.size/latestCollateral < maxLeverage){
                    _liquidate(_pos,_id);
                    return false;
                }
            }
        }
        return true;
    }
}
