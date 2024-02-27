// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;
import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "src/Positions.sol";
import "src/Vault.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract Token is ERC20{
    constructor(string memory _name, string memory _symbol) ERC20(_name,_symbol){
        _mint(msg.sender,type(uint).max);
    }
}
contract datafeed{
    function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    ){
        if(tx.origin == address(5)){
           return (0,4500000000000,0,0,0);
        }
        if(tx.origin == address(6)){
            return (0,6000000000000,0,0,0);
        }
        return (0,5200000000000,0,0,0);
    }
}
contract test is Test{
    ERC20 public Asset;
    Positions public _pos;
    Vault public _Vault;
    datafeed public _dataFeed;
    address[10] users;

    function setUp() public{
        Asset =new Token("USD","USD");
        _Vault =new Vault(Asset,"Vault","VLT",80);
        _dataFeed= new datafeed();
        _pos =new Positions(0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c,15,address(_Vault),address(Asset),90);
        _Vault.set_Position(address(_pos));
        uint i;
        for(i=1;i<10;i++){
            users[i]=address(uint160(i));
            Asset.transfer(address(uint160(i)),type(uint).max/10);
            vm.startPrank(address(uint160(i)));
            Asset.approve(address(_Vault),type(uint).max);
            Asset.approve(address(_pos),type(uint).max);
            vm.stopPrank();

        }
        _pos.setLiquidatorFeePercentage(3);
    }
    function test_Vault() public{


        vm.startPrank(users[1]);
        uint shares_users1=_Vault.deposit(10000,users[1]);
        console.log("assets:",10000,"shares:",_Vault.balanceOf(users[1]));
        vm.stopPrank();


        vm.startPrank(users[2]);
        uint shares_users2=_Vault.deposit(78454,users[2]);
        console.log("assets:",78454,"shares:",_Vault.balanceOf(users[2]));
        vm.stopPrank();


       vm.startPrank(address(_Vault));
        console.log("before transfer :",_Vault.totalAssets());
        Asset.transfer(address(4),7337);
        console.log("tranfer :",7337);
        console.log("after tranfer :",_Vault.totalAssets());
        vm.stopPrank();


        vm.startPrank(users[3]);
        uint shares_users3=_Vault.deposit(13434,users[3]);
        console.log("assets:",13434,"shares:",_Vault.balanceOf(users[3]));
        vm.stopPrank();


        console.log(_Vault.totalAssets());
        console.log(_Vault.totalSupply());  
        vm.startPrank(users[4]);
        _Vault.mint(239990, users[4]);
        vm.stopPrank();


        vm.startPrank(users[1]);
        console2.log(Asset.balanceOf(users[1]));
        _Vault.redeem(shares_users1,users[1],users[1]);
        console2.log(Asset.balanceOf(users[1]));
        vm.stopPrank();


        console2.log(Asset.balanceOf(users[2]));
        console2.log(Asset.balanceOf(users[3]));


       vm.startPrank(users[2]);
        console2.log(Asset.balanceOf(users[2]));
        _Vault.redeem(shares_users2,users[2],users[2]);
        console2.log(Asset.balanceOf(users[2]));
        console.log(_Vault.balanceOf(users[2]));
        vm.stopPrank();


        vm.startPrank(users[3]);
        console2.log(Asset.balanceOf(users[3]));
        _Vault.redeem(shares_users3,users[3],users[3]);
        console2.log(Asset.balanceOf(users[3]));
        vm.stopPrank();


        vm.startPrank(users[4]);
        uint assets_user4=_Vault.mint(10000,users[4]);
        console.log(_Vault.balanceOf(users[4]));
        vm.stopPrank();


        vm.startPrank(users[4]);
        _Vault.withdraw(assets_user4,users[4],users[4]);
        console.log(_Vault.balanceOf(users[4]));
        vm.stopPrank();
        

    }
    function test_Positions () public{
        uint lop;
        uint lopt;
        uint sop;
        uint sopt;

        vm.startPrank(users[9]);
        uint shares_users3=_Vault.deposit(999999999999999999,users[9]);
        vm.stopPrank();

        console.log("pos bal :",Asset.balanceOf(address(_pos)));
        //user5 opens a long position worth 1000 usd
        vm.startPrank(users[5]);
        uint _id1=_pos.openPosition(5000,1000,true);
        vm.stopPrank();


        console.log("pos bal :",Asset.balanceOf(address(_pos)));

        //user6 opens a short position with size 7500 col 900
        vm.startPrank(users[6]);
        uint _id2=_pos.openPosition(7500,900,false);
        vm.stopPrank();

        console.log("pos bal :",Asset.balanceOf(address(_pos)));
        (lop, lopt, sop ,sopt)=_pos._getPositionSummary();
        console2.log("position summary ");
        console2.log(lop,lopt,sop,sopt);

        //user6 and 5 adds collateral and size
        vm.startPrank(users[5]);
        require(_pos.increasePositionSize(_id1, 6000));
        require(_pos.increasePositionCollateral(_id1, 1500));
        vm.stopPrank();
        console.log("pos bal :",Asset.balanceOf(address(_pos)));
        (lop, lopt ,sop ,sopt)=_pos._getPositionSummary();
        console2.log("position summary ");
        console2.log(lop,lopt,sop,sopt);



        vm.startPrank(users[6]);
        require(_pos.increasePositionSize(_id2, 8000));
        require(_pos.increasePositionCollateral(_id2,1200));
        vm.stopPrank();
        console.log("pos bal :",Asset.balanceOf(address(_pos)));
        (lop ,lopt ,sop, sopt)=_pos._getPositionSummary();
        console2.log("position summary ");
        console2.log(lop,lopt,sop,sopt);
        

        //decrease the collateral and size of long and short position
        vm.startPrank(users[5]);
        require(_pos.decreaseCollateral(_id1,500));
        require(_pos.decreaseSize(_id1, 4000));
        vm.stopPrank();
       console.log("pos bal :",Asset.balanceOf(address(_pos)));
        vm.startPrank(users[6]);
        require(_pos.decreaseCollateral(_id2,500));
        require(_pos.decreaseSize(_id2, 4000));
        vm.stopPrank();
        console.log("pos bal :",Asset.balanceOf(address(_pos)));

    
        //liquidating long position and short position
        vm.startPrank(users[5]);
        require(_pos.liquidate(_id1));
        vm.stopPrank();

        vm.startPrank(users[6]);
        require(_pos.liquidate(_id2));
        vm.stopPrank();

        console.log("Position bal :",Asset.balanceOf(address(_pos)));
    }
}