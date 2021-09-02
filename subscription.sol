pragma solidity ^0.8.6;


import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract Payment {
  mapping(address => bool) private admins;
  address[] private adminsList;
  address private tokenAddress;
  
  modifier adminOnly{
    require(admins[msg.sender], "Admin only access");
    _;
  }
  function addAdmin(address admin) external adminOnly {
    adminsList.push(admin);
    admins[admin] = true;
  }

  function remove(uint index)  returns(uint[]) {
    require(index < adminsList.length, 'index out of range');
    for (uint i = index; i<adminsList.length-1; i++){
        adminsList[i] = adminsList[i+1];
    }
    delete adminsList[adminsList.length-1];
    adminsList.length--;
    return adminsList;
  }

  function addMultipleAdmin(address[] admins) external adminOnly {
    for (uint i=0; i < admins.length; i++){
      adminsList.push(i);
      admins[i] = true;
    }
  }

  function removeAdmin(address admin) external adminOnly {
    admins[admin] = false;
  }

  function setTokenAddress(address _address) external adminOnly {
    tokenAddress = _address;
  }
  
  // This contract is meant to facilitate subscriptions on the VOYR platform using VOYRME tokens
  // This contract assumes there is an external database keeping track of the subscription IDs
  // This contract REQUIRES that the subscriber pre-approve the allowed amount prior to creating the subscription

  struct Plan {
    address receiver;
    uint creatorID;
    uint amount;
    uint frequency;
    bool status;
  }
  struct Subscription {
    address fan;
    uint start;
    uint nextPayment;
    bool status;
  }

  uint private minFrequency = 86400;

  mapping(uint => Plan) public plans;
  mapping(address => mapping(uint => Subscription)) public subscriptions;

  event PlanCreated(address creator, uint planId, uint date);
  event SubscriptionCreated(address fan, uint planId, uint date);
  event SubscriptionCancelled(address fan, uint planId, uint date);
  event PaymentSent(address from, address to, uint amount, uint planId, uint date);

  function setMinFrequency(uint _minFrequency) external adminOnly {
    require(_minFrequency > 0, 'frequency needs to be > 0');
    minFrequency = _minFrequency;
  }

  function showMinFrequency() external pure adminOnly returns(uint){
    return minFrequency;
  }

  function createPlan(address reciever, uint creatorID, uint amount, uint frequency, uint planID) external adminOnly {
    require(amount > 0, 'amount needs to be > 0');
    require(frequency >= minFrequency, 'frequency needs to be greater than the minimum');
    require(!plans[planID].status, 'plan already exists');
    plans[planID] = Plan(
      receiver,
      creatorID,
      amount, 
      frequency,
      true
    );
  }

  function cancelPlan(uint plaId) external adminOnly {

  }

  function subscribe(uint planId) external {
    Plan storage plan = plans[planId];
    IERC20 token = IERC20(tokenAddress);
    require(!plan.status, 'this plan does not exist');
    require(token.allowance[msg.sender][plan.receiver] > (plan.amount * 12), "pre-approval required");  // UI needs to pre-approve for amount * 12
    token.transferFrom(msg.sender, plan.receiver, plan.amount);

    subscriptions[msg.sender][planId] = Subscription(
      msg.sender, 
      block.timestamp, 
      block.timestamp + plan.frequency,
      true
    );
  }

  function cancelSubscription(uint planId) external {
    Subscription storage subscription = subscriptions[msg.sender][planId];
    if(!admin[msg.sender]){
      require(subscription.fan = msg.sender, 'you are not the subscriber');
    }
    require(subscription.fan != address(0), 'this subscription does not exist');
    subscriptions[msg.sender][planId].status = false;
  }

  function pay(address fan, uint planId) external {
    Subscription storage subscription = subscriptions[fan][planId];
    IERC20 token = IERC20(tokenAddress);
    Plan storage plan = plans[planId];
    require(subscription.fan != address(0), 'this subscription does not exist');
    require(block.timestamp > subscription.nextPayment, 'not due yet');

    token.transferFrom(fan, plan.creator, plan.amount);  
    subscription.nextPayment = subscription.nextPayment + plan.frequency;
  }
}
