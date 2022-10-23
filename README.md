# LBPair fee calculation error background
- LBPair contracts do not collect the correct number of fees on swaps.
- Fees are usually short by about 0.1% for single bin swaps.
- For multi-bin swaps, the lost fees compound and the difference grows larger with each bin that is crossed. (due to the variable fee increasing)



## Detailed walkthrough
- LBPair.swap uses _bin.getAmounts(...) on the active bin to calculate fees. [See here](https://github.com/sha256yan/incorrect-fee/blob/dc355df9ee61a41185dedd7017063fc508584f24/src/LBPair.sol#L329-L330)
- _bin is an instance of the custom type Bin, which uses the SwapHelper library. [See here](https://github.com/sha256yan/incorrect-fee/blob/dc355df9ee61a41185dedd7017063fc508584f24/src/LBPair.sol#L36)
- For a given swap, if a bin has enough liqudity, the fee is calculated using [FeeHelper.getFeeAmountFrom(amountIn)](https://github.com/code-423n4/2022-10-traderjoe/blob/79f25d48b907f9d0379dd803fc2abc9c5f57db93/src/libraries/SwapHelper.sol#L65)
- 



## Impacted Contracts and functions 
- LBPair.swap


## Install foundry

Foundry documentation can be found [here](https://book.getfoundry.sh/forge/index.html).

### On Linux and macOS

Open your terminal and type in the following command:

```
curl -L https://foundry.paradigm.xyz | bash
```

This will download foundryup. Then install Foundry by running:

```
foundryup
```

To update foundry after installation, simply run `foundryup` again, and it will update to the latest Foundry release.
You can also revert to a specific version of Foundry with `foundryup -v $VERSION`.

### On Windows

If you use Windows, you need to build from source to get Foundry.

Download and run `rustup-init` from [rustup.rs](https://rustup.rs/). It will start the installation in a console.

After this, run the following to build Foundry from source:

```
cargo install --git https://github.com/foundry-rs/foundry foundry-cli anvil --bins --locked
```

To update from source, run the same command again.

## Install dependencies

To install dependencies, run the following to install dependencies:

```
forge install
```

___

## Tests

To run tests, run the following command:

```
forge test
```

To run slither, run the following command:

```
slither --solc-remaps "ds-test/=lib/forge-std/lib/ds-test/src/ forge-std/=lib/forge-std/src/ openzeppelin/=lib/openzeppelin-contracts/contracts/" src/
```
