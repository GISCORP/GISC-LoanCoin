pragma solidity ^0.4.18;

 //—— Safe Math.sol ———
contract SafeMath {

    /**@dev Adds two numbers, throws on overflow.*/
    function safeAdd(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
    
    function safeSubtract(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }
    
    /**@dev Multiplies two numbers, throws on overflow.*/
    function safeMult(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        assert(c / a == b);
        return c;
    }
    
    /**@dev Integer division of two numbers, truncating the quotient.*/
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
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

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  /**@dev The Ownable constructor sets the original `owner` of the contract to the sender
   account.*/
  function Ownable() public {
    owner = msg.sender;
  }

  /**@dev Throws if called by any account other than the owner.*/
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  /**@dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.*/
  function transferOwnership(address newOwner) public onlyOwner {
    require(newOwner != address(0));
    OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }
}

//———— ERC20 Standard Code ———
contract Token {
    uint256 public totalSupply;
    function balanceOf(address who) public view returns (uint256);
    function transfer(address to, uint256 value) public returns (bool);
    function transferFrom(address from, address to, uint256 value) public returns (bool);
    function approve(address spender, uint256 value) public returns (bool);
    function allowance(address owner, address spender) public view returns (uint256);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
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

    function transfer(address _to, uint256 _value) 
             onlyPayloadSize(2 * 32) public returns (bool success) {
      if (balances[msg.sender] >= _value && _value > 0) {
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        Transfer(msg.sender, _to, _value);
        return true;
      } else {
        return false;
      }
    }

    function transferFrom(address _from, address _to, uint256 _value) 
             onlyPayloadSize(3 * 32) public returns (bool success) {
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

    function balanceOf(address _owner) public constant returns (uint256 alanceBW) {
        return balances[_owner];
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) public constant returns (uint256 remaining) {
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
	//address public reserveDevDestinationAddr;
	
	// Sale data
	bool public saleHasEnded;
	bool public minCapReached;
	mapping (address => uint256) public ETHContributed;
	uint256 public totalETHRaised;
	uint256 public saleStartBlock;
	uint256 public saleEndBlock;
	//uint256 public constant DEV_PORTION = 200 * (10**5) * 10**decimals;  
	uint256 public constant FOUNDERS_PORTION = 5500 * (10**5) * 10**decimals;
	uint256 public constant TOTAL_TOKENS = 4500 * (10**5) * 10**decimals;
	//uint256 public constant SECURITY_ETHER_CAP = 1000000 ether;
	uint256 public constant GISC_PER_ETH_BASE_RATE = 20000;  
    //uint256 public constant GISCFund = 1000 * (10**5) * 10**decimals;
    
    event CreateGISC(address indexed _creator, uint256 _amountOfGISC);
    
	function GISCToken(
		address _ETHFundDepositAddr,
		address _reserveFoundersDestinationAddr,
		//address _reserveDevDestinationAddr,
		uint256 _saleStartBlock,
		uint256 _saleEndBlock
	) public {
		// Reject on invalid ETH destination address or GISC destination address
		require(_ETHFundDepositAddr != address(0x0));
		require(_reserveFoundersDestinationAddr != address(0x0));
		//require(_reserveDevDestinationAddr != address(0x0));
		// Reject if sale ends before the current block
		require(_saleEndBlock >= block.number);
		// Reject if the sale end time is less than the sale start time
		require(_saleEndBlock >= _saleStartBlock);

		executor = msg.sender;
		saleHasEnded = false;
		minCapReached = false;
		ETHFundDepositAddr = _ETHFundDepositAddr;
		reserveFoundersDestinationAddr = _reserveFoundersDestinationAddr;
		//reserveDevDestinationAddr = _reserveDevDestinationAddr;
		totalETHRaised = 0;
		saleStartBlock = _saleStartBlock;
		saleEndBlock = _saleEndBlock;

		totalSupply = 0;
		//--- Place Founder Share and DEveloper share into the holding accounts
	//	balances[reserveDevDestinationAddr] = DEV_PORTION;// Deposit GISC share
      //  CreateGISC(reserveDevDestinationAddr, DEV_PORTION);  // logs GISC fund
		
		balances[reserveFoundersDestinationAddr] = FOUNDERS_PORTION;//Dep Founder share
        CreateGISC(reserveFoundersDestinationAddr, FOUNDERS_PORTION);  // log Founders
	}
	
	  function () public payable {           // prefer to use fallback function
      require(msg.value > 0);
      createTokens();
    }

	function createTokens() internal {
		uint256 newEtherBalance = safeAdd(totalETHRaised, msg.value);
		require(!saleHasEnded);
		require(block.number > saleStartBlock);
		require(block.number < saleEndBlock);
		//require(newEtherBalance < SECURITY_ETHER_CAP);
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
	
	function endSale() public {
	    require(msg.sender == executor);
		// Do not end an already ended sale
		require(!saleHasEnded);
		// Can't end a sale that hasn't hit its minimum cap
		saleHasEnded = true;
		if (this.balance > 0) {
			if (!ETHFundDepositAddr.call.value(this.balance)()) revert();
		}
	}

	// Allows GISC Loancoin to withdraw funds
	function withdrawETH() public {
	    require(msg.sender == executor);
		if (0 == this.balance) revert();
		require(ETHFundDepositAddr.call.value(this.balance)());
	}
	
	// Signals that the sale has reached its minimum funding goal
	function triggerMinCap() public {
	    require(msg.sender == executor);
		minCapReached = true;
	}
	
	function changeETHDestinationAddress(address _newAddress) public {
		require(msg.sender == executor);
		ETHFundDepositAddr = _newAddress;
	}
	
	function kill() public {
        if (msg.sender == executor)
        selfdestruct(executor);
    }
    
    function transferTokens(address _to, uint256 _value) onlyPayloadSize(2 * 32) public returns (bool success) {
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
    
    function changeSaleEndDate (uint256 _newSaleEndBlock) public 
    {
        require(msg.sender == executor);
        saleEndBlock = _newSaleEndBlock;
    }
    
    function moveRemainingTokens () public 
    { // Take the remaining of the 450 Million tokens at the end
        require(msg.sender == executor);
		if (TOTAL_TOKENS <= totalSupply) revert();
		balances[reserveFoundersDestinationAddr] = (TOTAL_TOKENS - totalSupply);
        CreateGISC(reserveFoundersDestinationAddr, (TOTAL_TOKENS - totalSupply));
    }
}
