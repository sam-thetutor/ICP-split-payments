# Scenario when the vendor is not configured
# the smart contract should send back 99% to the sender

echo "TRIGGERING THE NO VENDOR SCENARIO FOR ICP"
echo "switching to the testIdentity"
dfx identity use testIdentity

export TEST_ID=$(dfx identity get-principal)

# first delete the vendor address
echo "deleting the vendor address"
dfx canister call backend deleteVendor --network "${NETWORK}"

# fetch the balance of the vendor bedore the transaction was sent
export ICP_BEFORE=$(dfx canister call ICP_ledger icrc1_balance_of --network "${NETWORK}" '(
    record{
        owner = principal "'${TEST_ID}'";
        subaccount=null
    }
)'
)


# send the payment to trigger the splitting
echo "sending ICP to the smart contract"
dfx canister --network "${NETWORK}" call ICP_ledger icrc1_transfer '
  (record {
    to=(record {
      owner=(principal "'${BACKENDID}'")
    });
    amount=100000000
  })
'
# get the token balance after sending the funds

echo "fetching new balance of the vendor after transaction"
export ICP_AFTER_SENDING=$(dfx canister call ICP_ledger icrc1_balance_of --network "${NETWORK}" '(
    record{
        owner = principal "'${TEST_ID}'";
        subaccount=null
    }
)'
)

echo "waiting for the smart contract to trigger a refund"
sleep 30

# fetch the new balance of the vendor
echo "fetching new balance of the vendor after refund"
export ICP_AFTER_REFUND=$(dfx canister call ICP_ledger icrc1_balance_of --network "${NETWORK}" '(
    record{
        owner = principal "'${TEST_ID}'";
        subaccount=null
    }
)'
)

# display the balances
echo "ICP balance before"
echo $ICP_BEFORE
echo "ICP balance after transacting"
echo $ICP_AFTER_SENDING
echo "ICP balance after refund"
echo $ICP_AFTER_REFUND

