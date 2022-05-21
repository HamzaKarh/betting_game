// SPDX-License-Identifier: MIT

pragma solidity 0.6.0;

import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BettingGame is Ownable {
    /**
     *******************************************************************
     *************************** structures  ***************************
     */

    enum COND_STATE {
        WAITING,
        TRUE,
        FALSE
    }

    enum BET_STATE {
        OPEN,
        CLOSED,
        COMPLETED
    }

    enum BET_TYPE {
        FIXED,
        FREE
    }

    enum GAME_TYPE {
        UNICONDITIONAL,
        MULTICONDITIONAL,
        HIGH_SCORE
    }

    struct Condition {
        int256 id;
        string statement;
        uint256 value;
        uint256 rating;
        COND_STATE state;
    }

    /***********************************************************************
     *************************** State Variables ***************************
     */
    BET_STATE public currentState;
    BET_TYPE public betType;
    GAME_TYPE public gameType;
    address payable[] public players;
    mapping(address => Condition) public playerToUniCond;
    mapping(address => Condition[]) public playerToMultiCond;
    mapping(address => uint256) public playerToScore;
    uint256 public usdEntryFee;
    string[] conditions;
    AggregatorV3Interface internal ethUsdPriceFeed;

    /**
     *******************************************************************
     *************************** Constructor ***************************
     */

    constructor(
        address _priceFeedAddress,
        uint256 _entryFee,
        string memory _betType,
        string memory _gameType
    ) public reqCorrectStates(_betType, _gameType) {
        ethUsdPriceFeed = AggregatorV3Interface(_priceFeedAddress);
        currentState = BET_STATE.OPEN;
        if (strCompare(_betType, "FIXED")) {
            betType = BET_TYPE.FIXED;
        } else if (strCompare(_betType, "FREE")) {
            betType = BET_TYPE.FREE;
        }
        if (strCompare(strToUpper(_gameType), "UNICONDITIONAL")) {
            gameType = GAME_TYPE.UNICONDITIONAL;
        } else if (strCompare(strToUpper(_gameType), "MULTICONDITIONAL")) {
            gameType = GAME_TYPE.MULTICONDITIONAL;
        } else if (strCompare(strToUpper(_gameType), "HIGH_SCORE")) {
            gameType = GAME_TYPE.HIGH_SCORE;
        }
        usdEntryFee = _entryFee;
    }

    /**
     ******************************************************************
     *************************** functions  ***************************
     */

    function enter(string memory _statement, uint256 _rating)
        public
        payable
        reqOpenLottery
        reqPay(msg.value)
        reqExistingCondition(_statement)
        reqNotGameType(GAME_TYPE.HIGH_SCORE)
    {
        if (gameType == GAME_TYPE.UNICONDITIONAL) {
            require(
                playerInGame(msg.sender) == false,
                "Player already joined."
            );
            Condition memory cond = Condition(
                0,
                _statement,
                msg.value,
                _rating,
                COND_STATE.WAITING
            );
            playerToUniCond[msg.sender] = cond;
            players.push(msg.sender);
        } else if (gameType == GAME_TYPE.MULTICONDITIONAL) {
            Condition memory cond = Condition(
                int256(playerToMultiCond[msg.sender].length),
                _statement,
                msg.value,
                _rating,
                COND_STATE.WAITING
            );
            playerToMultiCond[msg.sender].push(cond);
            if (playerToMultiCond[msg.sender].length == 1) {
                players.push(msg.sender);
            }
        }
        refreshRates();
    }

    function enter()
        public
        payable
        reqOpenLottery
        reqPay(msg.value)
        reqGameType(GAME_TYPE.HIGH_SCORE)
    {
        playerToScore[msg.sender] = 0;
        players.push(msg.sender);
    }

    function getEntranceFee() public view returns (uint256) {
        return usdEntryFee;
    }

    function playerInGame(address _player) public view returns (bool) {
        for (uint256 i; i < players.length; i++) {
            if (players[i] == _player) {
                return true;
            }
        }
        return false;
    }

    function startGame() public reqOpenLottery onlyOwner {
        currentState = BET_STATE.CLOSED;
    }

    function refreshRates() private {
        for (uint256 i = 0; i < players.length; i++) {
            for (uint256 y = 0; y < playerToMultiCond[players[i]].length; y++) {
                playerToMultiCond[players[i]][y].rating = calculateRate(
                    playerToMultiCond[players[i]][y].statement
                );
            }
        }
    }

    function calculateRate(string memory _statement) private returns (uint256) {
        uint256 rate = 1;
        uint256 sumOcc = 1; // Sum of occurences of the statement
        uint256 total = 0; // Total amount of statements

        for (uint256 i = 0; i < players.length; i++) {
            for (uint256 y = 0; y < playerToMultiCond[players[i]].length; y++) {
                if (
                    strCompare(
                        playerToMultiCond[players[i]][y].statement,
                        _statement
                    )
                ) {
                    sumOcc++;
                }
                total++;
            }
        }
        rate *= (total - sumOcc) / sumOcc;
        return rate;
    }

    function setState(
        address _player,
        uint256 _id,
        string memory _state
    ) public reqClosedLottery onlyOwner {
        if (strCompare(strToUpper(_state), "TRUE")) {
            playerToMultiCond[_player][_id].state = COND_STATE.TRUE;
        } else if (strCompare(strToUpper(_state), "FALSE")) {
            playerToMultiCond[_player][_id].state = COND_STATE.FALSE;
        }
    }

    function setState(address _player, string memory _state)
        public
        reqClosedLottery
        onlyOwner
        reqCorrectCondState(_state)
        reqExistingPlayer(_player)
    {
        if (strCompare(strToUpper(_state), "TRUE")) {
            playerToUniCond[_player].state = COND_STATE.TRUE;
        } else if (strCompare(strToUpper(_state), "FALSE")) {
            playerToUniCond[_player].state = COND_STATE.FALSE;
        }
    }

    function endGame() public reqClosedLottery onlyOwner {
        if (gameType == GAME_TYPE.UNICONDITIONAL) {} else if (
            gameType == GAME_TYPE.MULTICONDITIONAL
        ) {} else {}
    }

    function conditionExists(string memory _statement)
        public
        view
        returns (bool)
    {
        for (uint256 i = 0; i < conditions.length; i++) {
            if (strCompare(_statement, conditions[i])) {
                return true;
            }
        }
        return false;
    }

    function addCondition(string memory _statement)
        public
        onlyOwner
        reqNonExistingCondition(_statement)
    {
        conditions.push(_statement);
    }

    /**
     *****************************************************************
     *************************** modifiers ***************************
     */

    modifier reqNotGameType(GAME_TYPE _type) {
        require(_type != gameType);
        _;
    }

    modifier reqGameType(GAME_TYPE _type) {
        require(_type == gameType);
        _;
    }

    modifier reqExistingCondition(string memory _statement) {
        require(conditionExists(_statement), "Condition does not exist");
        _;
    }

    modifier reqNonExistingCondition(string memory _statement) {
        require(
            conditionExists(_statement) == false,
            "Condition does not exist"
        );
        _;
    }

    modifier reqExistingPlayer(address _player) {
        require(playerInGame(_player));
        _;
    }

    modifier reqCorrectStates(string memory _betType, string memory _gameType) {
        require(
            strCompare(strToUpper(_betType), "FIXED") ||
                strCompare(strToUpper(_betType), "FREE"),
            "Bet type incorrect"
        );
        require(
            strCompare(strToUpper(_gameType), "UNICONDITIONAL") ||
                strCompare(strToUpper(_gameType), "MULTICONDITIONAL") ||
                strCompare(strToUpper(_gameType), "HIGH_SCORE"),
            "Game type incorrect"
        );
        _;
    }

    modifier reqCorrectCondState(string memory _condState) {
        require(
            strCompare(strToUpper(_condState), "TRUE") ||
                strCompare(strToUpper(_condState), "FALSE"),
            "Condition state incorrect"
        );
        _;
    }

    modifier reqOpenLottery() {
        require(currentState == BET_STATE.OPEN, "The bet needs to be open.");
        _;
    }

    modifier reqClosedLottery() {
        require(
            currentState == BET_STATE.CLOSED,
            "The bet needs to be started."
        );
        _;
    }

    modifier reqPay(uint256 _fee) {
        (, int256 rate, , , ) = ethUsdPriceFeed.latestRoundData();
        uint256 entranceFee = getEntranceFee();
        uint256 weiFee = (10**18 / (uint256(rate) / 10**18)) * entranceFee;
        if (betType == BET_TYPE.FIXED) {
            require(
                _fee == weiFee,
                strConcat(
                    string("The entry fee is fixed at :"),
                    uintToString(_fee)
                )
            );
        } else {
            require(
                _fee >= weiFee,
                strConcat(
                    string("The minimum entrance fee is :"),
                    uintToString(usdEntryFee)
                )
            );
        }
        _;
    }

    /**
     *************************************************************************
     *************************** Helpful functions ***************************
     */

    function uintToString(uint256 v) internal returns (string memory) {
        uint256 maxlength = 100;
        bytes memory reversed = new bytes(maxlength);
        uint256 i = 0;
        while (v != 0) {
            uint256 remainder = v % 10;
            v = v / 10;
            reversed[i++] = bytes1(uint8(48 + remainder));
            //ASCII code starts numbers (0) at 48 and continues till 57
            //bytes and bytes1 are the same (one byte worth of data)
            //Code basically writes the number in a byte
            //then is cast from byte to string through ASCII code table
        }
        bytes memory s = new bytes(i);
        for (uint256 j = 0; j < i; j++) {
            s[j] = reversed[i - 1 - j];
        }
        return string(s);
    }

    function strConcat(string memory _a, string memory _b)
        internal
        returns (string memory)
    {
        bytes memory _ba = bytes(_a);
        bytes memory _bb = bytes(_b);
        bytes memory ab = new bytes(_ba.length + _bb.length);
        uint256 k = 0;
        for (uint256 i = 0; i < _ba.length; i++) ab[k++] = _ba[i];
        for (uint256 i = 0; i < _bb.length; i++) ab[k++] = _bb[i];

        return string(ab);
    }

    function strToUpper(string memory str) internal returns (string memory) {
        bytes memory bStr = bytes(str);
        bytes memory bUpper = new bytes(bStr.length);
        for (uint256 i = 0; i < bStr.length; i++) {
            // if char is uppercase
            if ((int8(bStr[i]) >= 97) && (int8(bStr[i]) <= 122)) {
                bUpper[i] = bytes1(int8(bStr[i]) - 32);
            } else {
                bUpper[i] = bStr[i];
            }
        }
        return string(bUpper);
    }

    function strToLower(string memory str) internal returns (string memory) {
        bytes memory bStr = bytes(str);
        bytes memory bLower = new bytes(bStr.length);
        for (uint256 i = 0; i < bStr.length; i++) {
            // if char is uppercase
            if ((int8(bStr[i]) >= 65) && (int8(bStr[i]) <= 90)) {
                bLower[i] = bytes1(int8(bStr[i]) + 32);
            } else {
                bLower[i] = bStr[i];
            }
        }
        return string(bLower);
    }

    function strCompare(string memory strA, string memory strB)
        internal
        pure
        returns (bool)
    {
        return (keccak256(bytes(strA)) == keccak256(bytes(strB)));
    }
}
