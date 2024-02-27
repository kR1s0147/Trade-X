# What is Trade-x ?

### What are perpetuals?

*Perpetuals are essentially just a way for a trader to bet on the price of a certain index token without actually buying the token while enabling the trader to employ leverage.*

* * *

*Trade-x is a Decentralised Perpetual Protocol . A user can open a position either long / short on BTC with collateral backing up the losses. Liquidity providers provide the liquidity to the traders when traders's position is on loss then it is deducted from users collateral and sent to the LP's and whenever the user position is profitable and the profits are paid by the LP's. This system has three roles*

- ***Liquidity Providers*** *: LP's provide the liquidity for the traders , to pay up for their losses. They also receive the  liquidator fee, which is proportional to time the traders hold the LP's assets.*
- ***Traders*** *: Traders can open position by depositing equivalent amount of collateral to backup their losses .*
- ***Keeper*** *:Keeper usually set Position and Vault contracts address in the other contracts in order to get information across different protocols . claims the fee .*

# Features

- Liquidity Providers can deposit and withdraw liquidity.
- Traders can open a perpetual position for BTC, with a given size and collateral.
- Traders can increase the size of a perpetual position.
- Traders can increase the collateral of a perpetual position.
- Traders cannot utilize more than a configured percentage of the deposited liquidity.
- Liquidity providers cannot withdraw liquidity that is reserved for positions.
- Traders can decrease the size of their position and realize a proportional amount of their PnL.
- Traders can decrease the collateral of their position.
- Individual position’s can be liquidated with a `liquidate` function, any address may invoke the `liquidate` function.
- A `liquidatorFee` is taken from the position’s remaining collateral upon liquidation with the `liquidate` function and given to the caller of the `liquidate` function.
- It is up to you whether the `liquidatorFee` is a percentage of the position’s remaining collateral or the position’s size, you should have a reasoning for your decision documented in the `README.md`.
- Traders can never modify their position such that it would make the position liquidatable.
- Traders are charged a `borrowingFee` which accrues as a function of their position size and the length of time the position is open.

# The Protocol

|     |     |
| --- | --- |
| **<ins> Contract Name</ins>** | **<ins>Usage</ins>** |
| **Vault.sol** | In this contract Liquidity providers provide Liquidity for the protocol , in return they get equivalent amount of shares. |
| **Position.sol** | Its entry for the traders . They can open position by depositing the collateral to backup for their losses. |
| **AggregetorV3interface.sol** | To interact with Chain link Oracles and get BTC price |
| **OpenZeppelin library** | OZ library used to get ERC20 tokens and ERC4626 and other utilities |

# How does a user can open Position ?

***function openPosition(uint \_size,uint \_collateral , bool isLong) public returns(uint){
                 return isLong ? openLongPosition(\_size, \_collateral) : openShortPosition(\_size, \_collateral);***
            }

- This function servers as a entry point into the system , when this function is called then a position is created and collateral is transfered to the Position contract .
- Position contract holds all the collateral of the users.
- If IsLong is true then it creates a Long Position else Short Position.

 " **function increasePositionSize(uint \_id,uint \_size) external checkLiquidityAvailability() returns(bool)** "

- A user can increase the size by calling this function and returns "true " if successfull or else "False".
- checkLiquidityAvailability() checks of enough liquidity available for the Position.

"**function increasePositionCollateral(uint \_id,uint \_collateral) external checkLiquidityAvailability() returns(bool)"**

- A user can increase the position collateral by calling this function.

**"function decreaseSize(uint \_id,uint \_size) external returns(bool)"**

- A user can decrease the size of the Position , and realise some of his PnL .
- when a user calls this function then we calculate pnl of the position then if it is >0  then we transfer the amount to the owner and if it is <0 then we deduct the loss and transfer to the Vault contract.

**"function decreaseCollateral(uint \_id,uint \_collateral) external returns(bool)"**

- A user can decrease the collateral amount of his position and returns true on success
- and remaining amount of collateral is tranfered to the owner

**"function liquidate(uint _id) external returns(bool)"**

- Anyone can liquidate the Position if it is liquidatable . 
- A position is liquidatable if its leverage is greater than 15x as a reward liquidator recieves some share of Position's collateral
- A user need to pay the borrowers fee to the LP's . (10% per annum)

**" function \_getLeverage(Position memory \_pos,uint \_id) internal isopen(\_pos) isOwner(_pos) returns(bool)"**

- Every function has _getLeverage function is called . 
- it calculates the current Leverage of the Position if it is greater than _maxLeverage then it is liquidated and Liquidator fee is tranfered to LP's 
- if it is less than _maxLeverage(15x) then it does nothing !.

# Security Practices

## Global non-Reentrant :

A user can only enter one function at a time so when we a Attacker try to reenter in to the system then the transaction reverts. and every function has global_nonReentrant modifier to Guard against the Cross-Function reentrancy 

## CEI(check effect interactions) :

Every piece of the details of Positions are updated before an external call is made 

## Return values of external call :

return values of some external calls are not stored to avoid gas griefing attacks .