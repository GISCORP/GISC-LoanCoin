pragma solidity ^0.4.11;
import "zeppelin-solidity/contracts/token/StandardToken.sol";
import "zeppelin-solidity/contracts/SafeMath.sol";

contract GISCToken is StandardToken {
	using SafeMath for uint256;
	
	// keccak256 hash of hidden cap
	string public constant HIDDEN_CAP = "0xd22f19d54193ff5e08e7ba88c8e52ec1b9fc8d4e0cf177e1be8a764fa5b375fa";
	
	// Events
	event CreatedGISC(address indexed _creator, uint256 _amountOfGISC);
	event GISCRefundedForWei(address indexed _refunder, uint256 _amountOfWei);
	
	// Token data
	string public constant name = “GISC Loancoin Token";
	string public constant symbol = “GIS”;
	uint256 public constant decimals = 18;  // Since our decimals equals the number of wei per ether, we needn't multiply sent values when converting between GISC and ETH.
	string public version = "1.0";
	
	// Addresses and contracts
	address public executor;
	address public devETHDestination;
	address public devGISCDestination;
	address public reserveGISCDestination;
	
	// Sale data
	bool public saleHasEnded;
	bool public minCapReached;
	bool public allowRefund;
	mapping (address => uint256) public ETHContributed;
	uint256 public totalETHRaised;
	uint256 public saleStartBlock;
	uint256 public saleEndBlock;
	uint256 public saleFirstEarlyBirdEndBlock;
	uint256 public saleSecondEarlyBirdEndBlock;
	uint256 public constant DEV_PORTION = 20;  // In percentage
	uint256 public constant RESERVE_PORTION = 1;  // In percentage
	uint256 public constant ADDITIONAL_PORTION = DEV_PORTION + RESERVE_PORTION;
	uint256 public constant SECURITY_ETHER_CAP = 1000000 ether;
	uint256 public constant GISC_PER_ETH_BASE_RATE = 250;  // 200 GISC = 1 ETH during normal part of token sale
	uint256 public constant GISC_PER_ETH_FIRST_EARLY_BIRD_RATE = 325;
	uint256 public constant GISC_PER_ETH_SECOND_EARLY_BIRD_RATE = 300;
	uint256 public constant GISC_PER_ETH_THIRD_EARLY_BIRD_RATE = 287;
        uint256 public constant GISC_PER_ETH_FOURTH_EARLY_BIRD_RATE = 275;

	function GISCToken(
		address _devETHDestination,
		address _devGISCDestination,
		address _reserveGISCDestination,
		uint256 _saleStartBlock,
		uint256 _saleEndBlock
	) {
		// Reject on invalid ETH destination address or GISC destination address
		if (_devETHDestination == address(0x0)) throw;
		if (_devGISCDestination == address(0x0)) throw;
		if (_reserveGISCDestination == address(0x0)) throw;
		// Reject if sale ends before the current block
		if (_saleEndBlock <= block.number) throw;
		// Reject if the sale end time is less than the sale start time
		if (_saleEndBlock <= _saleStartBlock) throw;

		executor = msg.sender;
		saleHasEnded = false;
		minCapReached = false;
		allowRefund = false;
		devETHDestination = _devETHDestination;
		devGISCDestination = _devGISCDestination;
		reserveGISCDestination = _reserveGISCDestination;
		totalETHRaised = 0;
		saleStartBlock = _saleStartBlock;
		saleEndBlock = _saleEndBlock;
		saleFirstEarlyBirdEndBlock = saleStartBlock + 43197;  // Equivalent to (24 hours — (6171)) later (7 days), assuming 14 second blocks
		saleSecondEarlyBirdEndBlock = saleFirstEarlyBirdEndBlock + 43197;  // Equivalent to 48 hours later after first early bird, assuming 14 sec blocks
                saleThirdEarlyBirdEndBlock = saleSecondEarlyBirdEndBlock + 43197;
		saleFourthEarlyBirdEndBlock = saleThirdEarlyBirdEndBlock + 43197;  

		totalSupply = 0;
	}
	
	function createTokens() payable external {
		// If sale is not active, do not create GISC
		if (saleHasEnded) throw;
		if (block.number < saleStartBlock) throw;
		if (block.number > saleEndBlock) throw;
		// Check if the balance is greater than the security cap
		uint256 newEtherBalance = totalETHRaised.add(msg.value);
		if (newEtherBalance > SECURITY_ETHER_CAP) throw; 
		// Do not do anything if the amount of ether sent is 0
		if (0 == msg.value) throw;
		
		// Calculate the GISC to ETH rate for the current time period of the sale
		uint256 curTokenRate = GISC_PER_ETH_BASE_RATE;
		if (block.number < saleFirstEarlyBirdEndBlock) {
			curTokenRate = GISC_PER_ETH_FIRST_EARLY_BIRD_RATE;
		}
		else if (block.number < saleSecondEarlyBirdEndBlock) {
			curTokenRate = GISC_PER_ETH_SECOND_EARLY_BIRD_RATE;
		}
                else if (block.number < saleThirdEarlyBirdEndBlock) {
			curTokenRate = GISC_PER_ETH_THIRD_EARLY_BIRD_RATE;
		}
                else if (block.number < saleFourthEarlyBirdEndBlock) {
			curTokenRate = GISC_PER_ETH_FOURTH_EARLY_BIRD_RATE;
		}
		
		// Calculate the amount of GISC being purchased
		uint256 amountOfGISC = msg.value.mul(curTokenRate);
		
		// Ensure that the transaction is safe
		uint256 totalSupplySafe = totalSupply.add(amountOfGISC);
		uint256 balanceSafe = balances[msg.sender].add(amountOfGISC);
		uint256 contributedSafe = ETHContributed[msg.sender].add(msg.value);

		// Update individual and total balances
		totalSupply = totalSupplySafe;
		balances[msg.sender] = balanceSafe;

		totalETHRaised = newEtherBalance;
		ETHContributed[msg.sender] = contributedSafe;

		CreatedGISC(msg.sender, amountOfGISC);
	}
	
	function endSale() {
		// Do not end an already ended sale
		if (saleHasEnded) throw;
		// Can't end a sale that hasn't hit its minimum cap
		if (!minCapReached) throw;
		// Only allow the owner to end the sale
		if (msg.sender != executor) throw;
		
		saleHasEnded = true;

		// Calculate and create developer and reserve portion of GISC
		uint256 additionalGISC = (totalSupply.mul(ADDITIONAL_PORTION)).div(100 - ADDITIONAL_PORTION);
		uint256 totalSupplySafe = totalSupply.add(additionalGISC);

		uint256 reserveShare = (additionalGISC.mul(RESERVE_PORTION)).div(ADDITIONAL_PORTION);
		uint256 devShare = additionalGISC.sub(reserveShare);

		totalSupply = totalSupplySafe;
		balances[devGISCDestination] = devShare;
		balances[reserveGISCDestination] = reserveShare;
		
		CreatedGISC(devGISCDestination, devShare);
		CreatedGISC(reserveGISCDestination, reserveShare);

		if (this.balance > 0) {
			if (!devETHDestination.call.value(this.balance)()) throw;
		}
	}

	// Allows GISC Loancoin to withdraw funds
	function withdrawFunds() {
		if (0 == this.balance) throw;

		if (!devETHDestination.call.value(this.balance)()) throw;
	}
	
	// Signals that the sale has reached its minimum funding goal
	function triggerMinCap() {
		if (msg.sender != executor) throw;

		minCapReached = true;
	}

	// Opens refunding.
	function triggerRefund() {
		// No refunds if the sale was successful
		if (saleHasEnded) throw;
		// No refunds if minimum cap is hit
		if (minCapReached) throw;
		// No refunds if the sale is still progressing
		if (block.number < saleEndBlock) throw;
		if (msg.sender != executor) throw;

		allowRefund = true;
	}

	function refund() external {
		// No refunds until it is approved
		if (!allowRefund) throw;
		// Nothing to refund
		if (0 == ETHContributed[msg.sender]) throw;

		// Do the refund.
		uint256 etherAmount = ETHContributed[msg.sender];
		ETHContributed[msg.sender] = 0;

		GISCRefundedForWei(msg.sender, etherAmount);
		if (!msg.sender.send(etherAmount)) throw;
	}

	function changeDeveloperETHDestinationAddress(address _newAddress) {
		if (msg.sender != executor) throw;
		devETHDestination = _newAddress;
	}
	
	function changeDeveloperGISCDestinationAddress(address _newAddress) {
		if (msg.sender != executor) throw;
		devGISCDestination = _newAddress;
	}
	
	function changeReserveGISCDestinationAddress(address _newAddress) {
		if (msg.sender != executor) throw;
		reserveGISCDestination = _newAddress;
	}
	
	function transfer(address _to, uint _value) {
		// Cannot transfer unless the minimum cap is hit
		if (!minCapReached) throw;
		
		super.transfer(_to, _value);
	}
	
	function transferFrom(address _from, address _to, uint _value) {
		// Cannot transfer unless the minimum cap is hit
		if (!minCapReached) throw;
		
		super.transferFrom(_from, _to, _value);
	}
}
