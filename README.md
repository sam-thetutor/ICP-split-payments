# Token Spliiting Smart contract

- A smart contract canister that splits tokens deposits in the ratio of 99:1
- 99% is sent to the vendor's address
- 1% is sent to the relayer's address
- Incase the vendor's address is not configured, 99% is refunded to the sender and 1% remains in the custody of the contract
- Tokens accepted, ICP ckETH,ckBTC and any other token that follows the ICRC token standard
- To prevent against attacks, it can only perform transactions where the deposit is double or equal to the transaction fees



## Steps on how to use the smart contract

- Deploy the contract on the network of your choice(local or ic)
- Add the token ledger canisters that you want to be monitored using the `addNewCanister` method. Forexample to add icp ledger, call the addNewCanister method and supply "ICP" and "ryjl3-tyaaa-aaaaa-aaaba-cai". token names should be in capital letters
- Send the payment to the smart contract principal address and it will be split in a ratio of 99:1
- 99% will be sent to the vendor while 1% will be sent to the elayer(commissioner) that you specify
- call the `get_payments_history` method to see all the split payments that have happened.

GOOD LUCK

**To  run the project locally**

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
