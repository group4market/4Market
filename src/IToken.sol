// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IToken {
    // Function to mint tokens to an address
    function mint(address to, uint256 amount) external;

    // Function to burn tokens from an address
    function burnFrom(address account, uint256 amount) external;

    // Function to get the total supply of tokens
    function totalSupply() external view returns (uint256);

    // Function to get the balance of tokens for an address
    function balanceOf(address account) external view returns (uint256);
}
