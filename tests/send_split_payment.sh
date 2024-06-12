#!/bin/bash

export VENDORACC="cfodr-7nuj5-mtyou-sccf2-llmlr-fg3u4-nvz5r-aykus-hmpta-25mqm-mae"
export COMMACC="bd3h5-lf4h2-bovez-alh3a-j4c4f-y7lz2-5vkq5-k22vv-j2vrl-bgyvz-yqe"

# trigger the splitting payment feature by depositing funds into the smart contract account

# swtich to the testIdentity
echo -e "\033[32m TRIGGERING THE SPLITTING PAYMENT FEATURE FOR ckETH \033[0m"

echo "switching to the testIdentity"
dfx identity use testIdentity

# check the balance of the two accounts before any spliiting happens

echo "check the icp balances of the vendor and commissioner accounts before spliiting"
echo "initial ICP balance for the vendor"

dfx canister call ICP_ledger icrc1_balance_of --network "${NETWORK}" '(
    record{
        owner = principal "'${VENDORACC}'";
        subaccount=null
    }
)'

echo "initial ICP balance for the commissioner"

dfx canister call ICP_ledger icrc1_balance_of --network "${NETWORK}" '(
    record{
        owner = principal "'${COMMACC}'";
        subaccount=null
    }
)'



# send ICP to the smart contract
echo "sending ICP payment to the smart contract"
echo $BACKENDID

dfx canister --network "${NETWORK}" call ICP_ledger icrc1_transfer '
  (record {
    to=(record {
      owner=(principal "'${BACKENDID}'")
    });
    amount=100000000
  })
'
# echo "sending a ckETH payment to the smart contract"

# dfx canister --network "${NETWORK}" call ckBTC_ledger icrc1_transfer '
#   (record {
#     to=(record {
#       owner=(principal "'${BACKENDID}'")
#     });
#     amount=1000000
#   })
# '

echo "waiting "
echo $MONITOR
echo "for the smart contract to sync the transactions"

sleep 15
# fetch the balances for the vendor addresses and commissioner account to ensure they match the respective amounts

# get the new balances after the smart contract has carried out the splitting

echo "FETCHING NEW VENDOR AND COMMISSIONER ICP BALANCES AFTER TOKEN SPLITTING"
sleep 2

echo "New ICP balance for the vendor"
dfx canister call ICP_ledger icrc1_balance_of --network "${NETWORK}" '(
    record{
        owner = principal "'${VENDORACC}'" ;
        subaccount=null
    }
)'

sleep 2
echo "New ICP balance for the commissioner"
dfx canister call ICP_ledger icrc1_balance_of --network "${NETWORK}"  '(
    record{
        owner = principal "'${COMMACC}'";
        subaccount=null
    }
)'


chmod a+x ./no_vendor.sh
 source ./no_vendor.sh