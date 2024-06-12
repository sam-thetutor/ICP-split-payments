# Token Spliiting Smart contract

- A smart contract canister that splits tokens deposits in the ratio of 99:1
- 99% is sent to the vendor's address
- 1% is sent to the relayer's address
- Incase the vendor's address is not configured, 99% is refunded to the sender and 1% remains in the custody of the contract
- Tokens accepted, ICP ckETH,ckBTC and any other token that follows the ICRC token standard


To  run the project locally

 - Clone it from the repo

```bash
git clone https://github.com/sam-thetutor/ICP-split-payments

cd ICP-Split-payments

./deployCan.sh 
```

This will install the necessary canisters for you to start interacting with the project

The smart contract takes in some initial arguments before it can be instatiated

- the canister id of the ICP ledger canister depending on the network(local or ic)
- the duration that the smart contract should check for new transaction. This has to be specified in seconds
- The account id of the smart contract itself. This can be retrived by using dfx. Below is how the method to deploy the smart contract looks like

```bash

dfx deploy backend --network "${NETWORK}" --argument '
    record {
        icpLedger = "'${ICPLEDGERID}'";
        monitor= '${MONITOR_SECONDS}';
        scAccIdentifier = "'${SM_ACC_IDENTIFIER}'"
    }
' --mode=reinstall -y

```

Once the smart contract is deploy, it automatically starts a monitoring instance. You just need to add the token ledger canisters that you are interested to be monitored. This ca be done using the `addNewCanister` method that takes in the name of the token and the canister id of the token ledger

- Depending on how long the monitoring duration is, once that period elapses, the smart contract will fetch all the transactions that happened from the last time it checked. And it will try to look for those transactions where the recipient is itself.

- For now the smart contract is open and has no admin, and that means anyone can chnage the details of forexample the vendorAddress or the relayer address. Thus it should not be exposed to the audience until it is gated.

#### To test the project

- navigate to the tests folder and run

  ```bash
  /deploycanisters.sh
  ```

