// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract CryptoSOSTest{
    address public owner;
    uint256 private moneyFromGames;

    struct Games{
        uint8 GameNumber;
        address firstPlayer;
        address secondPlayer;
        string listOfLetters;
        uint256 lastTimestamp;
        address lastPlayer;
    }

    Games[] private gamesList;

    //Indexed specifies storing so every event is stored at the logs
    event StartGame(address indexed firstPlayer,address indexed secondPlayer); //Storing the address of the players at the log record as a topic

    event Move(uint8 indexed position, uint8 indexed moveType, address indexed player); //moveType only 1 for S or 2 for O

    event Winner(address indexed winner);

    event Tie(address indexed firstPlayer, address indexed secondPlayer);


    modifier onlyOwner() {
        require(msg.sender == owner, "You can't call this function,only the owner of the contract can");
        _;
    }

    modifier onlyPlayers(){
        uint256 gameIndex;
        for (uint256 i = 0; i < gamesList.length; i++) {
            if (gamesList[i].firstPlayer==msg.sender || gamesList[i].secondPlayer==msg.sender) {
                gameIndex = i;
                break;
            }
        }
        require(msg.sender == gamesList[gameIndex].firstPlayer || msg.sender == gamesList[gameIndex].secondPlayer,"Only players who payed for this particular game call this function");
        _;
    }

    modifier status(){
        uint256 gameIndex;
        for (uint256 i = 0; i < gamesList.length; i++) {
            if (gamesList[i].firstPlayer==msg.sender || gamesList[i].secondPlayer==msg.sender) {
                gameIndex = i;
                break;
            }
        }
        require(gamesList[gameIndex].firstPlayer != address(0) || gamesList[gameIndex].secondPlayer != address(0),"Game is not started yet");
        _;
    }

    function play() public payable{
        require(msg.sender != owner,"Owner cannot play his own game");
        require(msg.value == 1 ether,"You have to pay 1 ether in order to participate in this round"); //Paying 1 ether to the contract's balance is a must
        bool playerNotInGame = true;
        for (uint256 i = 0; i < gamesList.length; i++) {
            if (msg.sender == gamesList[i].firstPlayer || msg.sender == gamesList[i].secondPlayer) {
                playerNotInGame = false;
                break;
            }
        }
        require(playerNotInGame, "You can't participate in more than one game at the time");
        if (gamesList.length == 0) {
            Games memory newGame = Games({
                GameNumber: uint8(gamesList.length+1),
                firstPlayer: msg.sender,
                secondPlayer: address(0),
                listOfLetters: "---------",
                lastTimestamp: block.timestamp,
                lastPlayer: msg.sender
            });
            gamesList.push(newGame);
            emit StartGame(newGame.firstPlayer, newGame.secondPlayer);
            return;
        }      
        for (uint256 i = 0; i < gamesList.length; i++) {
            if(gamesList[i].firstPlayer==address(0)){
                gamesList[i].firstPlayer=msg.sender;
                emit StartGame(msg.sender, address(0));
                break;
            }
            else if(gamesList[i].secondPlayer==address(0)){
                gamesList[i].secondPlayer=msg.sender;
                gamesList[i].lastTimestamp=block.timestamp;
                gamesList[i].lastPlayer=msg.sender;
                emit StartGame(gamesList[i].firstPlayer, gamesList[i].secondPlayer);
                break;
            }
            else if(i == gamesList.length - 1) {
                Games memory newGame = Games({
                    GameNumber: uint8(gamesList.length + 1),
                    firstPlayer: msg.sender,
                    secondPlayer: address(0),
                    listOfLetters: "---------",
                    lastTimestamp: block.timestamp,
                    lastPlayer: msg.sender
                });
                gamesList.push(newGame);
                emit StartGame(newGame.firstPlayer, newGame.secondPlayer);
                break;
            }

        }
    }

    function getGameState() public view returns (string memory){
        for (uint256 i = 0; i < gamesList.length; i++) {
            if(gamesList[i].firstPlayer==msg.sender || gamesList[i].secondPlayer==msg.sender){
                return gamesList[i].listOfLetters;
            }
        }
        return "You are not participating in any game!";
    }
    function placeLetter(uint8 position,bytes1 character) internal {
        bool playerInGame = false;
        uint256 gameIndex;
        for (uint256 i = 0; i < gamesList.length; i++) {
            if (gamesList[i].firstPlayer==msg.sender || gamesList[i].secondPlayer==msg.sender) {
                playerInGame = true;
                gameIndex = i;
                break;
            }
        }
        require(playerInGame, "You are not participating in any game!");
        require(gamesList[gameIndex].firstPlayer!=address(0) && gamesList[gameIndex].secondPlayer!=address(0),"You are waiting for another player still");
        require(msg.sender != gamesList[gameIndex].lastPlayer, "It's not your turn to play!");
        require(position >= 0 && position < 9, "Invalid position");
        require(checkEmpty(position,gameIndex), "Position is not empty, letter already placed");

        placeChar(position,character,gameIndex);
        gamesList[gameIndex].lastPlayer=msg.sender;
        positionWin();
        gamesList[gameIndex].lastTimestamp = block.timestamp;
    }
    function placeS(uint8 position) external onlyPlayers status{
        placeLetter(position,"S");
        emit Move(position,1,msg.sender);

    }
    function placeO(uint8 position) external onlyPlayers status {
        placeLetter(position,"O");
        emit Move(position,2,msg.sender);
    }
    function checkEmpty(uint position,uint256 gameIndex) internal view returns (bool)  {
        require(position < 9, "Invalid position");
        bytes memory str=bytes(gamesList[gameIndex].listOfLetters);
        return str[position] == '-';

    }
    function placeChar(uint8 number,bytes1 char,uint256 gameIndex) internal { //Placing character to the position the player wants
        bytes memory str=bytes(gamesList[gameIndex].listOfLetters);
        for(uint8 i=0;i<9;i++){
            if(number==i){
                str[i]=char;
            }
        }
        gamesList[gameIndex].listOfLetters=string(str);
    }

    function cancel() external onlyPlayers {
        uint number;
        for (uint256 i = 0; i < gamesList.length; i++) {
            if (msg.sender == gamesList[i].firstPlayer || msg.sender == gamesList[i].secondPlayer) {
                number=i;
                break;
            }
        }
        if(gamesList[number].secondPlayer==address(0) && block.timestamp - gamesList[number].lastTimestamp > 120 seconds){
            (bool success1, )= msg.sender.call{value:1 ether}("");
            require(success1,"The transfer to first player failed");
            emit Winner(msg.sender);
            resetGame();
        }
        require(gamesList[number].secondPlayer==address(0) && block.timestamp - gamesList[number].lastTimestamp > 120 seconds,"You have to wait 2 more minutes");
    }

    function tooSlow() external onlyPlayers{
        uint number;
        for (uint256 i = 0; i < gamesList.length; i++) {
            if (msg.sender == gamesList[i].firstPlayer || msg.sender == gamesList[i].secondPlayer) {
                number=i;
                break;
            }
        }
        require(msg.sender!=owner && block.timestamp - gamesList[number].lastTimestamp >60 seconds,"You have to wait 1 minute");
        require(msg.sender==gamesList[number].lastPlayer,"Can only be called by the last player");
        if(msg.sender==gamesList[number].lastPlayer && block.timestamp - gamesList[number].lastTimestamp > 60 seconds){
            (bool success1, )= gamesList[number].lastPlayer.call{value:1.9 ether}("");
            require(success1,"The transfer to firstPlayer failed");
            emit Winner(msg.sender);
            resetGame();
        }
        if(msg.sender==owner && block.timestamp - gamesList[number].lastTimestamp>300 seconds){
            tiePrize();
            resetGame();
        }
    }
    function positionWin() internal{
        if(checkWinner()){
            getPrize(msg.sender);
            resetGame();
            moneyFromGames+=0.3 ether;
        }else if (fullLetters()){
            tiePrize();
            resetGame();
            moneyFromGames+=0.4 ether;
        }    

    }
    function tiePrize() internal {
        uint number;
        for (uint256 i = 0; i < gamesList.length; i++) {
            if (msg.sender == gamesList[i].firstPlayer || msg.sender == gamesList[i].secondPlayer) {
                number=i;
                break;
            }
        }
        (bool success1, )= gamesList[number].firstPlayer.call{value:0.8 ether}("");
        require(success1,"The transfer to firstPlayer failed");
        (bool success2, )= gamesList[number].secondPlayer.call{value:0.8 ether}("");
        require(success2,"The transfer to secondPlayer failed");
        emit Tie(gamesList[number].firstPlayer,gamesList[number].secondPlayer);
    }

    function getPrize(address player) internal{
        (bool success1, )=player.call{value:1.7 ether}("");
        require(success1,"The transfer didn't complete successfully");
        emit Winner(msg.sender);
    }

    function sweepProfit() external onlyOwner{
        require(moneyFromGames>0,"No profit for owner");
        (bool success, )=owner.call{value: moneyFromGames}("");
        require(success,"Owner couldn't receive the money");
        moneyFromGames=0 ether;
    }

    function fullLetters() internal view returns (bool){
        uint number;
        for (uint256 i = 0; i < gamesList.length; i++) {
            if (msg.sender == gamesList[i].firstPlayer || msg.sender == gamesList[i].secondPlayer) {
                number=i;
                break;
            }
        }
        bytes memory str = bytes(gamesList[number].listOfLetters);
        for (uint8 i = 0; i < 9; i++) {
            if (str[i] != "-") { 
                return false; // Characters are different, not equal
            }
        }
        return true;
    }
    function resetGame() internal{
        uint number;
        for (uint256 i = 0; i < gamesList.length; i++) {
            if (msg.sender == gamesList[i].firstPlayer || msg.sender == gamesList[i].secondPlayer) {
                number=i;
                break;
            }
        }
        if(number==gamesList.length){
            gamesList.pop(); //If it is the last game of the list,at the exact moment,it pops/deletes the last element of the list.
        }
        gamesList[number].firstPlayer=address(0);
        gamesList[number].secondPlayer=address(0);
        gamesList[number].listOfLetters="---------";
        gamesList[number].lastTimestamp=0 seconds;
        gamesList[number].lastPlayer=address(0);

    }
    function checkWinner() internal view returns (bool) {
        string memory list;
        for (uint256 i=0;i< gamesList.length; i++) {
            if (gamesList[i].firstPlayer==msg.sender || gamesList[i].secondPlayer==msg.sender) {
                list=gamesList[i].listOfLetters;
                break;
            }
        }
        bytes memory game=bytes(list);
        for (uint8 i=0;i<3;i++) {
            if(game[i*3]=="S" && game[i*3+1]=="O" && game[i*3+2]=="S"){
                return true;
            }
        }
        for (uint8 i=0;i<3;i++) {
            if (game[i]=="S" && game[i+3]=="O" && game[i+6]=="S"){
                return true;
            }
        }
        if (game[0]=="S" && game[4]=="O" && game[8]=="S"){
            return true;
        }
        if (game[2]=="S" && game[4]=="O" && game[6]=="S"){
            return true;
        }
        return false;

    }
    //Constructor is only called at the deployment
    constructor() {
        owner=msg.sender;
    }

}
