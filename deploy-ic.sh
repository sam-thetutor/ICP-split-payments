# Run this file to deploy the backend smart contract on the icp mainnet

dfx start --background --clean

export NETWORK="ic"

# create a new canister on the mainnet
dfx canister create backend --network "${NETWORK}"
export BACKENDID=$(dfx canister id backend --network "${NETWORK}")

# get the account id of the backend cnaister in the mainney
export SM_ACC_IDENTIFIER=$(dfx ledger account-id --of-canister "${BACKENDID}" --network "${NETWORK}")
# you can change the number of seconds that the smart contract will be fetching and validating transactions
# if you want faster forwarding of payments, you can reduce the number, but I think 60 seconds is average.
export MONITOR_SECONDS=60;

# icp ledger id on the mainnet
export ICPLEDGERID="ryjl3-tyaaa-aaaaa-aaaba-cai"

echo "deploying the backend smart contract"
dfx deploy backend --network "${NETWORK}" --argument '
    record {
        icpLedger = "'${ICPLEDGERID}'";
        monitor= '${MONITOR_SECONDS}';
        scAccIdentifier = "'${SM_ACC_IDENTIFIER}'"
    }
' --mode=reinstall -y

echo "adding ledgers ICP,ckETH and ckBTC for monitoring"
dfx canister call backend addNewCanister --network "${NETWORK}" '("ICP","'${ICPLEDGERID}'")'
dfx canister call backend addNewCanister --network "${NETWORK}" '("ckETH","'${CKETHLEDGERID}'")'
dfx canister call backend addNewCanister --network "${NETWORK}" '("ckBTC","'${CKBTCLEDGERID}'")'
