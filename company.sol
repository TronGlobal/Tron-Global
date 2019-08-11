pragma solidity ^0.4.23;

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
        c = a + b;
        require(c >= a, "SafeMath: addition overflow");
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256 c) {
        require(b <= a, "SafeMath: subtraction overflow");
        c = a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        if (a == 0) {
            return 0;
        }
        
        c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256 c) {
        require(b > 0, "SafeMath: division by zero");
        c = a / b;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256 c) {
        require(b != 0, "SafeMath: modulo by zero");
        c = a % b;
    }
}

contract Token {

    using SafeMath for uint256;

    uint256 private _totalShares;
    mapping(address => uint256) private _sharesOf;

    function totalShares() internal view returns(uint256) {
        return _totalShares;
    }

    function sharesOf(address user) internal view returns(uint256) {
        return _sharesOf[user];
    }

    function _mintShares(address user, uint256 amount) internal {
        _sharesOf[user] = _sharesOf[user].add(amount);
        _totalShares = _totalShares.add(amount);
    }

    function _burnShares(address user, uint256 amount) internal {
        _sharesOf[user] = _sharesOf[user].sub(amount);
        _totalShares = _totalShares.sub(amount);
    }
}

contract Coin is Token {

    using SafeMath for uint256;

    uint256 private _totalSupply;
    mapping(address => uint256) private _unlockedBalanceOf;
    
    event Transfer(address indexed from, address indexed to, uint256 value);

    function totalSupply() public view returns(uint256) {
        return _totalSupply;
    }

    function balanceOf(address user) public view returns(uint256) {
        return sharesOf(user).mul(_totalSupply).div(totalShares());
    }

    function lockedBalanceOf(address user) public view returns(uint256) {
        return balanceOf(user).sub(_unlockedBalanceOf[user]);
    }
    
    function unlockedBalanceOf(address user) public view returns(uint256) {
        return _unlockedBalanceOf[user];
    }

    function _rewardCoins(address user, uint256 amount) internal {
        _mintShares(user, amount.mul(totalShares()).div(_totalSupply));
        _totalSupply = _totalSupply.add(amount);
        emit Transfer(address(0), user, amount);
    }

    function _dividendCoins(address user, uint256 amount) internal {
        _mintShares(user, amount.mul(totalShares()).div(_totalSupply));
        _unlockedBalanceOf[user] = _unlockedBalanceOf[user].add(amount.div(2));
        _totalSupply = _totalSupply.add(amount);
        emit Transfer(address(0), user, amount);
    }

    function _depositCoins(address user, uint256 amount) internal {
        uint shares = amount;
        if (_totalSupply > 0) {
            shares = amount.mul(totalShares()).div(_totalSupply);
        }
        _mintShares(user, shares);
        _totalSupply = _totalSupply.add(amount);
        emit Transfer(address(0), user, amount);
    }
    
    function _mintUnlockedCoins(address user, uint256 amount) internal {
        _depositCoins(user, amount);
        _unlockedBalanceOf[user] = _unlockedBalanceOf[user].add(amount);
    }

    function _spendCoins(address user, uint256 amount) internal {
        _burnShares(user, amount.mul(totalShares()).div(_totalSupply));
        _totalSupply = _totalSupply.sub(amount);
        if (unlockedBalanceOf(user) > balanceOf(user)) {
            _unlockedBalanceOf[user] = balanceOf(user);
        }
        emit Transfer(user, address(0), amount);
    }

    function _withdrawCoins(address user, uint256 amount) internal {
        _burnShares(user, amount.mul(totalShares()).div(_totalSupply));
        _unlockedBalanceOf[user] = _unlockedBalanceOf[user].sub(amount);
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(user, address(0), amount);
    }
    
    function _mintLockedCoinsToEveryoneProportinalToShares(uint256 amount) internal {
        _totalSupply = _totalSupply.add(amount);
    }
}

