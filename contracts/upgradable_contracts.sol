pragma solidity ^0.4.0;

import './SafeMath.sol';

/**
 * Here is an example of upgradable contract, consisting of three parts:
 *   - Data contract keeps the resources (data) and is controlled by the Handler contract;
 *   - Handler contract (implements Handler interface) defines operations and provides services. This contract can be upgraded;
 *   - Upgrader contract (optional) deals with the voting mechanism and upgrades the Handler contract. The voters are pre-defined
 *     by the contract owner. 
 *
 * @author	Kaidong Wu (wukd94@pku.edu.cn)
 * @version	0.1.5
 */

/**
 * The example of Data contract.
 * There are three parts in the Data contract:
 *   - Administrator Data: owner’s address, Handler contract’s address and an boolean indicating whether the contract is
 *     initialized or not. 
 *   - Upgrader Data: Upgrader contract’s address, upgrade proposal’s submission timestamp and proposal’s time period. 
 *   - Resource Data: all other resources that the contract needs to keep and mange.
 */
contract DataContract {

	using SafeMath for uint256;

	/** Management data */
	// Owner and Handler contract
	address private owner;
	address private handlerAddr;

	// Getter permitted
	mapping(address => bool) private addressPermissions;

	// Ready?
	bool private valid;

	/** Upgrader data */
	address private upgraderAddr;
	uint256 private proposalBlockNumber;
	uint256 private proposalPeriod;
	/// Upgrading status of the Handler contract
	enum UpgradingStatus {
		// Can be upgraded
		Done,
		// In upgrading
		InProgress,
		// Another proposal is in progress
		Blocked,
		// Expired
		Expired,
		// Original Handler contract error
		Error
	}

	/** Data resources: examples */
	string private exmStr;
	uint256 private exmInt;
	mapping(address => uint256) private exmMapping;
	uint16[] private exmArray;

	struct ExmStruct {
		uint16 key;
		string value;
		uint[] list;
		mapping(uint16 => uint16) map;
	}

	mapping(uint16 => ExmStruct) private exmStructMapping;

	/**
	 * Constructor.
	 * Set the period of upgrading proposal.
	 *
	 * @param	_period	default value of this.proposalPeriod.
	 */
	constructor (uint256 _period) public {
		owner = msg.sender;
		upgraderAddr = address(0);
		proposalBlockNumber = 0;
		proposalPeriod = _period;
		valid = false;
		addressPermissions[msg.sender] = true;
	}

	/** Modifiers */

	/**
	 * Check if msg.sender is the Handler contract. It is used for setters.
	 * If fail, throw PermissionException.
	 */
	modifier onlyHandler {
		require(msg.sender == handlerAddr, "Only Handler contract can call this function!");
		_;
	}

	/**
	 * Check if msg.sender is not permitted to call getters. It is used for getters (if necessary).
	 * If fail, throw GetterPermissionException.
	 */
	modifier allowedAddress {
		require(addressPermissions[msg.sender], "Do not have the permission!");
		_;
	}

	/**
	 * Check if the contract is working.
	 * If fail, throw UninitializationException.
	 */
	modifier ready {
		require(valid, "Data contract has not been initialized!");
		_;
	}

	/** Management functions */

	/**
	 * Initializer. just the Handler contract can call it.
	 * 
	 * @param	_str	default value of this.exmStr.
	 * @param	_int	default value of this.exmInt.
	 * @param	_array	default value of this.exmArray.
	 * 
	 * exception	PermissionException	msg.sender is not the Handler contract.
	 * exception	ReInitializationException	contract has been initialized.
	 *
	 * @return	if the initialization succeeds.
	 */
	function initialize (string _str, uint256 _int, uint16 [] _array) external onlyHandler returns(bool) {
		require(!valid, "Data contarct has been initialized!");
		exmStr = _str;
		exmInt = _int;
		exmArray = _array;
		valid = true;
		return true;
	}

	/**
	 * Set Handler contract for the contract. Owner must set one to initialize the Data contract.
	 * Handler can be set by owner or Upgrader contract.
	 *
	 * @param	_handlerAddr	address of a deployed Handler contract.
	 * @param	_originalHandlerAddr	address of the original Handler contract, only used when an Upgrader contract want to set the Handler contract.
	 *
	 * exception	PermissionException	msg.sender is not the owner nor a registered Upgrader contract.
	 * exception	UpgraderException	Upgrader contract does not provide a right address of the original Handler contract.
	 *
	 * @return	if Handler contract is successfully set.
	 */
	function setHandler (address _handlerAddr, address _originalHandlerAddr) external returns(bool) {
		// If Handler contract can be just upgraded by Upgrader contract except the first one, use this requirement.
		require((!valid && msg.sender == owner) || msg.sender == upgraderAddr, "Permission error!");
		// // The other version of requirement, owner can always upgrade the Handler contract as well.
		// require(msg.sender == owner || msg.sender == upgraderAddr, "Permission error!");

		// Check if the Upgrader contract is right.
		require(handlerAddr == address(0) || handlerAddr == _originalHandlerAddr, "Upgrader contract error!");

		// Allow Handler contract to use getters, and remove original Handler contract's permission.
		addressPermissions[_handlerAddr] = true;
		if (handlerAddr != address(0)) {
			addressPermissions[handlerAddr] = false;
		}
		handlerAddr = _handlerAddr;
		upgraderAddr = address(0);
		return true;
	}

	/** Upgrader contract functions */

	/**
	 * Register an Upgrader contract in the contract.
	 * If a proposal has not been accepted until proposalBlockNumber + proposalPeriod, it can be replaced by a new one.
	 *
	 * @param	_upgraderAddr	address of a deployed Upgrader contract.
	 *
	 * exception	PermissionException	msg.sender is not the owner.
	 * exception	UpgraderConflictException	Another Upgrader contract is working.
	 *
	 * @return	if Upgrader contract is successfully registed.
	 */
	function startUpgrading (address _upgraderAddr) public returns(bool) {
		require(msg.sender == owner, "Just owner can start upgrading Handler contract!");
		require(upgraderAddr == address(0) ||
			proposalBlockNumber.add(proposalPeriod) < block.number,
			"Another proposal is in the progress!");
		upgraderAddr = _upgraderAddr;
		proposalBlockNumber = block.number;
		return true;
	}

	/**
	 * Getter of proposalPeriod.
	 *
	 * exception	UninitializationException	uninitialized contract.
	 * exception	GetterPermissionException	msg.sender is not permitted to call the getter.
	 *
	 * @return	this.proposalPeriod.
	 */
	function getProposalPeriod () public view ready allowedAddress returns(uint256) {
		return proposalPeriod;
	}

	/**
	 * Setter of proposalPeriod.
	 *
	 * @param	_proposalPeriod	new value of this.proposalPeriod.
	 *
	 * exception	UninitializationException	uninitialized contract.
	 * exception	PermissionException	msg.sender is not the owner.
	 *
	 * @return	if this.proposalPeriod is successfully set.
	 */
	function setProposalPeriod (uint256 _proposalPeriod) public ready returns(bool) {
		require(msg.sender == owner, "Permission error!");
		proposalPeriod = _proposalPeriod;
		return true;
	}

	/**
	 * Return upgrading status for Upgrader contracts.
	 *
	 * @param	_originalHandlerAddr	address of the original Handler contract.
	 *
	 * exception	UninitializationException	uninitialized contract.
	 *
	 * @return	Handler contract's upgrading status.
	 */
	function canBeUpgraded (address _originalHandlerAddr) external view ready returns(UpgradingStatus) {
		if (handlerAddr != _originalHandlerAddr) {
			return UpgradingStatus.Error;
		}
		if (upgraderAddr == msg.sender) {
			if (proposalBlockNumber.add(proposalPeriod) < block.number) {
				return UpgradingStatus.Expired;
			} else {
				return UpgradingStatus.InProgress;
			}
		} else {
			if (proposalBlockNumber.add(proposalPeriod) < block.number) {
				return UpgradingStatus.Done;
			} else {
				return UpgradingStatus.Blocked;
			}
		}
	}

	/**
	 * Check if the contract has been initialized.
	 *
	 * @return	if the contract has been initialized.
	 */
	function live () external view returns(bool) {
		return valid;
	}

	/** Getters and setters of data resources: examples */
	function getExmStr () external view ready allowedAddress returns(string) {
		return exmStr;
	}

	function setExmStr (string _str) external ready onlyHandler returns(bool) {
		exmStr = _str;
		return true;
	}

	function getExmInt () external view ready allowedAddress returns(uint256) {
		return exmInt;
	}

	function setExmInt (uint256 _int) external ready onlyHandler returns(bool) {
		exmInt = _int;
		return true;
	}

	function getExmMappingValue (address _key) external view ready allowedAddress returns(uint256) {
		return exmMapping[_key];
	}

	function setExmMappingValue (address _key, uint256 _value) external ready onlyHandler returns(bool) {
		exmMapping[_key] = _value;
		return true;
	}

	function deleteExmMappingValue (address _key) external ready onlyHandler returns(bool) {
		delete exmMapping[_key];
		return true;
	}

	function getExmArray () external view ready allowedAddress returns(uint16[]) {
		return exmArray;
	}

	function addElementInExmArray (uint16 _e) external ready onlyHandler returns(bool) {
		exmArray.push(_e);
		return true;
	}

	function deleteElementByIndex (uint256 _index) external ready onlyHandler returns(bool) {
		require(exmArray.length > _index, "Index error!");
		delete exmArray[_index];
		return true;
	}

	function deleteElementByEle (uint16 _e) external ready onlyHandler returns(bool) {
		uint i = 0;
		while (i < exmArray.length && exmArray[i] != _e) {
			i++;
		}
		if (i != exmArray.length) {
			delete exmArray[i];
		}
		return true;
	}

	function deleteAllElementsByEle (uint16 _e) external ready onlyHandler returns(bool) {
		for (uint i = exmArray.length; i > 0; i--) {
			if (exmArray[i-1] == _e) {
				delete exmArray[i-1];
			}
		}
		return true;
	}

	function getExmStruct (uint16 _key) external view ready allowedAddress returns(uint16, string, uint256[]) {
		ExmStruct storage tmp = exmStructMapping[_key];
		return (tmp.key, tmp.value, tmp.list);
	}

	function setExmStruct (uint16 _k, uint16 _key, string _value, uint256[] _list) external ready onlyHandler returns(bool) {
			ExmStruct storage tmp = exmStructMapping[_k];
			tmp.key = _key;
			tmp.value = _value;
			tmp.list = _list;
			return true;
	}

	function getMapValueInExmStruct (uint16 _k, uint16 _key) external view ready allowedAddress returns(uint16) {
		return exmStructMapping[_k].map[_key];
	}

	function setMapInExmStruct (uint16 _k, uint16 _key, uint16 _value) external ready onlyHandler returns(bool) {
		exmStructMapping[_k].map[_key] = _value;
		return true;
	}

	function deleteMapInExmStruct (uint16 _k, uint16 _key) external ready onlyHandler returns(bool) {
		delete exmStructMapping[_k].map[_key];
		return true;
	}
}

