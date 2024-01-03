// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract CryptoSOSTest{
    address public owner;
    address public firstPlayer;
    address public secondPlayer;
    uint256 public lastTimestamp;
    address public lastPlayer;
    string public listOfLetters="---------";

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
        require(msg.sender == firstPlayer || msg.sender == secondPlayer,"Only players who payed for this particular game call this function");
        _;
    }

    modifier status(){
        require(firstPlayer != address(0) || secondPlayer != address(0),"Game is not started yet");
        _;
    }

    constructor() {
        owner=msg.sender;
    }

    function play() public payable{
        require(msg.sender != owner,"Owner cannot play his own game");
        require(msg.value == 1 ether,"You have to pay 1 ether in order to participate in this round"); //Paying 1 ether to the contract's balance is a must
        require(msg.sender != firstPlayer && msg.sender != secondPlayer,"You cant play with your self");

        if (firstPlayer == address(0)) {
            firstPlayer = msg.sender;
            emit StartGame(firstPlayer, address(0));
            lastPlayer=firstPlayer;
            lastTimestamp = block.timestamp; //emit used to make an event
        } else if (secondPlayer == address(0)) {
            secondPlayer = msg.sender;
            emit StartGame(firstPlayer, secondPlayer);
            lastPlayer=secondPlayer;
            lastTimestamp = block.timestamp;
        } else {
            revert("You can't participate in this game");
        }
    }

    function getGameState() public view returns (string memory){
        return listOfLetters;
    }
    function placeLetter(uint8 position,bytes1 character) internal {
        require(firstPlayer!=address(0) || secondPlayer!=address(0),"There is only 1 player in the game still");
        require(msg.sender==firstPlayer || msg.sender==secondPlayer,"Only players who payed for this particular game can Play");
        require(msg.sender!=lastPlayer,"Only the first player must play first");
        require(position>=0 && position<9,"Invalid position");
        require(checkEmpty(position)==true,"Position is not empty,letter already placed");
        placeChar(position,character);
        lastPlayer=msg.sender;
        positionWin();
        lastTimestamp = block.timestamp;
    }
    function placeS(uint8 position) external onlyPlayers status{
        placeLetter(position,"S");
        emit Move(position,1,msg.sender);

    }
    function placeO(uint8 position) external onlyPlayers status {
        placeLetter(position,"O");
        emit Move(position,2,msg.sender);
    }
    function cancel() external onlyPlayers {
        if(secondPlayer==address(0) && block.timestamp - lastTimestamp > 120 seconds){
            (bool success1, )= msg.sender.call{value:1 ether}("");
            require(success1,"The transfer to first player failed");
            emit Winner(msg.sender);
            resetGame();
        }
        require(secondPlayer==address(0) && block.timestamp - lastTimestamp > 120 seconds,"You have to wait 2 more minutes");
    }

    function tooSlow() external onlyPlayers{
        require(msg.sender!=owner && block.timestamp - lastTimestamp >60 seconds,"You have to wait 1 minute");
        require(msg.sender==lastPlayer,"Can only be called by the last player");
        if(msg.sender==lastPlayer && block.timestamp - lastTimestamp > 60 seconds){
            (bool success1, )= lastPlayer.call{value:1.9 ether}("");
            require(success1,"The transfer to firstPlayer failed");
            emit Winner(msg.sender);
            resetGame();
        }
        if(msg.sender==owner && block.timestamp - lastTimestamp>300 seconds){
            tiePrize();
            resetGame();
        }
    }
    function positionWin() internal{
        if(checkWinner()){
            getPrize(msg.sender);
            resetGame();
        }else if (fullLetters()){
            tiePrize();
            resetGame();
        }    

    }
    function tiePrize() internal {
        (bool success1, )= firstPlayer.call{value:0.8 ether}("");
        require(success1,"The transfer to firstPlayer failed");
        (bool success2, )= secondPlayer.call{value:0.8 ether}("");
        require(success2,"The transfer to secondPlayer failed");
        emit Tie(firstPlayer,secondPlayer);
    }

    function getPrize(address player) internal{
        (bool success1, )=player.call{value:1.7 ether}("");
        require(success1,"The transfer didn't complete successfully");
        emit Winner(msg.sender);
    }

    function sweepProfit() external onlyOwner{
        require(address(this).balance>0,"No profit for owner");
        (bool success, )=owner.call{value: address(this).balance}("");
        require(success,"Owner couldn't receive the money");
    }

    function fullLetters() internal view returns (bool){
        bytes memory str = bytes(listOfLetters);
        for (uint8 i = 0; i < 9; i++) {
            if (str[i] != "-") { 
                return false; // Characters are different, not equal
            }
        }
        return true;
    }

    function resetGame() internal{
        firstPlayer=address(0);
        secondPlayer=address(0);
        listOfLetters="---------";
        lastTimestamp=0 seconds;
        lastPlayer=address(0);

    }
    function checkWinner() internal view returns (bool) {
        bytes memory game=bytes(listOfLetters);
        for (uint8 i = 0; i < 3; i++) {
            if (game[i * 3] == "S" && game[i * 3 + 1] == "O" && game[i * 3 + 2] == "S") {
                return true;
            }
        }
        for (uint8 i = 0; i < 3; i++) {
            if (game[i] == "S" && game[i + 3] == "O" && game[i + 6] == "S") {
                return true;
            }
        }
        if (game[0] == "S" && game[4] == "O" && game[8] == "S") {
            return true;
        }
        if (game[2] == "S" && game[4] == "O" && game[6] == "S") {
            return true;
        }
        return false;

    }
    function checkEmpty(uint position) internal view returns (bool)  {
        require(position < 9, "Invalid position");
        bytes memory str=bytes(listOfLetters);
        return str[position] == '-';

    }
    function placeChar(uint8 number,bytes1 char) internal { //Placing character to the position the player wants
        bytes memory str=bytes(listOfLetters);
        for(uint8 i=0;i<9;i++){
            if(number==i){
                str[i]=bytes1(char);
            }
        }
        listOfLetters=string(str);
    }
}