contract Tron_Global is Coin {

    using SafeMath for uint256;

    // Structs

    struct Player {
        uint lastPaidTime;
        uint[TYPES_FACTORIES] factories;
        uint factoriesCount;
        uint dayStarted;
        uint dayVolume;
        uint tasks;
    }

    // ERC20 Details

    uint8 constant public decimals = 6;
    string constant public name = "Tron Global";
    string constant public symbol = "TGB";

    // Constants

    uint constant public COIN_PRICE = 25; // Coins Per TRX
    uint constant public TYPES_FACTORIES = 7;
    uint constant public PERIOD = 1 hours;
    uint[TYPES_FACTORIES] public prices = [3000e6, 11750e6, 44500e6, 155000e6, 470000e6, 950000e6, 1950000e6];
    uint[TYPES_FACTORIES] public profit = [4e6, 16e6, 64e6, 224e6, 692e6, 1425e6, 2980e6];

    // Variables

    uint public statsDepositedTrx;
    uint public statsWithdrawedTrx;
    uint public statsUserCount;
    uint public statsTotalFactories;

    address public owner = msg.sender;
    mapping(address => Player) public players;

    // Events

    event Deposited(address indexed user, uint256 coins);
    event Withdrawed(address indexed user, uint256 coins);
    event Collected(address indexed user, uint256 coins);
    event Rewarded(address indexed user, uint256 rewardId, uint256 coins);
    event Bought(address indexed user, uint256 indexed factoryType, uint256 number);

    // Methods

    function factories(address user) public view returns(uint[TYPES_FACTORIES] memory){
        return players[user].factories;
    }

    function deposit() public payable {
        Player storage player = players[msg.sender];
        _depositCoins(msg.sender, msg.value.mul(COIN_PRICE));

        if(player.lastPaidTime == 0) {
            player.lastPaidTime = now;
            statsUserCount++;
        }

        statsDepositedTrx = statsDepositedTrx.add(msg.value);
        emit Deposited(msg.sender, msg.value.mul(COIN_PRICE));
    }

    function buy(uint factoryType, uint number) public {
        require(factoryType < TYPES_FACTORIES && number > 0);

        Player storage player = players[msg.sender];
        
        if (now.sub(player.lastPaidTime) >= PERIOD) {
            collect(msg.sender);
        }

        uint total_cost = number.mul(prices[factoryType]);
        require(total_cost <= balanceOf(msg.sender));

        _spendCoins(msg.sender, total_cost);

        // 10% to owner
        // 15% to all shareholders, but not to msg.sender
        // 75% to game dividends
        uint prevUserCoins = balanceOf(msg.sender);
        _mintUnlockedCoins(owner, total_cost.mul(10).div(100));
        _mintLockedCoinsToEveryoneProportinalToShares(total_cost.mul(15).div(100));
        _spendCoins(owner, lockedBalanceOf(owner));
        _spendCoins(msg.sender, balanceOf(msg.sender).sub(prevUserCoins));
        emit Bought(msg.sender, factoryType, number);

        player.factories[factoryType] = player.factories[factoryType].add(number);
        player.factoriesCount = player.factoriesCount.add(number);
        statsTotalFactories = statsTotalFactories.add(number);

        // Achievements

        uint256 prevVolume = player.dayVolume;
        if (now > player.dayStarted + 1 days) {
            prevVolume = 0;
            player.dayStarted = now;
            player.dayVolume = total_cost.div(COIN_PRICE);
        } else {
            player.dayVolume = player.dayVolume.add(total_cost.div(COIN_PRICE));
        }

        // One time achievements

        uint achievementReward = 0;
        uint prevTasks = player.tasks;

        if (player.factoriesCount >= 100 && (player.tasks & 0x01) == 0) {
            achievementReward = achievementReward.add(13000e6);
            player.tasks |= 0x01;
            emit Rewarded(msg.sender, 0x01, 13000e6);
        }
        if (player.factoriesCount >= 400 && (player.tasks & 0x02) == 0) {
            achievementReward = achievementReward.add(55000e6);
            player.tasks |= 0x02;
            emit Rewarded(msg.sender, 0x02, 55000e6);
        }
        if (player.factories[TYPES_FACTORIES - 1] >= 1 && (player.tasks & 0x04) == 0) {
            achievementReward = achievementReward.add(75000e6);
            player.tasks |= 0x04;
            emit Rewarded(msg.sender, 0x04, 75000e6);
        }
        if (player.factories[TYPES_FACTORIES - 1] >= 3 && (player.tasks & 0x08) == 0) {
            achievementReward = achievementReward.add(185000e6);
            player.tasks |= 0x08;
            emit Rewarded(msg.sender, 0x08, 185000e6);
        }
        if (prevTasks != 0x0F && player.tasks == 0x0F) {
            achievementReward = achievementReward.add(350000e6);
            emit Rewarded(msg.sender, 0x0F, 350000e6);
        }

        // Daily achievements

        if (prevVolume < 5000e6 && player.dayVolume >= 5000e6) {
            achievementReward = achievementReward.add(4000e6);
            emit Rewarded(msg.sender, 0x11, 4000e6);
        }
        if (prevVolume < 25000e6 && player.dayVolume >= 25000e6) {
            achievementReward = achievementReward.add(15000e6);
            emit Rewarded(msg.sender, 0x12, 15000e6);
        }
        if (prevVolume < 50000e6 && player.dayVolume >= 50000e6) {
            achievementReward = achievementReward.add(30000e6);
            emit Rewarded(msg.sender, 0x13, 30000e6);
        }
        if (prevVolume < 100000e6 && player.dayVolume >= 100000e6) {
            achievementReward = achievementReward.add(60000e6);
            emit Rewarded(msg.sender, 0x14, 60000e6);
        }

        if (achievementReward > 0) {
            _rewardCoins(msg.sender, achievementReward);
        }
    }

    function collect(address user) public returns(uint256) {
        Player storage player = players[user];
        require(player.lastPaidTime > 0);

        uint hoursPassed = now.sub(player.lastPaidTime).div(PERIOD);
        require(hoursPassed > 0);

        uint hourlyProfit = userProfitPerHour(user);
        uint collectedCoins = hoursPassed.mul(hourlyProfit);

        _dividendCoins(user, collectedCoins);
        player.lastPaidTime = player.lastPaidTime.add(hoursPassed.mul(PERIOD));

        emit Collected(user, collectedCoins);
        return collectedCoins;
    }

    function withdraw(uint256 coins) public {
        require(coins <= unlockedBalanceOf(msg.sender));

        _withdrawCoins(msg.sender, coins);
        msg.sender.transfer(coins.div(COIN_PRICE));
        statsWithdrawedTrx = statsWithdrawedTrx.add(coins.div(COIN_PRICE));
        emit Withdrawed(msg.sender, coins);
    }

    function userProfit(address user) public view returns(uint) {
        uint hoursPassed = now.sub(players[user].lastPaidTime).div(PERIOD);
        return userProfitPerHour(user).mul(hoursPassed);
    }

    function userProfitPerHour(address user) public view returns(uint hourlyProfit) {
        Player storage player = players[user];
        for (uint i = 0; i < TYPES_FACTORIES; i++) {
            hourlyProfit = hourlyProfit.add(player.factories[i].mul(profit[i]));
        }
    }
}