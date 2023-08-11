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
    address theContract;
    address target;
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
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // For this example, we will set the pool fee to 0.3%.
    uint24 public constant poolFee = 3000;

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
        uint256 amountIn;
        uint256 amountOut;
        uint256 amountOwed = amount + premium;
        IERC20(asset).approve(address(POOL), amountOwed);
         
        //Liquidate the position for a debt
         IPool POOL = IPool(target);

        POOL.liquidationCall(target,asset,targetUser,repayAmount,false);

        
        IERC20(target).approve(address(this),amountIn);
        TransferHelper.safeTransferFrom(target, initiator, address(this), amountIn);
        TransferHelper.safeApprove(target, address(swapRouter), amountIn);



        ISwapRouter.ExactInputSingleParams memory param =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: DAI,
                tokenOut: WETH9,
                fee: poolFee,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0,
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

    function executeLiquidation(address _flashToken, uint256 flashAmount, address _target, address _targetUser,uint256 _repayAmount) public {

        target = _target;
        targetUser = _targetUser;
        repayAmount = _repayAmount;
        requestFlashLoan(_flashToken,flashAmount);
    }

    // the contract can give ether.
    receive() external payable {}
}