// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/Math.sol";

contract CPAMM {
    IERC20 public immutable token0;
    IERC20 public immutable token1;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    constructor(address _token0, address _token1) {
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
    }

    function swap(address _tokenIn, uint256 amountIn)
        external
        returns (uint256 amountOut)
    {
        require(
            _tokenIn == address(token0) || _tokenIn == address(token1),
            "CPAMM: invalid address"
        );

        uint reserve0 = token0.balanceOf(address(this));
        uint reserve1 = token1.balanceOf(address(this));

        (IERC20 tokenIn, IERC20 tokenOut, uint reserveIn, uint reserveOut) = 
        _tokenIn == address(token0) 
        ? (token0, token1, reserve0, reserve1) 
        : (token1, token0, reserve1, reserve0);

        tokenIn.transferFrom(msg.sender, address(this), amountIn);

        uint realAmountIn = tokenIn.balanceOf(address(this)) - reserveIn;
        uint amountInWithFee = (realAmountIn * 997) / 1000; // 0.3% fee

        amountOut = (reserveOut * amountInWithFee) / (reserveIn + amountInWithFee);

        tokenOut.transfer(msg.sender, amountOut);
    }

    function addLiquidity(uint amount0, uint amount1) external returns (uint shares) {
        uint reserve0 = token0.balanceOf(address(this));
        uint reserve1 = token1.balanceOf(address(this));

        token0.transferFrom(msg.sender, address(this), amount0);
        token1.transferFrom(msg.sender, address(this), amount1);

        if (totalSupply == 0) {
            shares = Math.sqrt(amount0 * amount1);
        } else {
            shares = Math.min(
                ((amount0 * totalSupply) / reserve0),
                ((amount1 * totalSupply) / reserve1)
            );
        }

        require(shares > 0, "shares = 0");

        _mint(msg.sender, shares);
    }

    function removeLiquidity(uint shares) external returns (uint d0, uint d1) {
        uint reserve0 = token0.balanceOf(address(this));
        uint reserve1 = token1.balanceOf(address(this));

        d0 = (reserve0 * shares) / totalSupply;
        d1 = (reserve1 * shares) / totalSupply;

        _burn(msg.sender, shares);
        
        if (d0 > 0) {
            token0.transfer(msg.sender, d0);
        }

        if (d1 > 0) {
            token1.transfer(msg.sender, d1);
        }
    }

    function _mint(address to, uint256 amount) private {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function _burn(address to, uint256 amount) private {
        balanceOf[to] -= amount;
        totalSupply -= amount;
    }
}


contract Token0 is ERC20("Token0", "ZERO"){
    constructor() {
        _mint(msg.sender, 100000000);
    }
}
contract Token1 is ERC20("Token1", "ONE"){
    constructor() {
        _mint(msg.sender, 100000000);
    }
}