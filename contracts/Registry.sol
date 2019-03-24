pragma solidity ^0.5.0;

import "./UserWallet.sol";


/**
 * @title Address Registry
 */
contract AddressRegistry {
    event LogSetAddress(string name, address addr);

    mapping(bytes32 => address) registry;

    modifier isAdmin() {
        require(
            msg.sender == getAddress("admin") || 
            msg.sender == getAddress("owner"),
            "permission-denied"
        );
        _;
    }

    /**
     * @dev get the address from system registry 
     */
    function getAddress(string memory name) public view returns(address) {
        return registry[keccak256(abi.encodePacked(name))];
    }

    /**
     * @dev set new address in system registry 
     */
    function setAddress(string memory name, address addr) public isAdmin {
        registry[keccak256(abi.encodePacked(name))] = addr;
        emit LogSetAddress(name, addr);
    }

}


/**
 * @title Logic Registry
 */
contract LogicRegistry is AddressRegistry {

    event LogEnableDefaultLogic(address logicAddr);
    event LogEnableLogic(address logicAddr);
    event LogDisableLogic(address logicAddr);

    mapping(address => bool) public defaultLogicProxies;
    mapping(address => bool) public logicProxies;

    /**
     * @dev get the boolean of the logic contract
     * @param logicAddr is the logic proxy address
     * @return bool logic proxy is authorised by system admin
     * @return bool logic proxy is default proxy 
     */
    function isLogicAuth(address logicAddr) public view returns (bool, bool) {
        if (defaultLogicProxies[logicAddr]) {
            return (true, true);
        } else if (logicProxies[logicAddr]) {
            return (true, false);
        } else {
            return (false, false);
        }
    }

    /**
     * @dev this sets the default logic proxy to true
     * default proxies mostly contains the logic for withdrawal of assets
     * and can never be false to freely let user withdraw their assets
     * @param logicAddr is the default logic proxy address
     */
    function enableDefaultLogic(address logicAddr) public isAdmin {
        defaultLogicProxies[logicAddr] = true;
        emit LogEnableDefaultLogic(logicAddr);
    }

    /**
     * @dev enable logic proxy address and sets true
     * @param logicAddr is the logic proxy address
     */
    function enableLogic(address logicAddr) public isAdmin {
        logicProxies[logicAddr] = true;
        emit LogEnableLogic(logicAddr);
    }

    /**
     * @dev enable logic proxy address and sets false
     * @param logicAddr is the logic proxy address
     */
    function disableLogic(address logicAddr) public isAdmin {
        logicProxies[logicAddr] = false;
        emit LogDisableLogic(logicAddr);
    }

}


/**
 * @title User Wallet Registry
 */
contract WalletRegistry is LogicRegistry {
    
    event Created(address indexed sender, address indexed owner, address proxy);
    
    mapping(address => InstaWallet) public proxies;
    bool public guardianEnabled; // user guardian mechanism enabled in overall system
    bool public managerEnabled; // user manager mechanism enabled in overall system

    /**
     * @dev deploys a new proxy instance and sets msg.sender as owner of proxy
     */
    function build() public returns (InstaWallet proxy) {
        proxy = build(msg.sender);
    }

    /**
     * @dev deploys a new proxy instance and sets custom owner of proxy
     * Throws if the owner already have a UserWallet
     */
    function build(address owner) public returns (InstaWallet proxy) {
        require(proxies[owner] == InstaWallet(0), "multiple-proxy-per-user-not-allowed");
        proxy = new InstaWallet();
        proxy.setOwnerOnce(owner);
        emit Created(msg.sender, owner, address(proxy));
        proxies[owner] = proxy;
    }

    /**
     * @dev update the proxy record whenever owner changed on any proxy
     * Throws if msg.sender is not a proxy contract created via this contract
     */
    function updateProxyRecord(address currentOwner, address nextOwner) public {
        require(msg.sender == address(proxies[currentOwner]), "invalid-proxy-or-owner");
        proxies[nextOwner] = proxies[currentOwner];
        proxies[currentOwner] = InstaWallet(0);
    }

    /**
     * @dev enable guardian in overall system
     */
    function enableGuardian() public isAdmin {
        guardianEnabled = true;
    }

    /**
     * @dev disable guardian in overall system
     */
    function disableGuardian() public isAdmin {
        guardianEnabled = false;     
    }

    /**
     * @dev enable user manager in overall system
     */
    function enableManager() public isAdmin {
        managerEnabled = true;
    }

    /**
     * @dev disable user manager in overall system
     */
    function disableManager() public isAdmin {
        managerEnabled = false;     
    }

}


contract InstaRegistry is WalletRegistry {

    constructor() public {
        registry[keccak256(abi.encodePacked("admin"))] = msg.sender;
        registry[keccak256(abi.encodePacked("owner"))] = msg.sender;
        build();
    }

}