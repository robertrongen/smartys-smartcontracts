pragma experimental ABIEncoderV2; // supports structs and arbitrarily nested arrays
pragma solidity>0.4.99<0.6.0;

/// @author Robert Rongen for Smartys
/// @title Escrow contract for temperature monitored transport

import "@openzeppelin/contracts/token/ERC777/IERC777.sol";   // to send and receive ERC777 tokens
import "@openzeppelin/contracts/token/ERC777/IERC777Recipient.sol";   // to receive ERC777 tokens
import "@openzeppelin/contracts/token/ERC777/IERC777Sender.sol";   // to send ERC777 tokens
import "@openzeppelin/contracts/introspection/IERC1820Registry.sol";
import "@openzeppelin/contracts/introspection/ERC1820Implementer.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

/*
https://kauri.io/article/6816abb97f104026a946ba65968eefe6/openzeppelin-part-2:-access-control
import "openzeppelin-solidity/contracts/access/Roles.sol";
*/

/// @dev TransportContracts takes Smartys token in escrow from Client and Carrier.
/// @dev Both can claim the tokens if they send a valid signed message.
contract TransportContract is IERC777Recipient, IERC777Sender, ERC1820Implementer {

    IERC1820Registry private _erc1820 = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);
    bytes32 constant private TOKENS_RECIPIENT_INTERFACE_HASH = keccak256("ERC777TokensRecipient");
    bytes32 constant public TOKENS_SENDER_INTERFACE_HASH = keccak256("ERC777TokensSender");
    IERC777 public smartysToken;
    /// @dev Link contract to Smartys token.
    /// @dev For a smart contract to receive ERC777 tokens, it needs to implement the tokensReceived hook and register with ERC1820 registry as an ERC777TokensRecipient
    constructor (IERC777 tokenAddress) public {
        smartysToken = IERC777(tokenAddress);
        _erc1820.setInterfaceImplementer(address(this), TOKENS_RECIPIENT_INTERFACE_HASH, address(this));
    }

    function senderFor(address account) public {
        _registerInterfaceForAddress(TOKENS_SENDER_INTERFACE_HASH, account);
    }

    using SafeMath for uint256;

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

    /// @dev  Define contract parameters.
    /// @param transportID Contract nonce to prevent replay attack (make sure escrow can only be claimed successfully once).
    /// @param sessionUuid Hex representation of Session UUID.
    /// @param orderID NEW. Order ID for the transported goods.
	/// @param supplier Sets the transport data.
    /// @param client Stakes the transportDeposit.
    /// @param carrier Stakes the temperatureDeposit.
    /// @param transportDepositPaid Renamed from clientEscrowPaid. True if client has send the tokens for the transportDeposit.
    /// @param temperatureDepositPaid Renamed from carrierEscrowPaid. True if carrier has send the tokens for the temperatureDeposit.
	/// @param goodsReceived True when valid signed message by Client is received.
	/// @param transportEnded Set to true at the end, disallows any change. By default initialized to `false`.
	/// @param TransportData Array of dynamic size to capture the contract data for a specific transport.
	/// @param depositTempLow NEW. Low temperature limit for transport, is linked to temperatureDeposit.
	/// @param depositTempHigh High temperature for transport, is linked to temperatureDeposit.
	/// @param transportDeposit Escrowed by Carrier, can be claimed by Client if maxtemp > depositTempHigh.
	/// @param temperatureDeposit Escrowed by Client, can be claimed by Carrier upon goodsReceived.
	/// @param transportResult Array of dynamic size to capture the contract results for a specific transport.
	/// @param minTemp NEW. Minimum temperature measured during the transport.
	/// @param maxTemp Maximum temperature measured during the transport.
	/// @param clientOk NEW. Captures transport received message form client.
	/// @param sensorID NEW. ID of the sensor that captures the temperature during transport.
	/// @param sensorRegistered NEW. Confirms registration of the sensor.
    uint256 public transportID;
    bool transportDepositPaid = false;
    bool temperatureDepositPaid = false;
    bool goodsReceived = false;
    // bool sensorRegistered = false;
    bool transportEnded = false;
    bool clientQuits = false;
    bool supplierQuits = false;
    bool carrierQuits = false;

    struct TransportSteps {
        bool transportDepositPaid;
        bool temperatureDepositPaid;
        bool goodsReceived;
        bool transportEnded;
        bool sensorRegistered;
        bool clientQuits;
        bool supplierQuits;
        bool carrierQuits;
    }

    struct TransportConditions {
        int depositTempLow;
        int depositTempHigh;
        uint256 transportDeposit;
        uint256 temperatureDeposit;
        int minTemp;
        int maxTemp;
    }

    struct TransportData {
        string sessionUuid;
        uint256 orderID;
        address client;
        address supplier;
        address carrier;
        string sensorID; 
        TransportConditions conditions;
        TransportSteps step;
    }
    mapping (uint256 => TransportData) public transports;
    uint256[] public transportIDs;

    /// @notice Register transport parameters and store in struct
    /// @return	TransportID that is increased by 1 for every new transport registered
    event newTransport(uint256 transportID);
    function defineTransport(
        string memory _sessionUuid,
        uint256 _orderID,
        address _client_address,
        address _carrier_address,
        int _depositTempLow,
        int _depositTempHigh,
        uint256 _transportDeposit,
        uint256 _temperatureDeposit
    )
    public
    returns(uint256) {
        require(_depositTempHigh - _depositTempLow >= 1, "Invalid condition: TempHigh is lower than TempLow");
        transportID++;
        transports[transportID].sessionUuid = _sessionUuid;
        transports[transportID].orderID = _orderID;
        transports[transportID].supplier = msg.sender;
        transports[transportID].client = _client_address;
        transports[transportID].carrier = _carrier_address;
        transports[transportID].conditions.depositTempLow = _depositTempLow;
        transports[transportID].conditions.depositTempHigh = _depositTempHigh;
        transports[transportID].conditions.transportDeposit = _transportDeposit;
        transports[transportID].conditions.temperatureDeposit = _temperatureDeposit;
        transportIDs.push(transportID) -1;
        
        emit newTransport(transportID);
    }

    function getTransportIDs() view public returns(uint256[] memory){
        return transportIDs;
    }

    
    event orderDeposited(string text, uint transportID);
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

        uint256 _transportID = bytesToUint(userData);
        emit orderDeposited("transportID", _transportID);

        registerDeposit(_transportID, from, amount);
    }


    event supplierDeposited(uint256 _transportID, bool _supplierDeposited);
    event carrierDeposited(uint256 _transportID, bool _carrierDeposited);
    function registerDeposit(uint256 _transportID, address _from, uint256 _amountReceived)  public {

        // check conditions
        require(transports[_transportID].step.transportEnded != true, "Order is already ended.");
 
        if (_from == transports[_transportID].supplier) {
            require(transports[_transportID].step.transportDepositPaid != true, "Deposit is already paid.");
            require(_amountReceived == transports[_transportID].conditions.transportDeposit, "Amount does not equal transport deposit set for this contract.");
            // register deposit
            transports[_transportID].step.transportDepositPaid = true;
            emit supplierDeposited(_transportID, transports[_transportID].step.transportDepositPaid);


        } else if (_from == transports[_transportID].carrier) {
            require(transports[_transportID].step.temperatureDepositPaid != true, "Deposit is already paid.");
            require(_amountReceived == transports[_transportID].conditions.temperatureDeposit, "Amount does not equal temperature deposit set for this contract.");
            // register deposit
            transports[_transportID].step.temperatureDepositPaid = true;
            emit carrierDeposited(_transportID, transports[_transportID].step.temperatureDepositPaid);

        } else {
            revert("Deposit not send by supplier or carrier");
        }

    }

    event SensorRegistered(bool _transportEnded);
    function quitTransport(uint256 _transportID, string memory _sensorID) internal {
        transports[_transportID].sensorID = _sensorID;
        transports[_transportID].step.sensorRegistered = true;
        emit SensorRegistered(transports[_transportID].step.sensorRegistered);
    }

    event TransportEnded(bool _transportEnded);
    function setTransportResults(bytes memory userData, int _minTemp, int _maxTemp) public {
        uint256 _transportID = bytesToUint(userData);
        address _client = transports[_transportID].client;
        address _carrier = transports[_transportID].carrier;
        uint256 _totalDeposit;
        int minTemp = _minTemp;
        int maxTemp = _maxTemp;

        require(msg.sender == transports[_transportID].client, "Only client can call this function.");
        require(transports[_transportID].step.goodsReceived == false, "Transport result already executed.");
        require(transports[_transportID].step.transportDepositPaid == true, "Escrow not paid by client for this transport.");
        require(transports[_transportID].step.temperatureDepositPaid == true, "Escrow not paid by carrier for this transport.");

        transports[_transportID].conditions.minTemp = minTemp;
        transports[_transportID].conditions.maxTemp = maxTemp;
        transports[_transportID].step.goodsReceived = true;

        if (_maxTemp < transports[_transportID].conditions.depositTempHigh && _minTemp > transports[_transportID].conditions.depositTempLow) {
            // Scenario green
            _totalDeposit = transports[_transportID].conditions.transportDeposit.add(transports[_transportID].conditions.temperatureDeposit);
            smartysToken.send(_carrier, _totalDeposit, userData);

        } else {
            // Scenario red
            smartysToken.send(_carrier, transports[_transportID].conditions.transportDeposit, userData);
            smartysToken.send(_client, transports[_transportID].conditions.temperatureDeposit, userData);
        }

        transports[_transportID].step.transportEnded = true;

        emit TransportEnded(transports[_transportID].step.transportEnded);
    }

    function quitTransport(uint256 _transportID) internal {
        address _supplier;
        address _carrier;
        bytes memory userData = uintToBytes(_transportID);
        _supplier = transports[_transportID].supplier;
        _carrier = transports[_transportID].carrier;
 
        smartysToken.send(_carrier, transports[_transportID].conditions.temperatureDeposit, userData);
        smartysToken.send(_supplier, transports[_transportID].conditions.transportDeposit, userData);
        transports[_transportID].step.transportEnded = true;
        emit TransportEnded(transports[_transportID].step.transportEnded);
    }

    function clientQuitsTransport(uint256 _transportID) public {
        require(msg.sender == transports[_transportID].client, "Only client can call this function.");
        transports[_transportID].step.clientQuits = true;
        if (
            (transports[_transportID].step.carrierQuits == true
            || transports[_transportID].step.supplierQuits == true
            ) && transports[_transportID].step.transportEnded != true
        ) {
        quitTransport(_transportID);
        }
    }

    function carrierQuitsTransport(uint256 _transportID) public {
        require(msg.sender == transports[_transportID].carrier, "Only carrier can call this function.");
        transports[_transportID].step.carrierQuits = true;
        if (
                (transports[_transportID].step.clientQuits == true
                || transports[_transportID].step.supplierQuits == true
                ) && transports[_transportID].step.transportEnded != true
        ) {
        quitTransport(_transportID);
        }
    }

    function supplierQuitsTransport(uint256 _transportID) public {
        require(msg.sender == transports[_transportID].supplier, "Only supplier can call this function.");
        transports[_transportID].step.supplierQuits = true;
        if (
                (transports[_transportID].step.clientQuits == true
                || transports[_transportID].step.carrierQuits == true
                ) && transports[_transportID].step.transportEnded != true
        ) {
            quitTransport(_transportID);
        }
    }

}
