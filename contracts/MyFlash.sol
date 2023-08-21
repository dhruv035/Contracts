// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;
pragma abicoder v2;

import {FlashLoanSimpleReceiverBase} from "@aave/core-v3/contracts/flashloan/base/FlashLoanSimpleReceiverBase.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';

contract FlashLoan is FlashLoanSimpleReceiverBase {
    address payable owner;
    uint256 amountIn;
    address theContract;
    address targetCollateral;
    address targetUser;
    uint256 repayAmount;
    ISwapRouter swapRouter;

    // take an address of provider
    constructor(
        address _addressProvider,
        ISwapRouter _swapRouter
      
    ) FlashLoanSimpleReceiverBase(IPoolAddressesProvider(_addressProvider)) {
        owner = payable(msg.sender);
        swapRouter = ISwapRouter(_swapRouter);
        
    }

    // For this example, we will set the pool fee to 0.3%.
    uint24 public poolFee = 3000;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the contract owner can call this function");
        _;
    }

    function executeOperation(
        address asset, // the token that we're borrowing
        uint256 amount, //the amount we're borrowing
        uint256 premium, // the loan fee
        address initiator, // The address of the flashloan initiator
        bytes calldata params // The byte-encoded params passed when initiating the flashloan
    ) external override returns (bool) {
        uint256 amountOut;
        uint256 amountOwed = amount + premium;
        IERC20(asset).approve(address(POOL), amountOwed+amount);
         
        //Liquidate the position for a debt
         IPool POOL = IPool(targetCollateral);

        POOL.liquidationCall(targetCollateral,asset,targetUser,repayAmount,false);

        
        IERC20(targetCollateral).approve(address(this),amountIn);
        TransferHelper.safeTransferFrom(targetCollateral, initiator, address(this), amountIn);
        TransferHelper.safeApprove(targetCollateral, address(swapRouter), amountIn);



        ISwapRouter.ExactInputSingleParams memory param =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: targetCollateral,
                tokenOut: asset,
                fee: poolFee,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: amountOwed,
                sqrtPriceLimitX96: 0
            });
        // The call to `exactInputSingle` executes the swap.
        amountOut = swapRouter.exactInputSingle(param);
        //Swap the received collateral to the flash token
        return true;
    }

    function requestFlashLoan(address _token, uint256 _amount) internal {
        address receiverAddress = address(this); // address of this contract
        address asset = _token;
        uint256 amount = _amount;
        bytes memory params = "";
        uint16 referralCode = 0;
        POOL.flashLoanSimple(receiverAddress, asset, amount, params, referralCode);
    }


    function getBalance(address _tokenAddress) external view returns (uint256) {
        return IERC20(_tokenAddress).balanceOf(address(this));
    }

    function withdraw(address _tokenAddress) external onlyOwner {
        IERC20 token = IERC20(_tokenAddress);
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    function executeLiquidation(address _flashToken, address _targetCollateral, address _targetUser, uint256 _repayAmount, uint256 _amountIn, uint24 _poolFee) public {

        poolFee = _poolFee;
        targetCollateral = _targetCollateral;
        amountIn = _amountIn;
        targetUser = _targetUser;
        repayAmount = _repayAmount;
        requestFlashLoan(_flashToken,repayAmount);
    }

    // the contract can give ether.
    receive() external payable {}
}