/**
 * Handler interface.
 * Handler defines bussiness related functions.
 * Use the interface to ensure that your external services are always supported.
 * Because of function live(), we design IHandler as an abstract contract
 *   rather than a true interface.
 *
 * Handler is deployed as following steps:
 *   1. Deploy Data contract;
 *   2. Deploy a Handler contract at a given address specified in the data
 *      contract;
 *   3. Register the Handler contract address by calling setHandler() in the
 *      Data contract, or use an Upgrader contract to switch the handler
 *      contract, which requires that Data contract is initialized;
 *   4. Initialize Data contract if haven’t done it already.
 */
contract IHandler {

	/**
	 * Initialize the data contarct.
	 *
	 * @param	_str	value of exmStr of Data contract.
	 * @param	_int	value of exmInt of Data contract.
	 * @param	_array	value of exmArray of Data contract.
	 */
	function initialize (string _str, uint256 _int, uint16 [] _array) public;

	/**
	 * Register Upgrader contract address.
	 *
	 * @param	_upgraderAddr	address of the Upgrader contract.
	 */
	function prepare2BUpgraded (address _upgraderAddr) external;

	/**
	 * Upgrader contract calls this to check if it is registered.
	 *
	 * @return	if the Upgrader contract is registered.
	 */
	function isPrepared4Upgrading () external view returns(bool);

	/**
	 * Handler has been upgraded so the original one has to self-destruct.
	 */
	function done() external;

	/**
	 * Check if the Handler contract is a working Handler contract.
	 * It is used to prove the contract is a Handler contract.
	 *
	 * @return	always true.
	 */
	function live() external pure returns(bool) {
		return true;
	}

	/** Functions: define functions here */
	// Some example functions.
	function a () view external returns(string);
	function b (string _str) external;

	/** Events: add events here */
	// Some example events.
	event Create(address contractAddress);
}

