pragma solidity ^0.4.11;
import "zeppelin-solidity/contracts/token/StandardToken.sol";
import "zeppelin-solidity/contracts/SafeMath.sol";

contract GISCFreezer {
	using SafeMath for uint256;

	// Addresses and contracts
	address public GISCContract;
	address public postFreezeDevGISCDestination;

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
		
		firstUnlocked = false;
	}

	function unlockFirst() external {
		if (firstUnlocked) throw;
		if (msg.sender != postFreezeDevGISCDestination) throw;
		if (now < firstThawDate) throw;
		
		firstUnlocked = true;
		
		uint256 totalBalance = StandardToken(GISCContract).balanceOf(this);

		// Allocations are each 22% of founder tokens
		firstAllocation = totalBalance.div(2);
		secondAllocation = totalBalance.sub(firstAllocation);
		
		uint256 tokens = firstAllocation;
		firstAllocation = 0;

		StandardToken(GISCContract).transfer(msg.sender, tokens);
	}

	function unlockSecond() external {
		if (!firstUnlocked) throw;
		if (msg.sender != postFreezeDevGISCDestination) throw;
		if (now < secondThawDate) throw;
		
		uint256 tokens = secondAllocation;
		secondAllocation = 0;

		StandardToken(GISCContract).transfer(msg.sender, tokens);
	}

	function changeGISCDestinationAddress(address _newAddress) external {
		if (msg.sender != postFreezeDevGISCDestination) throw;
		postFreezeDevGISCDestination = _newAddress;
	}
}
