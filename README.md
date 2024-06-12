# Token Spliiting Smart contract

- A smart contract canister that splits tokens deposits in the ratio of 99:1
- 99% is sent to the vendor's address
- 1% is sent to the relayer's address
- Incase the vendor's address is not configured, 99% is refunded to the sender and 1% remains in the custody of the contract
- Tokens accepted, ICP ckETH,ckBTC and any other token that follows the ICRC token standard


- To  run the project locally

  - Clone it from the repo

```bash
git clone https://github.com/sam-thetutor/ICP-split-payments

cd ICP-Split-payments

./deployCan.sh 
```
This will install the necessary canisters for you to start interacting with the project

- To test the project

  - navigate to the tests folder and run

```bash
/deploycanisters.sh
```
