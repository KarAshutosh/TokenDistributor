// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Distributor is Ownable
{
    
    constructor()
    {  

        recieverEditable = true;
        frozenVal = false;
        tokenTypes = 0;
        totalDistributions = 0;
        balanceSufficient = false;
        addGammaUsed = false;
        nextInterval = 604740;

        lastDistribution = block.timestamp;        

        address _owner = owner();
        addAuthorizedAddress(_owner);

        emergencyWallet = _owner;

    }

    bool internal balanceSufficient;  
    
    bool internal addGammaUsed;

    bool internal frozenVal;

    bool internal recieverEditable;

    uint tokenTypes;
    
    uint totalDistributions;

    uint lastDistribution;

    uint nextInterval;

    address internal emergencyWallet;

    mapping(address => bool) public authorized;

    uint[] private balanceNeeded;

    address[] public token;          
    
    receiverStruct[] public receiverList;

    event IntervalSet(uint);
    event Authorized(address,bool);
    event AuthorizationToggled(address, bool, bool);
    event DistributionFrozen(bool);
    event TokenAdded(address);
    event TokenRemoved(address);
    event ReceiverUpdate(address, uint, uint, uint, uint, uint, bool);
    event DistributionOn(uint);
    event balanceInsufficient(address, uint);
    event PassedCheck(address, bool);
    
    function setNextInterval(uint _nextInterval) public onlyOwner
    {
        nextInterval = _nextInterval;
        emit IntervalSet(nextInterval);
    }

    modifier onInterval 
    {
      require(block.timestamp > lastDistribution + nextInterval, "Sufficient time hasn't passed since contract was last called");
      _;
    }

    modifier editProtection 
    {
      require(recieverEditable == true, "Use refreshCheck to be able to edit list");
      _;
    }
    
    function addAuthorizedAddress(address _user) public onlyOwner 
    {
        require(_user != address(0),"_user should not be zero address");
        authorized[_user] = true;
        emit Authorized(_user, true);        
    }

    function updateAuthorizedAddress(address _user) public onlyOwner 
    {
        require(_user != address(0),"_user should no be zero address");
        bool prev = authorized[_user];
        authorized[_user] = !prev;
        emit AuthorizationToggled(_user, prev, !prev);
    }

    modifier onlyAuthorized 
    {
        require(authorized[_msgSender()] == true, "only authorized user is allowed");
        _;
    }

    modifier checkFrozen
    {
        require(frozenVal == false, "Tranzactions have been frozen");
        _;
    }

    function freezeSending() external onlyOwner returns(bool)
    {
        frozenVal = true;
        emit DistributionFrozen(true);
        return frozenVal;
    }

    function unfreezeSending() external onlyOwner returns(bool)
    {
        frozenVal = false;
        emit DistributionFrozen(false);
        return frozenVal;
    }


    function addGammaToToken() public onlyOwner
    {
        require(addGammaUsed == false, "This function has already been used");
        address gammaAddress = 0xb3Cb6d2f8f2FDe203a022201C81a96c167607F15;
        addToken(gammaAddress);
        addGammaUsed = true;
    }
    
    function addToken(address _token) public onlyAuthorized editProtection
    {
        token[tokenTypes] = _token;
        tokenTypes = tokenTypes + 1;
        emit TokenAdded(_token);
    }

    function removeToken(uint _tokenID) external onlyAuthorized editProtection
    {
        
        uint lastToken = tokenTypes - 1;
        address oldToken = token[_tokenID];
        token[_tokenID] = token[lastToken];
        token.pop();
        tokenTypes = tokenTypes - 1;
        emit TokenRemoved(oldToken);
    }

    //Use this to cross check if the right token is being removed in removedStabes
    function getTokenAddressByID(uint _tokenID) public view returns (address) 
    {
        address tokenAdd = token[_tokenID];
        return tokenAdd;
    } 

    //Send funds to smart contract  
    function deposit(uint _amount, uint _tokenID) public payable 
    {  
        IERC20(getTokenAddressByID(_tokenID)).transferFrom(msg.sender, address(this), _amount);
    }

    //See present funds in smart contract
    function getBalanceByID(uint _tokenID) public view returns(uint)
    {
        return IERC20(getTokenAddressByID(_tokenID)).balanceOf(address(this));
    } 

    struct receiverStruct
    { 
        address receiverAdd;
        uint distributionID;
        uint tokenID;
        uint receiveAmt;
        uint lastReceived;
        uint intervalOf;
        bool willReceive;
    }

    function AddReceiver(address _receiverAdd, uint _tokenID, uint _receiveAmt, uint _intervalOf) external onlyAuthorized editProtection
    {

        receiverList[totalDistributions] = receiverStruct(_receiverAdd, totalDistributions, _tokenID, _receiveAmt, 0, _intervalOf, true);
        emit ReceiverUpdate(_receiverAdd, totalDistributions, _tokenID, _receiveAmt, 0, _intervalOf, true);
        totalDistributions = totalDistributions + 1;
        balanceNeeded[_tokenID] = balanceNeeded[_tokenID] + _receiveAmt;
        
    }

    function UpdateReceiver(address _receiverAdd, uint _distributionID, uint _tokenID, uint _receiveAmt, uint _intervalOf, bool _willReceive) external onlyAuthorized editProtection
    {
        uint previousAmt = receiverList[_distributionID].receiveAmt;
        balanceNeeded[_tokenID] = balanceNeeded[_tokenID] - previousAmt;  

        uint _lastReceived = receiverList[_distributionID].lastReceived;
        
        receiverList[_distributionID] = receiverStruct(_receiverAdd, _distributionID, _tokenID, _receiveAmt, _lastReceived, _intervalOf, _willReceive);
        emit ReceiverUpdate(_receiverAdd, _distributionID, _tokenID, _receiveAmt, _lastReceived, _intervalOf, _willReceive);
        
        balanceNeeded[_tokenID] = balanceNeeded[_tokenID] + _receiveAmt;
    }

    function checkSufficient() public onlyAuthorized 
    {
        uint checkFails = 0;

        for(uint _tokenID = 0; _tokenID < tokenTypes; _tokenID++)
        {
            uint currentBalance = getBalanceByID(_tokenID);
            uint neededBalance = balanceNeeded[_tokenID];
            address theToken = token[_tokenID];

            if(neededBalance > currentBalance)
            {
                checkFails = checkFails + 1;

                uint missingBalance = neededBalance - currentBalance;

                emit PassedCheck(theToken, false);
                emit balanceInsufficient(theToken, missingBalance);

            }
            
            //balanceSufficient = true; 
            else
            {
                emit PassedCheck(theToken, true);
            }
                    
            
        }

        if(checkFails > 0)
        {
            balanceSufficient = false;
        }

        if(checkFails == 0)
        {
            balanceSufficient = true;
            recieverEditable = false;
        }

    }

    function refreshCheck() external onlyAuthorized
    {
        balanceSufficient = false;
        recieverEditable = true;
    }
        
    function distributeToAll() external payable onlyAuthorized onInterval
    {
        require(balanceSufficient == true, "Insufficient balance");
        
        checkSufficient();

        for(uint _distributionID = 0; _distributionID < totalDistributions; _distributionID++)
        {
            uint _lastReceived = receiverList[_distributionID].lastReceived;
            uint _intervalOf = receiverList[_distributionID].intervalOf;
                        
            if(block.timestamp > _lastReceived + _intervalOf)
            {
                IERC20(getTokenAddressByID(receiverList[_distributionID].tokenID)).transferFrom(address(this), receiverList[_distributionID].receiverAdd, receiverList[_distributionID].receiveAmt);
            }
        }

        balanceSufficient = false;
        lastDistribution = block.timestamp;
        emit DistributionOn(lastDistribution);
    }   

    function setEmergencyWallet(address _emergencyWallet) public onlyOwner
    {
        emergencyWallet = _emergencyWallet;
    }

    function emergancyHide() external onlyOwner
    {
        for(uint _tokenID = 0; _tokenID < tokenTypes; _tokenID++)
        {
            uint allFunds = IERC20(getTokenAddressByID(_tokenID)).balanceOf(address(this));
            IERC20(getTokenAddressByID(_tokenID)).transferFrom(address(this), emergencyWallet, allFunds);
        }

    }

}