/**
 * An example implementation of Handler contract interface
 */
contract Handler is IHandler {

	using SafeMath for uint256;

	/** Management data */
	// Owner.
	address private owner;

	// Data conract.
	DataContract private data;

	// Cache of data.live().
	bool private valid;

	/** Upgrader data */
	address private upgraderAddr;

	/**
	 * Constructor.
	 *
	 * @param	_dataAddr	address of the Data contract.
	 */
	constructor (address _dataAddr) public {
		owner = msg.sender;
		data = DataContract(_dataAddr);
		valid = data.live();
	}

	/**
	 * Initialize the data contarct.
	 *
	 * @param	_str	value of exmStr of Data contract.
	 * @param	_int	value of exmInt of Data contract.
	 * @param	_array	value of exmArray of Data contract.
	 *
	 * exception	PermissionException	msg.sender is not the owner.
	 * exception	ReInitializationException	Data contract has been initialized.
	 *
	 * event	Create	service is created.
	 */
	function initialize (string _str, uint256 _int, uint16 [] _array) public {
		require(msg.sender == owner, "Permission error!");
		require(data.initialize(_str, _int, _array),
			"Initialization failed! Check if the Data contract has been initialized!");
		valid = true;
		// Example event is used.
		emit Create(address(this));
	}

	/**
	 * Register upgrader address.
	 *
	 * @param	_upgraderAddr	address of the upgrader.
	 *
	 * exception	PermissionException	msg.sender is not the owner.
	 */
	function prepare2BUpgraded (address _upgraderAddr) external {
		require(msg.sender == owner, "Permission error!");
		upgraderAddr = _upgraderAddr;
	}

	/**
	 * Upgrader calls this to check if it is registered.
	 *
	 * @return	if the upgrader is registered.
	 */
	function isPrepared4Upgrading () external view returns(bool) {
		return upgraderAddr == msg.sender;
	}

	/**
	 * Handler has been upgraded so the original one has to self-destruct.
	 *
	 * exception	PermissionException	msg.sender is not the owner nor the upgrader.
	 */
	function done() external{
		require(msg.sender == owner || msg.sender == upgraderAddr, "Permission error!");
		selfdestruct(owner);
	}

	/** Functions */
	// Example functons.
	function a () view external returns(string) {
		return data.getExmStr();
	}

	function b (string _str) external {
		data.setExmStr(_str);
	}
}

