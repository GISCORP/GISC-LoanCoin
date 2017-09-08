pragma solidity ^0.4.11;

 //—— Safe Math.sol ———
contract SafeMath {

    function safeAdd(uint256 x, uint256 y) internal returns(uint256) {
      uint256 z = x + y;
      assert((z >= x) && (z >= y));
      return z;
    }

    function safeSubtract(uint256 x, uint256 y) internal returns(uint256) {
      assert(x >= y);
      uint256 z = x - y;
      return z;
    }

    function safeMult(uint256 x, uint256 y) internal returns(uint256) {
      uint256 z = x * y;
      assert((x == 0)||(z/x == y));
      return z;
    }
    
    function safeDiv(uint256 a, uint256 b) constant returns (uint256) {
    // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    return c;
  }

}

//——— Ownable.sol ——

/* Ownable
 * Base contract with an owner.
 * Provides onlyOwner modifier, which prevents function from running if it is called by anyone other than the owner.
 */
contract Ownable {
  address public owner;

  function Ownable() {
    owner = msg.sender;
  }

  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  function transferOwnership(address newOwner) onlyOwner {
    if (newOwner != address(0)) {
      owner = newOwner;
    }
  }
}

//———— ERC20 Standard Code ———
contract Token {
    uint256 public totalSupply;
    function balanceOf(address _owner) constant returns (uint256 alanceBW);
    function transfer(address _to, uint256 _value) returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) returns (bool success);
    function approve(address _spender, uint256 _value) returns (bool success);
    function allowance(address _owner, address _spender) constant returns (uint256 remaining);
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}

/*  ERC 20 token */
contract StandardToken is Token {

  modifier onlyPayloadSize(uint size) {
     /*if(msg.data.length < size + 4) {
       throw;
     }*/
     require(msg.data.length >= size + 4);
     _;
  }

    function transfer(address _to, uint256 _value) onlyPayloadSize(2 * 32) returns (bool success) {
      if (balances[msg.sender] >= _value && _value > 0) {
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        Transfer(msg.sender, _to, _value);
        return true;
      } else {
        return false;
      }
    }

    function transferFrom(address _from, address _to, uint256 _value) onlyPayloadSize(3 * 32) returns (bool success) {
      if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value && _value > 0) {
        balances[_to] += _value;
        balances[_from] -= _value;
        allowed[_from][msg.sender] -= _value;
        Transfer(_from, _to, _value);
        return true;
      } else {
        return false;
      }
    }

    function balanceOf(address _owner) constant returns (uint256 alanceBW) {
        return balances[_owner];
    }

    function approve(address _spender, uint256 _value) returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) constant returns (uint256 remaining) {
      return allowed[_owner][_spender];
    }

    mapping (address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;
}

