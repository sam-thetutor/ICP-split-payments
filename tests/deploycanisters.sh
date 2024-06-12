# This file is used to deploy the necessary canisters for the backend smart contract.
# ICP_ledger,ckBTC_ledger and ckETH_ledger

NETWORK="local"

dfx canister create ckETH_ledger --network "${NETWORK}"
dfx canister create ICP_ledger --network "${NETWORK}"
dfx canister create ckBTC_ledger --network "${NETWORK}"

# export the token ledger canisters

CKBTCLEDGERID="$(dfx canister id ckBTC_ledger --network "${NETWORK}")"
echo $CKBTCLEDGERID

CKETHLEDGERID="$(dfx canister id ckETH_ledger --network "${NETWORK}")"
echo $CKBTCLEDGERID

ICPLEDGERID="$(dfx canister id ICP_ledger --network "${NETWORK}")"
echo $ICPLEDGERID

# create and export a new identity that will receive the initial token allocation from the ledger canisters
echo "ceating new identity Rec-Identity"
dfx identity new Rec-Identity

echo "exporting the Rec-Ientity principal"
export REC_IDENTITY+$(dfx identity get-principal)
echo $REC_IDENTITY

echo "exporting the Rec_identity account id"
export DEFAULT_ACCOUNT_ID=$(dfx ledger account-id)
echo $DEFAULT_ACCOUNT_ID

# create a new identity that will be the controller of all the token ledger canisters
echo "ceating new identity MINTER"
dfx identity new MINTER
dfx identity use MINTER

echo "exporting the minter identity principal address"
MINTERID="$(dfx identity get-principal)"
echo $MINTERID

echo "exporting the minter identity account_id"
export MINTER_ACCOUNT_ID=$(dfx ledger account-id)
echo $MINTER_ACCOUNT_ID


## deploy the ICP ledger canister
echo "Deploying ICP_ledger canister..."
dfx deploy  ICP_ledger --argument "
  (variant {
    Init = record {
      minting_account = \"$MINTER_ACCOUNT_ID\";
      initial_values = vec {
        record {
          \"$DEFAULT_ACCOUNT_ID\";
          record {
            e8s = 10_000_000_000 : nat64;
          };
        };
      };
      send_whitelist = vec {};
      transfer_fee = opt record {
        e8s = 10_000 : nat64;
      };
      token_symbol = opt \"ICP\";
      token_name = opt \"Local ICP\";
    }
  })
" --mode=reinstall -y

## deploy the ckbtc ledger canister
echo "Deploying ckBTC_ledger canister......."
dfx deploy --network "${NETWORK}" ckBTC_ledger --argument '
  (variant {
    Init = record {
      token_name = "Testnet ckBTC";
      token_symbol = "ckBTC";
      minting_account = record { owner = principal "'${MINTERID}'";};
      initial_balances = vec { record { record { owner = principal "'${REC_IDENTITY}'";}; 100_000_000_000; }; };
      metadata = vec {};
      transfer_fee = 10;
      archive_options = record {
        trigger_threshold = 2000;
        num_blocks_to_archive = 1000;
        controller_id = principal "'${MINTERID}'";
      }
    }
  })
' --mode=reinstall -y

## deploy the ckbtc ledger canister
echo "Deploying ckETH_ledger canister......."
dfx deploy --network "${NETWORK}" ckETH_ledger --argument '
  (variant {
    Init = record {
      token_name = "Testnet ckETH";
      token_symbol = "ckETH";
      minting_account = record { owner = principal "'${MINTERID}'";};
      initial_balances = vec { record { record { owner = principal "'${REC_IDENTITY}'";}; 100_000_000_000; }; };
      metadata = vec {};
      transfer_fee = 10;
      archive_options = record {
        trigger_threshold = 2000;
        num_blocks_to_archive = 1000;
        controller_id = principal "'${MINTERID}'";
      }
    }
  })
' --mode=reinstall -y




