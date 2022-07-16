//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./Busd.sol";
import "hardhat/console.sol";

contract EventPool {
    //STATE VARIABLES
    uint256 private eventId;
    uint256 private resellId;
    Events[] public EventsList;
    BUSD internal token;
    uint256 internal constant cutFee = 10;
    uint256 internal perBalance;
    address public owner;

    struct Events {
        address admin;
        uint256 eventId;
        string name;
        string category;
        string image;
        string description;
        uint256 startdate; //in number days
        uint256 enddate; //in number days
        uint256 price;
        uint256 ticketCount;
        uint256 ticketRemaining;
    }

    struct Resell {
        address admin;
        uint256 resellId;
        uint256 eventId;
        uint256 price;
        bool sold;
    }

    //EVENTS
    event CreateEvent(address indexed owner, uint256 indexed price);
    event BuyTicket(address indexed buyer, uint256 _id);
    event SellTicket(
        address indexed seller,
        address indexed buyer,
        uint256 _id
    );

    event EventSalesWithdrawal(address indexed owner, uint256  amount);

    //MAPPING
    mapping(uint256 => Events) public allEvents;
    mapping(uint256 => Resell) public allResell;
    mapping(address => mapping(uint256 => uint256)) public tickets;
    mapping(address => uint256) public salesBalance;

    constructor(address token_addr) {
      owner = msg.sender;
      token = BUSD(token_addr);
    }

    /**
    @dev create event
     */
    function createEvent(
        string memory _name,
        uint256 _startdate,
        uint256 _enddate,
        uint256 _price,
        uint256 _ticketCount,
        string memory _category,
        string memory _image,
        string memory _description
    ) external returns (bool) {
        require(
            _startdate > block.timestamp,
            "can only organize event at a future date"
        );
        require(
            _ticketCount > 0,
            "can only organize event with at least 1 ticket"
        );
        Events memory event1 = Events(
            msg.sender,
            eventId,
            _name,
            _category,
            _image,
            _description,
            _startdate,
            _enddate,
            _price,
            _ticketCount,
            _ticketCount
        );

        allEvents[eventId] = event1;
        eventId++;

        emit CreateEvent(msg.sender, _price);
        return true;
    }

    /* Returns all unsold market items */
    function fetchAllEvents() public view returns (Events[] memory) {
        uint256 currentIndex = 0;

        Events[] memory items = new Events[](eventId);
        for (uint256 i = 0; i < eventId; i++) {
            uint256 currentId = i;
            Events storage currentItem = allEvents[currentId];
            items[currentIndex] = currentItem;
            currentIndex += 1;
        }
        return items;
    }

    function fetchMyEvents() public view returns (Events[] memory) {
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < eventId; i++) {
            if (allEvents[i].admin == msg.sender) {
                itemCount += 1;
            }
        }

        Events[] memory items = new Events[](itemCount);
        for (uint256 i = 0; i < eventId; i++) {
            if (allEvents[i].admin == msg.sender) {
                uint256 currentId = i;
                Events storage currentItem = allEvents[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    function getEvent(uint256 id) public view returns (Events memory) {
        return allEvents[id];
    }

    function getResell(uint256 id) public view returns (Resell memory) {
        return allResell[id];
    }

    function fetchAllResell() public view returns (Resell[] memory) {
        uint256 currentIndex = 0;

        Resell[] memory items = new Resell[](resellId);
        for (uint256 i = 0; i < resellId; i++) {
            uint256 currentId = i;
            if (allResell[currentId].sold == false) {
                Resell storage currentItem = allResell[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    /**
    @dev event owner decides to extend the deadline for the sale of tickets
     */
    function extendDate(
        uint256 _eventId,
        uint256 _startdate,
        uint256 _enddate
    ) external eventOwner(_eventId) {
        uint256 myEventStartDate = allEvents[_eventId].startdate;
        uint256 myEventEndDate = allEvents[_eventId].enddate;

        require(
            _startdate > myEventStartDate,
            "can only extend to a future date"
        );
        require(_enddate > myEventEndDate, "can only extend to a future date");

        allEvents[_eventId].startdate = _startdate;
        allEvents[_eventId].enddate = _enddate;
    }

    /**
    @dev buys ticket with an input of event id
    @dev uses chainlink price feed to convert between fiat currency USD and ETH

     */
    function buyTicket(uint256 _eventId)
        external
        payable
        eventExist(_eventId)
        eventActive(_eventId)
        returns (bool)
    {
        uint256 ticketPrice = allEvents[_eventId].price; //ticket set price for the event
        uint256 Per = (ticketPrice / 100) * (cutFee);
        uint256 actualPriceTicketSold = ticketPrice - Per;
        require(
            tickets[msg.sender][_eventId] != 1,
            "You already have a ticket"
        );
        require(token.balanceOf(msg.sender) >= ticketPrice, "Not enough busd"); //checks that enough eth
        require(
            allEvents[_eventId].ticketRemaining >= 1,
            "Not enough ticket left"
        );
        // require(
        //     token.transferFrom(
        //         msg.sender,
        //         allEvents[_eventId].admin,
        //         actualPriceTicketSold
        //     ),
        //     "An error occured, make sure you approve the contract"
        // );
        require(
            token.transferFrom(msg.sender, address(this), ticketPrice),
            "An error occured, make sure you approve the contract"
        );

        salesBalance[allEvents[_eventId].admin] += actualPriceTicketSold;
        perBalance += Per;


        tickets[msg.sender][_eventId] = 1; //increment number of ticket for this event
        allEvents[_eventId].ticketRemaining -= 1;
        emit BuyTicket(msg.sender, _eventId);
        return true;
    }

    function listTicket(uint256 _eventId, uint256 price)
        external
        ticketExist(_eventId)
        eventExist(_eventId)
        eventActive(_eventId)
    {
        Resell memory tick = Resell(
            msg.sender,
            resellId,
            _eventId,
            price,
            false
        );
        allResell[resellId] = tick;
        resellId++;
    }

    function sellTicket(
        uint256 _resellId,
        uint256 _eventId,
        address owner_addr
    ) external eventExist(_eventId) eventActive(_eventId) {
        uint256 ticketPrice = allResell[_resellId].price; //ticket set price for the event
        uint256 Per = (ticketPrice / 100) * (cutFee);
        uint256 actualPriceTicketSold = ticketPrice - Per;

        require(
            tickets[msg.sender][_eventId] != 1,
            "You already have a ticket"
        );
        require(tickets[owner_addr][_eventId] == 1, "No ticket available");
        require(token.balanceOf(msg.sender) >= ticketPrice, "Not enough busd"); //checks that enough eth

        require(
            token.transferFrom(
                msg.sender,
                allResell[_resellId].admin,
                actualPriceTicketSold
            ),
            "An error occured, make sure you approve the contract"
        );
        require(
            token.transferFrom(msg.sender, address(this), ticketPrice),
            "An error occured, make sure you approve the contract"
        );

        tickets[owner_addr][_eventId] -= 1; //derement senders ticket value
        tickets[msg.sender][_eventId] += 1; //increment beneficiaries

        console.log("ev", _eventId);

        allResell[_resellId].sold = true;

        //implement
        emit SellTicket(owner_addr, msg.sender, _eventId);
    }

    function hasTicket(uint256 Id, address addr) public view returns (bool) {
        if (tickets[addr][Id] == 1) {
            return true;
        }
        return false;
    }

    function SalesBalance(address _address) external view returns (uint256) {
      require(_address ==  msg.sender, "you are not authorized to view another address earnings");
      return salesBalance[_address];
    }

    function PerBalance() external onlyOwner view returns (uint256) {
      return perBalance;
    }

    function withdrawSaleBalance(uint256 _amount) external {
      require(_amount >= salesBalance[msg.sender], "Insufficient Funds");
      require(
        token.transferFrom(
          address(this),
          msg.sender,
          _amount
        ),
        "An error occured, make sure you approve the contract"
        );
        
        salesBalance[msg.sender] -= _amount;
      emit EventSalesWithdrawal(msg.sender, _amount);
    }


    function withdrawPerBalance(uint256 _amount, address _address) external onlyOwner {
      require(_amount >= perBalance, "Insufficient Funds");
      require(
        token.transfer(
          _address,
          _amount
        ),
        "An error occured, make sure you approve the contract"
        );

      perBalance -= _amount;
    }

    //MODIFIERS
    modifier onlyOwner() {
      require(msg.sender == owner, 'only owner');
      _;
    }

    modifier eventOwner(uint256 _id) {
        require(allEvents[_id].admin == msg.sender);
        _;
    }

    modifier eventExist(uint256 id) {
        require(allEvents[id].enddate != 0, "this event does not exist");
        _;
    }

    modifier eventActive(uint256 id) {
        require(
            block.timestamp < allEvents[id].enddate,
            "event must be active"
        );
        _;
    }

    modifier ticketExist(uint256 id) {
        require(tickets[msg.sender][id] == 1, "must have a ticket");
        _;
    }
}
