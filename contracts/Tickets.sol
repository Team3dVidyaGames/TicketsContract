// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Tickets is ERC721URIStorage, VRFConsumerBase, Ownable {
    uint256 private tokenIds;
    uint256 public ethTracker;
    uint256 public hardCap = 500 ether;
    uint256 public endTime;
    uint256 public randomTicketNumber;
    uint256 public rollStatus; // 0: Not started rolling yet, 1: Progress in rolling, 2: Finished rolling

    string public baseURI;

    // ChainLink Variables
    bytes32 private keyHash;
    uint256 private fee;
    bytes32 private currentRequestId;

    /// @notice Event emitted when randomNumber arrived.
    event randomNumberArrived(
        bool arrived,
        bytes32 requestId,
        uint256 randomNumber
    );

    /**
     * Constructor inherits VRFConsumerBase
     *
     * Network: Ethereum(Kovan) Testnet
     * Chainlink VRF Coordinator address: 0xdD3782915140c8f3b190B5D67eAc6dc5760C46E9
     * LINK token address:                0xa36085F69e2889c224210F603D836748e7dC0088
     * Key Hash:                          0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4
     * Fee :                              0.1 LINK
     */
    constructor(
        address _vrfCoordinator,
        address _link,
        bytes32 _keyHash,
        uint256 _fee,
        string memory _baseURI
    ) VRFConsumerBase(_vrfCoordinator, _link) ERC721("Ticket", "TIC") {
        keyHash = _keyHash;
        fee = _fee;
        endTime = block.timestamp + 30 days;
        baseURI = _baseURI;
    }

    /**
     * @dev Public function to claim tickets.
     * @dev Anyone can buy as many tickets as they want. Tickets cost 0.1 eth cah.
     * @dev Must not have hit hard cap of 500 eth.
     * @return tokenId
     */
    function claimTicket() public payable returns (uint256) {
        require(
            msg.value == 0.1 ether,
            "Tickets: Tickets go for 0.1 ETH each."
        );
        require(
            msg.value + ethTracker <= hardCap,
            "Tickets: Tickets have sold out."
        );

        ethTracker += msg.value;
        tokenIds++;

        _mint(msg.sender, tokenIds);

        return tokenIds;
    }

    /**
     * @dev Public function to request randomness and returns request Id. This function can be called by only owner.
     * @dev This function can be called when hard cap is reached or when endTime has passed, reverts otherwise.
     * @return requestID
     */
    function rollDice() public onlyOwner returns (bytes32) {
        require(
            rollStatus == 0,
            "Tickets: Dice is already rolled or finished."
        );

        // If endTime is passed OR hard cap is reached...
        if (block.timestamp >= endTime || ethTracker >= hardCap) {
            require(
                LINK.balanceOf(address(this)) >= fee,
                "Tickets: Not enough LINK to pay fee"
            );

            currentRequestId = requestRandomness(keyHash, fee);
            rollStatus = 1;

            emit randomNumberArrived(
                false,
                currentRequestId,
                randomTicketNumber
            );

            return currentRequestId;
        } else {
            revert();
        }
    }

    /**
     * @dev Callback function used by VRF Coordinator. This function sets new random number with unique request Id.
     * @param _requestId Request Id of randomness.
     * @param _randomness Random Number
     */
    function fulfillRandomness(bytes32 _requestId, uint256 _randomness)
        internal
        override
    {
        require(
            currentRequestId == _requestId,
            "Tickets: Request Id is not correct."
        );

        randomTicketNumber = (_randomness % tokenIds) + 1;

        rollStatus = 2;

        emit randomNumberArrived(true, _requestId, randomTicketNumber);
    }

    /**
     * @dev External function to finialize the tickets and choose a winner.
     * @dev Sends all eth to the owner of random tokenId
     */
    function finalize() external {
        require(
            randomTicketNumber > 0 && rollStatus == 2,
            "Tickets: Rolling is not started or still in progress"
        );
        (bool sent, ) = ownerOf(randomTicketNumber).call{
            value: address(this).balance
        }("");
        require(sent, "Tickets: Failed to send Ether");
    }

    /**
     * @dev Override function of the standard ERC721 implementation. This function returns the same JSON URI for all existing tokens.
     * @param tokenId The token Id requested.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        return baseURI;
    }

    /**
     * @dev Function to change the baseURI. This function can be called only by owner.
     * @param _uri The new base URI
     */
    function changeBaseURI(string memory _uri) external onlyOwner {
        baseURI = _uri;
    }
}
