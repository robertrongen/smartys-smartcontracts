pragma solidity>0.4.99<0.6.0;

/// @author Robert Rongen for Smartys
/// @title Order contract for temperature monitored transport

import "@openzeppelin/contracts/token/ERC777/IERC777.sol";   
import "@openzeppelin/contracts/token/ERC777/IERC777Recipient.sol";   
import "@openzeppelin/contracts/token/ERC777/IERC777Sender.sol";   
import "@openzeppelin/contracts/introspection/IERC1820Registry.sol";
import "@openzeppelin/contracts/introspection/ERC1820Implementer.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract OrderContract is IERC777Recipient, IERC777Sender, ERC1820Implementer {

    IERC1820Registry private _erc1820 = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);
    bytes32 constant private TOKENS_RECIPIENT_INTERFACE_HASH = keccak256("ERC777TokensRecipient");
    bytes32 constant public TOKENS_SENDER_INTERFACE_HASH = keccak256("ERC777TokensSender");
    IERC777 public smartysToken;
    using SafeMath for uint256;

    /// @dev Link contract to Smartys token.
    /// @dev For a smart contract to receive ERC777 tokens, it needs to implement the tokensReceived hook and register with ERC1820 registry as an ERC777TokensRecipient
    constructor (IERC777 tokenAddress) public {
        smartysToken = IERC777(tokenAddress);
        _erc1820.setInterfaceImplementer(address(this), TOKENS_RECIPIENT_INTERFACE_HASH, address(this));
    }

    function senderFor(address account) public {
        _registerInterfaceForAddress(TOKENS_SENDER_INTERFACE_HASH, account);
    }


	/// @dev  Define contract parameters.
	/// @dev  Struct and mapping tutorial: https://coursetro.com/posts/code/102/Solidity-Mappings-&-Structs-Tutorial.
	/// @param OrderData Array of dynamic size to capture the contract data for a specific transport.
	/// @param client Sends the order data and pays the order
	/// @param supplier Receives the order payment
	/// @param productName Ordered product
	/// @param productAmount Amount of ordered product
	/// @param goodsCost Tokens to be paid for the product
	/// @param transportCost Tokens to be paid for the transport
	/// @param temperatureDeposit Tokens to be paid for the temperature deposit
    uint256 orderID;
    bool orderPaid = false;
    struct OrderData {
        string sessionUuid;
        address client;
        address supplier;
        string productName;
        uint256 productAmount;
        uint256 goodsCost;
        uint256 transportCost;
        uint256 temperatureDeposit;
        bool orderPaid;
    }

    mapping (uint256 => OrderData) public orders;
    uint[] public orderIDs;

    /// @dev Helper functions

    function bytesToUint(bytes memory userData) public pure returns (uint256 number) {
        number=0;
        for(uint i=0;i<userData.length;i++){
            number *= 256;
            number += uint(uint8(userData[i]));
        }
    }

    function uintToBytes(uint256 x) public pure returns (bytes memory b) {
        b = new bytes(32);
        for (uint i = 0; i < 32; i++) {
            b[i] = byte(uint8(x / (2**(8*(31 - i))))); 
        }
    }

    event DoneStuff(address operator, address from, address to, uint256 amount, bytes userData, bytes operatorData);
    function tokensToSend(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData
    ) public {
        emit DoneStuff(operator, from, to, amount, userData, operatorData);
    }


    /// @dev Order functions

    /// @notice Register order parameters and store in struct
    /// @return	orderID that is increased by 1 for every new order registered
    event newOrder(uint256 orderID);
    function defineOrder(
        string memory _sessionUuid,
        address _supplier_address,
        string memory _productName,
        uint256 _productAmount,
        uint256 _goodsCost,
        uint256 _transportCost,
        uint256 _temperatureDeposit
    )
    public
    returns(uint256) {
        orderID++;
        orders[orderID].sessionUuid = _sessionUuid;
        orders[orderID].client = msg.sender;
        orders[orderID].supplier = _supplier_address;
        orders[orderID].productName = _productName;
        orders[orderID].productAmount = _productAmount;
        orders[orderID].goodsCost = _goodsCost;
        orders[orderID].transportCost = _transportCost;
        orders[orderID].temperatureDeposit = _temperatureDeposit;
        orderIDs.push(orderID) -1;
        
        emit newOrder(orderID);
    }

    function getorderIDs() view public returns(uint256[] memory){
        return orderIDs;
    }

    event paymentReceived(string text, uint orderID);
    /// @dev Code from https://forum.openzeppelin.com/t/simple-erc777-token-example/746
    function tokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata userData,
        bytes calldata operatorData
    ) external {
        require(msg.sender == address(smartysToken), "Simple777Recipient: Invalid token");
        emit DoneStuff(operator, from, to, amount, userData, operatorData);

        uint256 _orderID = bytesToUint(userData);
        emit paymentReceived("orderID", _orderID);

        registerPayment(_orderID, from, amount);
    }


    /// @dev Verify payment conditions and register payment
    event clientPaidOrder(uint256 _orderID, bool _orderPaid);
    function registerPayment(
        uint256 _orderID,
        address _from,
        uint256 _amountReceived
    ) public /* onlyBy(client) */ {
        require(orders[_orderID].orderPaid != true, "Order is already paid.");
        if (_from == orders[_orderID].client) {
            uint256 _totalAmount = orders[_orderID].goodsCost + orders[_orderID].transportCost;

            require(_amountReceived == _totalAmount, "Amount does not equal transport bond set for this contract.");
            orders[_orderID].orderPaid = true;
            emit clientPaidOrder(_orderID, orders[_orderID].orderPaid);
        
            address _supplier_address = orders[orderID].supplier;
            bytes memory userData = uintToBytes(_orderID);
            smartysToken.send(_supplier_address, _totalAmount, userData); 

        } else {
            revert("Escrow not paid by client");
        }
    }

}
