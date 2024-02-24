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
    pure
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    ){
        return (0,5200000000000,0,0,0);
    }
}
contract test is Test{
    ERC20 public Asset;
    Positions public _pos;
    Vault public _Vault;
    datafeed public _dataFeed;
    address constant user1=address(1);
    address constant user2=address(2);
    address constant user3=address(3);
    function setUp() public{
        Asset =new Token("USD","USD");
        _Vault =new Vault(Asset,"Vault","VLT",80);
        _dataFeed= new datafeed();
        _pos =new Positions(address(_dataFeed),15,address(_Vault),address(Asset),90);
        _Vault.set_Position(address(_pos));
        Asset.transfer(user1,(type(uint).max)/3);
        Asset.transfer(user2,(type(uint).max)/3);
        Asset.transfer(user3,(type(uint).max)/3);
        vm.startPrank(user1);
        Asset.approve(address(_Vault),type(uint).max);
        Asset.approve(address(_pos),type(uint).max);
        vm.stopPrank();
        vm.startPrank(user2);
        Asset.approve(address(_Vault),type(uint).max);
        Asset.approve(address(_pos),type(uint).max);
        vm.stopPrank();
        vm.startPrank(user3);
        Asset.approve(address(_Vault),type(uint).max);
        Asset.approve(address(_pos),type(uint).max);
        vm.stopPrank();

    }
    function test_Vault() public{
        vm.startPrank(user1);
        uint shares_user1=_Vault.deposit(10000,user1);
        console.log("assets:",10000,"shares:",_Vault.balanceOf(user1));
        console.log(shares_user1);
        require(shares_user1>0);
        vm.stopPrank();

        vm.startPrank(user2);
        uint shares_user2=_Vault.deposit(78454,user2);
        console.log("assets:",78454,"shares:",_Vault.balanceOf(user2));
        console.log(shares_user2);
        require(shares_user2>0);
        vm.stopPrank();

       vm.startPrank(address(_Vault));
        console.log("before transfer :",_Vault.totalAssets());
        Asset.transfer(address(4),7337);
        console.log("tranfer :",7337);
        console.log("after tranfer :",_Vault.totalAssets());
        vm.stopPrank();

        vm.startPrank(user3);
        uint shares_user3=_Vault.deposit(13434,user3);
        console.log("assets:",13434,"shares:",_Vault.balanceOf(user3));
        console.log(shares_user3);
        require(shares_user3>0);
        vm.stopPrank();


        console.log(_Vault.totalAssets());
        console.log(_Vault.totalSupply());  


        vm.startPrank(user1);
        console2.log(Asset.balanceOf(user1));
        uint assets_user1 =_Vault.redeem(shares_user1,user1,user1);
        console2.log(Asset.balanceOf(user1));
        vm.stopPrank();


        console2.log(Asset.balanceOf(user2));
        console2.log(Asset.balanceOf(user3));


        vm.startPrank(user2);
        console2.log(Asset.balanceOf(user2));
        // uint assets_user2 =_Vault.redeem(shares_user2,user2,user2);
        console2.log(Asset.balanceOf(user2));
        console.log(_Vault.balanceOf(user2));
        vm.stopPrank();


        vm.startPrank(user3);
        console2.log(Asset.balanceOf(user3));
        uint assets_user3 =_Vault.redeem(shares_user3,user3,user3);
        console2.log(Asset.balanceOf(user3));
        vm.stopPrank();
    }
}