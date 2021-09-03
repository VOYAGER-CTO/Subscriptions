pragma solidity ^0.8.6;
// SPDX-License-Identifier: None

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract Payment {
  mapping(address => bool) private admins;
  mapping(string => address) private tokens;
  string[] private tokenArray;
  address[] private adminsList;
  uint private minMultiplier = 12;
  
  constuctor () public {
    adminsList.push(msg.sender);
    admins[msg.sender] = true;
    setTokenAddress(VOYRME, 0x33a887Cf76383be39DC51786e8f641c9D6665D84);
  }

  // adminOnly modifier requiring msg.sender to be in the admins list
  modifier adminOnly{
    require(admins[msg.sender], "Admin only access");
    _;
  }

  // add an admin to the list
  function addAdmin(address admin) external adminOnly {
    adminsList.push(admin);
    admins[admin] = true;
  }

  // disable admin
  function disableAdmin(address admin) external adminOnly {
    admins[admin] = false;
  }

  // set tokenAddress
  function setTokenAddress(string name, address _address) external adminOnly {
    tokens[name] = _address;
    tokensArray.push(name);
  }

  function getTokenList() view external adminOnly {
    return(tokenArray)
  }
  
  // This contract is meant to facilitate subscriptions
  // This contract assumes there is an external database keeping track of the subscription and plan IDs
  // This contract REQUIRES that the UI initiate the fan to pre-approve the allowed amount prior to creating the subscription

  struct Plan {
    address receiverAddress;
    uint planID;
    uint creatorID;
    uint amount;
    uint frequency;
    bool isActive;
  }
  struct Subscription {
    address fanAddress;
    uint planID;
    uint subscriptionID;
    uint startTime;
    uint nextPayment;
    bool isActive;
  }

  uint private minFrequency = 86400;

  mapping(uint => Plan) public plans;
  mapping(address => mapping(uint => Subscription)) public subscriptions;
  mapping(uint => uint[]) private planSubscriptions;  // planId => subscriptions

  function getMinMultiplier() external view adminOnly returns(uint minMultiplier){
    return(minMultiplier);
  }

  function setMinMultiplier(uint _minMultiplier) external adminOnly {
    minMultiplier = _minMultiplier;
  }

  function getPlanSubscriptions(planId) external view adminOnly returns(uint[] subscriptions){
    return planSubscriptions[planId];
  }

  function getPlanDetails(planId) external view adminOnly returns(string[] plan){
    return(plans[planId]);
  }

  function getSubscriptionDetails(subscriptionId) external view adminOnly returns(string[] subscription){
    return(subscriptions(subscriptionId));
  }

  function getSubscriptionAmount(subscriptionId) external view adminOnly returns (uint amount){
    return(plans[subscriptions[subscriptionId].planID].amount);
  }

  function getSubscriptionNextPayment(subscriptionId) external view adminOnly returns (uint nextPayment){
    return(subscriptions[subscriptionId].nextPayment);
  }

  function getSubscriptionStartTime(subscriptionId) external view adminOnly returns (uint startTime){
    return(subscriptions[subscriptionId].startTime);
  }

  function isSubscriptionActive(subscriptionId) external view adminOnly returns(bool isActive) {
    return(subscriptions[subscriptionId].startTime);
  }

  function subscriptionFanAddress(subscriptionId) external view adminOnly returns(address fanAddress){
    return(subscriptions[subscriptionId].fanAddress);
  }

  function subscriptionPlanID(subscriptionId) external view adminOnly returns(uint planID){
    return(subscriptions[subscriptionId].planID);
  }

  function setMinFrequency(uint _minFrequency) external adminOnly {
    require(_minFrequency > 0, 'frequency needs to be > 0');
    minFrequency = _minFrequency;
  }

  function getMinFrequency() external pure adminOnly returns(uint){
    return minFrequency;
  }

  function createPlan(address recieverAddress, uint planID, uint creatorID, uint amount, uint frequency) external adminOnly {
    require(amount > 0, 'amount needs to be > 0');
    require(frequency >= minFrequency, 'frequency needs to be greater than the minimum');
    require(plans[planID].status == false, 'plan already exists');
    plans[planID] = Plan(
      receiverAddress,
      planID,
      creatorID,
      amount, 
      frequency,
      true
    );
  }

  function cancelPlan(uint planId) external adminOnly {
    plans[planId].isActive = false;
  }

  function subscribe(uint planId, uint subscriptionId, string tokenName) external {
    Plan storage plan = plans[planId];
    IERC20 token = IERC20(tokens[tokenName]);
    require(!plan.isActive, 'this plan is not active');
    require(token.allowance(msg.sender,address(this)) > (plan.amount * minMultiplier), "pre-approval required");  // UI needs to pre-approve for multiple months
    require(token.balanceOf(msg.sender) > plan.amount, "insufficient balance");
    subscriptions[msg.sender][planId] = Subscription(
      msg.sender,
      planId,
      subscriptionId,
      block.timestamp, 
      block.timestamp + plan.frequency,
      true
    );
    planSubscriptions[planId].push(subscriptionId);
    token.transferFrom(subscription.fanAddress, address(this), plan.amount);
    token.transfer(plan.receiverAddress, plan.amount);
  }

  // Cancel a  subscription
  // This can be done by the subscriber OR an admin
  function cancelSubscription(uint planId) external {
    Subscription storage subscription = subscriptions[msg.sender][planId];
    require(subscription.fan = msg.sender || admins[msg.sender], 'you are not the subscriber or an admin');
    require(subscription.fan != address(0), 'this subscription does not exist');
    subscriptions[msg.sender][planId].status = false;
  }

  // This function is to take in a list of planIds that will need to be processed
  // If you know of a better way to store potentially millions of entries by time and just trigger a function without having to...
  // ... send a list and also be careful not to run out of gas, hence why I went with sending a list and iterating over that, then...
  // ... I can make the list any size I want and call it multiple times. Depending on the number of planIds I can send through here...
  // ... it may take a while, I may end up having to process thousands a day, hopefuly this will handle enough without running out of gas

  // Any gas optimization on here would be welcome as I would like to include as many as possible in a single transaction
  function paySubscriptions(uint[] planIds, string tokenName) external returns(uint[] memory successSubscriptionIDs,
                                                             uint[] memory failedSubscriptionIDs, 
                                                             string[] memory failedSubscriptionReasons){
    IERC20 token = IERC20(tokens[tokenName]);
    uint[] memory successSubscriptionIDs;
    uint[] memory failedSubscriptionIDs;
    string[] memory failedSubscriptionReasons;
    for (uint256 i=0; i < planIds.length; i++) {
      Subscription storage subscription = subscriptions[fan][planIds[i]];
      Plan storage plan = plans[planIds[i]];
      require(subscription.fan != address(0), 'this subscription does not exist');
      if(token.balanceOf() > plan.amount 
            || block.timestamp > subscription.nextPayment 
            || token.allowance(msg.sender, address(this)) > plan.amount 
            || subscription.isActive == false 
            || plan.isActive == false) {
        if(token.balanceOf() > plan.amount){
          failedSubscriptionReasons.push('insufficient balance');
        } else if (block.timestamp > subscription.nextPayment){
          failedSubscriptionReasons.push('payment attempted too early');
        } else if (token.allowance(msg.sender, address(this))){
          failedSubscriptionReasons.push('insufficient allowance');
        } else if (!subscription.isActive){
          failedSubscriptionReasons.push('subscription is not active');
        } else if (!plan.isActive){
          failedSubscriptionReasons.push('plan is not active');
        }
        failedSubscriptionIDs.push(planIds[i]);
      }
      else {
        successSubscriptionIDs.push(planIds[i]);
        token.transferFrom(subscription.fanAddress, address(this), plan.amount);
        token.transfer(subscription.fanAddress, plan.amount);
        subscription.nextPayment = subscription.nextPayment + plan.frequency;
      }
    }
    return(successSubscriptionIDs, failedSubscriptionIDs, failedSubscriptionReasons);
  }
}