//—— GISC Token Code ————————
contract GISCToken is StandardToken, SafeMath {

	// Token data and Meta Data
	string public constant name = "GISC Loancoin";
	string public constant symbol = "GIS";
	uint256 public constant decimals = 18; 
	string public version = "1.0";
	
	// Addresses and contracts
	address public executor;
	// deposit address for ETH for Domain Development Fund
	address public ETHFundDepositAddr;
	address public reserveFoundersDestinationAddr;
	address public reserveDevDestinationAddr;
	
	// Sale data
	bool public saleHasEnded;
	bool public minCapReached;
	mapping (address => uint256) public ETHContributed;
	uint256 public totalETHRaised;
	uint256 public saleStartBlock;
	uint256 public saleEndBlock;
	uint256 public constant DEV_PORTION = 200 * (10**5) * 10**decimals;  
	uint256 public constant FOUNDERS_PORTION = 200 * (10**5) * 10**decimals;
	uint256 public constant SECURITY_ETHER_CAP = 1000000 ether;
	uint256 public constant GISC_PER_ETH_BASE_RATE = 900;  
    uint256 public constant GISCFund = 1000 * (10**5) * 10**decimals;
    
    event CreateGISC(address indexed _creator, uint256 _amountOfGISC);
    
	function GISCToken(
		address _ETHFundDepositAddr,
		address _reserveFoundersDestinationAddr,
		address _reserveDevDestinationAddr,
		uint256 _saleStartBlock,
		uint256 _saleEndBlock
	) {
		// Reject on invalid ETH destination address or GISC destination address
		require(_ETHFundDepositAddr != address(0x0));
		require(_reserveFoundersDestinationAddr != address(0x0));
		require(_reserveDevDestinationAddr != address(0x0));
		// Reject if sale ends before the current block
		require(_saleEndBlock >= block.number);
		// Reject if the sale end time is less than the sale start time
		require(_saleEndBlock >= _saleStartBlock);

		executor = msg.sender;
		saleHasEnded = false;
		minCapReached = false;
		ETHFundDepositAddr = _ETHFundDepositAddr;
		reserveFoundersDestinationAddr = _reserveFoundersDestinationAddr;
		reserveDevDestinationAddr = _reserveDevDestinationAddr;
		totalETHRaised = 0;
		saleStartBlock = _saleStartBlock;
		saleEndBlock = _saleEndBlock;
		//saleFirstEarlyBirdEndBlock = saleStartBlock + 43197;  
		// Equivalent to (24 hours — (6171)) later (7 days), assuming 14 second blocks

		totalSupply = 0;
		//--- Place Founder Share and DEveloper share into the holding accounts
		balances[reserveDevDestinationAddr] = DEV_PORTION;// Deposit GISC share
        CreateGISC(reserveDevDestinationAddr, DEV_PORTION);  // logs GISC fund
		
		balances[reserveFoundersDestinationAddr] = FOUNDERS_PORTION;//Dep Founder share
        CreateGISC(reserveFoundersDestinationAddr, FOUNDERS_PORTION);  // log Founders
	}
	
	  function () payable {           // prefer to use fallback function
      require(msg.value > 0);
      createTokens();
    }

	function createTokens() internal {
		uint256 newEtherBalance = safeAdd(totalETHRaised, msg.value);
		require(!saleHasEnded);
		require(block.number > saleStartBlock);
		require(block.number < saleEndBlock);
		require(newEtherBalance < SECURITY_ETHER_CAP);
		require(msg.value > 0);

		// Calculate the amount of GISC being purchased
		uint256 amountOfGISCPurchased = safeMult(msg.value,GISC_PER_ETH_BASE_RATE);
		
		// Ensure that the transaction is safe
		uint256 totalSupplySafe = safeAdd(totalSupply,amountOfGISCPurchased);
		uint256 balanceSafe = safeAdd(balances[msg.sender],amountOfGISCPurchased);
		//uint256 contributedSafe = ETHContributed[msg.sender].add(msg.value);
		uint256 contributedSafe = safeAdd(ETHContributed[msg.sender],msg.value);

		// Update individual and total balances
		totalSupply = totalSupplySafe;
		balances[msg.sender] = balanceSafe;

		totalETHRaised = newEtherBalance;
		ETHContributed[msg.sender] = contributedSafe;

		CreateGISC(msg.sender, amountOfGISCPurchased);
	}
	
	function finalize() external {
      require(!saleHasEnded);
      require(msg.sender == executor); 
      saleHasEnded = true;
      ETHFundDepositAddr.transfer(this.balance);
    }
	
	function endSale() {
	    require(msg.sender == executor);
		// Do not end an already ended sale
		require(!saleHasEnded);
		// Can't end a sale that hasn't hit its minimum cap
		require(msg.sender == executor); 
		
		saleHasEnded = true;
		if (this.balance > 0) {
			if (!ETHFundDepositAddr.call.value(this.balance)()) revert();
		}
	}

	// Allows GISC Loancoin to withdraw funds
	function withdrawETH() {
	    require(msg.sender == executor);
		if (0 == this.balance) revert();
		require(ETHFundDepositAddr.call.value(this.balance)());
	}
	
	// Signals that the sale has reached its minimum funding goal
	function triggerMinCap() {
	    require(msg.sender == executor);
		minCapReached = true;
	}
	
	function changeETHDestinationAddress(address _newAddress) {
		require(msg.sender == executor);
		ETHFundDepositAddr = _newAddress;
	}
	
	function kill() {
        if (msg.sender == executor)
        suicide(executor);
    }
    
    function transferTokens(address _to, uint256 _value) onlyPayloadSize(2 * 32) returns (bool success) {
        require(msg.sender == executor);
        require(_value > 0);
        uint256 totalSupplySafe = safeAdd(totalSupply,_value);
		uint256 balanceSafe = safeAdd(balances[_to],_value);
        // Update individual and total balances
		totalSupply = totalSupplySafe;
		balances[_to] = balanceSafe;
		CreateGISC(_to, _value);
		return true;
    }
}

//—— GISC Freezer Code ——

contract GISCFreezer is StandardToken, SafeMath {

	// Addresses and contracts
	address public GISCContract;
	address public postFreezeDevGISCDestination;
	address public executor;

	// Freezer Data
	uint256 public firstAllocation;
	uint256 public secondAllocation;
	uint256 public firstThawDate;
	uint256 public secondThawDate;
	bool public firstUnlocked;

	function GISCFreezer(
		address _GISCContract,
		address _postFreezeDevGISCDestination
	) {
		GISCContract = _GISCContract;
		postFreezeDevGISCDestination = _postFreezeDevGISCDestination;

		firstThawDate = now + 180 days;  // half a year from now
		secondThawDate = now + 2 * 180 days;  // one year from now
		executor = msg.sender;
		firstUnlocked = false;
	}

	function unlockFirst() external {
	    require(msg.sender == executor);
	    require(!firstUnlocked);
		
		if (msg.sender != postFreezeDevGISCDestination) revert();
		if (now < firstThawDate) revert();
		
		firstUnlocked = true;
		
		uint256 totalBalance = StandardToken(GISCContract).balanceOf(this);

		// Allocations are each 22% of founder tokens
		firstAllocation = safeDiv(totalBalance,2);
		secondAllocation = safeSubtract(totalBalance,firstAllocation);
		
		uint256 tokens = firstAllocation;
		firstAllocation = 0;

		StandardToken(GISCContract).transfer(msg.sender, tokens);
	}

	function unlockSecond() external {
	    require(msg.sender == executor);
		if (!firstUnlocked) revert();
		if (msg.sender != postFreezeDevGISCDestination) revert();
		if (now < secondThawDate) revert();
		
		uint256 tokens = secondAllocation;
		secondAllocation = 0;

		StandardToken(GISCContract).transfer(msg.sender, tokens);
	}

	function changeGISCDestinationAddress(address _newAddress) external {
	    require(msg.sender == executor);
		if (msg.sender != postFreezeDevGISCDestination) revert();
		postFreezeDevGISCDestination = _newAddress;
	}
	
}