/**
 * Handler upgrader. The upgrader works in following steps:
 *   1. Verify the Data contract, its corresponding Handler contract and the new Handler contract have all been deployed;
 *   2. Deploy an Upgrader contract using Data contract address, previous Handler contract address and new Handler contract 
 *      address;
 *   3. Register upgrader address in the new Handler contract first, then the original hander and finally the Data contract;
 *   4. Call startProposal() to start the voting process;
 *   5. Call getResolution() before the expiration;
 *   6. Upgrade succeed or proposal is expired.
 *    * Function done() can be called at any time to let upgrader destruct itself.
 *    * Function status() can be called at any time to show caller status of the upgrader.
 */
contract Upgrader {

	using SafeMath for uint256;

	address private owner;

	// Data contract
	DataContract public data;
	// Original Handler contract
	IHandler public originalHandler;
	// New Handler contract
	address public newHandlerAddr;

	/** Marker */
	enum UpgraderStatus {
		Preparing,
		Voting,
		Success,
		Expired,
		End
	}
	UpgraderStatus public status;

	/** Voting mechanism related */
	uint256 private percentage;
	mapping(address => bool) public voting;
	mapping(address => bool) private voterRegistered;
	uint256 private numOfVoters = 0;
	uint256 private numOfAgreements = 0;

	/**
	 * Check if the proposal is expired.
	 * If so, contract would be marked as expired.
	 *
	 * exception	PreparingUpgraderException	proposal has not been started.
	 * exception	ReupgradingException	upgrading has been done.
	 * exception	ExpirationException	proposal is expired.
	 */
	modifier notExpired {
		require(status != UpgraderStatus.Preparing, "Invalid proposal!");
		require(status != UpgraderStatus.Success, "Upgrading has been done!");
		require(status != UpgraderStatus.Expired, "Proposal is expired!");
		if (data.canBeUpgraded(address(originalHandler)) != DataContract.UpgradingStatus.InProgress) {
			status = UpgraderStatus.Expired;
			require(false, "Proposal is expired!");
		}
		_;
	}

	/**
	 * Constructor.
	 *
	 * @param	_dataAddr	address of the Data contract.
	 * @param	_originalAddr	address of the original Handler contract.
	 * @param	_newAddr	address of the new Handler contract.
	 * @param	_voters	addresses of voters.
	 * @param	_percentage	value of this.percentage.
	 *
	 * exception	UninitializationException	_dataAddr does not belong to a deployed Data contract having been initialization.
	 * exception	UpgraderConflictException	another upgrader is working.
	 * exception	InvalidHandlerException	_originalAddr or _newAddr does not belong to a deployed Handler contract.
	 */
	constructor (address _dataAddr, address _originalAddr, address _newAddr, address[] _voters, uint256 _percentage) public {
		// Check if the Data contract can be upgarded.
		data = DataContract(_dataAddr);
		require(data.live(),
			"Can not upgrade Handler contract for an uninitialized Data contract!");
		require(data.canBeUpgraded(_originalAddr) == DataContract.UpgradingStatus.Done,
			"Can not upgrade Handler contract!");

		// Check if the Handler contracts are valid.
		originalHandler = IHandler(_originalAddr);
		require(originalHandler.live(), "Invlid original Handler contract!");
		newHandlerAddr = _newAddr;
		require(IHandler(_newAddr).live(), "Invlid new Handler contract!");

		owner = msg.sender;
		_addVoters(_voters);
		_setPercentage(_percentage);

		// Mark the contract as preparing.
		status = UpgraderStatus.Preparing;
	}

	/**
	 * Start voting.
	 * Upgrader must check if Data contract and 2 Handler contracts are ok.
	 *
	 * exception	RestartingException	proposal has been already started.
	 * exception	PermissionException	msg.sender is not the owner.
	 * exception	UpgraderConflictException	another upgrader is working.
	 * exception	NoPreparationException	original or new Handler contract is not prepared.
	 */
	function startProposal () external {
	 require(status == UpgraderStatus.Preparing, "Proposal has been already started!");
		require(msg.sender == owner, "Permission error!");
		// Check if contracts are prepared.
		require(data.canBeUpgraded(address(originalHandler)) == DataContract.UpgradingStatus.InProgress,
			"Have not registered upgrader in Data contract!");
		require(originalHandler.isPrepared4Upgrading(),
			"Have not registered upgrader in original Handler contract!");
		require(IHandler(newHandlerAddr).isPrepared4Upgrading(),
			"Have not registered upgrader in new Handler contract!");

		// Mark the contract as voting.
		status = UpgraderStatus.Voting;
	}

	/**
	 * Add unique voters.
	 * If expired, self-destruct.
	 *
	 * @param	_voters	addresses of voters.
	 *
	 * exception	PermissionException	msg.sender is not the owner.
	 * 
	 * see  this.notExpired
	 */
	function addVoters (address[] _voters) public notExpired {
		require(msg.sender == owner, "Permission error!");
		_addVoters(_voters);
	}

	function _addVoters (address[] _voters) internal {
		for (uint256 i = 0; i < _voters.length; i++) {
			if (!voterRegistered[_voters[i]]) {
				voterRegistered[_voters[i]] = true;
				numOfVoters++;
			}
		}
	}

	/**
	 * Vote.
	 * If expired, self-destruct.
	 *
	 * @param	_choose	if the voter agrees with the proposal.
	 *
	 * exception	PermissionException	msg.sender is not a voter.
	 * 
	 * see  this.notExpired
	 */
	function vote (bool _choose) external notExpired {
		require(voterRegistered[msg.sender], "Do not have the permission!");
		if (voting[msg.sender] != _choose) {
			if (_choose) {
				numOfAgreements++;
			} else {
				numOfAgreements--;
			}
			voting[msg.sender] = _choose;
		}
	}

	/**
	 * Set percentage.
	 * If percentage is over 100, it will be fixed automatically.
	 *
	 * @param	_percentage	value of this.percentage.
	 *
	 * exception	PermissionException	msg.sender is not the owner.
	 * 
	 * see  this.notExpired
	 */
	function setPercentage(uint256 _percentage) external notExpired {
		require(msg.sender == owner, "Permission error!");
		_setPercentage(_percentage);
	}

	function _setPercentage(uint256 _percentage) internal {
		percentage = _percentage;
		if (percentage > 100) {
			percentage = 100;
		}
	}

	/**
	 * Anyone can try to get resolution.
	 * If voters get consensus, upgrade the Handler contract.
	 * If expired, self-destruct.
	 * Otherwise, do nothing.
	 *
	 * exception	PreparingUpgraderException	proposal has not been started.
	 *
	 * @return	status of proposal.
	 * 
	 * see  this.notExpired
	 */
	function getResolution() external notExpired returns(UpgraderStatus) {
		if (numOfAgreements > numOfVoters.mul(percentage).div(100)) {
			data.setHandler(newHandlerAddr, address(originalHandler));
			originalHandler.done();
			status = UpgraderStatus.Success;
		}
		return status;
	}

	/**
	 * Destruct itself.
	 *
	 * exception	PermissionException	msg.sender is not the owner.
	 */
	function done() external {
		require(msg.sender == owner, "Permission error!");
		selfdestruct(owner);
	}
}
