import Nat "mo:base/Nat";
import TrieMap "mo:base/TrieMap";
import Text "mo:base/Text";
import Result "mo:base/Result";
import Iter "mo:base/Iter";
import Fuzz "mo:fuzz";
import { recurringTimer } "mo:base/Timer";
import Principal "mo:base/Principal";
import Nat64 "mo:base/Nat64";
import Int "mo:base/Int";
import Debug "mo:base/Debug";
import Blob "mo:base/Blob";
import Float "mo:base/Float";
import Time "mo:base/Time";
import Error "mo:base/Error";
import ICPLedgerTypes "./Types/icpledger.types";
import ICRCLedgerTypes "./Types/icrcledger.types";
import Types "Types/Types";
import { toAccount; toSubaccount; toHex } "./utils";
actor class SPLIT({ icpLedger : Text; monitor : Nat; scAccIdentifier : Text }) = this {

  let fuzz = Fuzz.Fuzz();

  //store the information about the canisters of the different tokens
  private var indexCanisters = TrieMap.TrieMap<Text, Types.CanisterData>(Text.equal, Text.hash);

  // ///store the addresses where the tokens will be forwared
  // private var addressesToForward = TrieMap.TrieMap<Text, Types.ForwardAddress>(Text.equal, Text.hash);

  //store the transaction history for the dust transactions
  private var transactionForwardHIstory = TrieMap.TrieMap<Text, Types.ForwardTransaction>(Text.equal, Text.hash);

  //store the recurring payments data
  private var recurringPayments = TrieMap.TrieMap<Principal, Types.RecurringPayments>(Principal.equal, Principal.hash);

  //save the payment history
  private var recurringPayHistory = TrieMap.TrieMap<Text, Types.RecurringPaymentHistory>(Text.equal, Text.hash);

  let tokenActor = actor (icpLedger) : ICPLedgerTypes.Actor;
  stable var contractAccount = scAccIdentifier;
  stable var monitorDuration : Nat = monitor;

  stable var commisionerAccount : ?Text = ?"bd3h5-lf4h2-bovez-alh3a-j4c4f-y7lz2-5vkq5-k22vv-j2vrl-bgyvz-yqe";
  stable var vendorAddress : ?Text = ?"cfodr-7nuj5-mtyou-sccf2-llmlr-fg3u4-nvz5r-aykus-hmpta-25mqm-mae";

  //set the account_identifier for the backend canister
  public func set_account_identifier(id : Text) : async Types.Result<(), Text> {
    contractAccount := id;
    #ok;
  };

  //get the contract identifier

  public query func get_contract_identifier() : async Text {
    return contractAccount;

  };

  //return the monitor duration
  public query func get_monitor_duration() : async Nat {
    return monitorDuration;
  };

  //get account identifier from a prinical address
  public func get_acc_identifier(arr : Principal) : async Text {
    let res = await tokenActor.account_identifier({
      owner = arr;
      subaccount = null;
    });
    return toHex(Blob.toArray(res));
  };

  public func addVendorAddress(addr_ : Text) : async Types.Result<(), Text> {
    try {
      vendorAddress := ?addr_;
      return #ok;
    } catch (error) {
      return #err(Error.message(error));
    };
  };

  //delete address to forward
  public func deleteVendor() : async Types.Result<(), Text> {
    vendorAddress := null;
    return #ok();
  };

  //return the details about the vendor address.
  public query func get_vendor_details() : async ?Text {
    return vendorAddress;
  };

  //add new address to receive forward payments
  public func addCommissioner(arg : Text) : async Types.Result<(), Text> {
    commisionerAccount := ?arg;
    return #ok();
  };

  public func deleteCommisioner() : async Types.Result<(), Text> {
    commisionerAccount := null;
    return #ok();
  };

  //get all addresses to forward the payments to
  public query func get_commissioner_details() : async ?Text {
    return commisionerAccount;
  };

  //get all addresses to forward the payments to
  public query func get_all_canisters() : async [(Text, Types.CanisterData)] {
    return Iter.toArray(indexCanisters.entries());
  };

  //add new address to receive forward payments
  public func addNewCanister(_tokenName : Text, _legCan : Text) : async Types.Result<(), Text> {

    var latestTransactionIndex : Nat = 0;
    var transferFee = 0;
    var conBal : Nat = 0;
    switch (_tokenName) {
      case ("ICP") {

        let response = await tokenActor.query_blocks({
          length = 1;
          start = 1;
        });

        transferFee := await tokenActor.icrc1_fee();

        conBal := await tokenActor.icrc1_balance_of({
          owner = Principal.fromActor(this);
          subaccount = null;
        });

        latestTransactionIndex := Nat64.toNat(response.chain_length);
      };
      case (_) {
        let tokenActor = actor (_legCan) : ICRCLedgerTypes.Actor;
        let response = await tokenActor.get_blocks({
          length = 1;
          start = 1;
        });
        transferFee := await tokenActor.icrc1_fee();
        conBal := await tokenActor.icrc1_balance_of({
          owner = Principal.fromActor(this);
          subaccount = null;
        });

        latestTransactionIndex := Nat64.toNat(response.chain_length);

      };
    };

    let newData : Types.CanisterData = {
      tokenName = _tokenName;
      ledgerCan = _legCan;
      contractBalance = conBal;
      latestTransactionIndex = latestTransactionIndex;
      transferFee = transferFee;
    };
    indexCanisters.put(_tokenName, newData);
    return #ok();
  };

  //withdrwa from the smart contract
  public func withdrawICRC(ledger : Text, amount : Nat, rec : Text) : async Types.Result<(), Text> {

    let tokenActor = actor (ledger) : ICRCLedgerTypes.Actor;
    let transferResult = await tokenActor.icrc1_transfer({
      amount = amount;
      fee = null;
      created_at_time = null;
      from_subaccount = null;
      to = { owner = Principal.fromText(rec); subaccount = null };
      memo = null;
    });

    switch (transferResult) {
      case (#Ok(num)) { return #ok };
      case (_) { #err "failed" };
    };

  };

  system func timer(setGlobalTimer : Nat64 -> ()) : async () {
    let next = Nat64.fromIntWrap(Time.now()) + (Nat64.fromNat(monitorDuration) * 10_00_000_000); // 0.1 seconds
    setGlobalTimer(next);
    await monitorBalances();
  };

  // public func startBalanceMonitor() : async Result.Result<Nat, Text> {
  //   let timer = recurringTimer<system>(#seconds(monitorDuration), monitorBalances);
  //   return #ok(timer);
  // };

  func monitorBalances() : async () {
    for ((tokenName, data) in indexCanisters.entries()) {
      if (tokenName == "ICP") {
        let name : Text = tokenName;
        let data_ = data;
        Debug.print("ICP MONITOR ACTIVE");
        let blocLen = await tokenActor.query_blocks({
          length = 1;
          start = 1;
        });

        //calculate the length of the transactions to fetch
        let leng_ : Nat = Nat64.toNat(blocLen.chain_length);
        let length : Nat = leng_ - data_.latestTransactionIndex;
        Debug.print(" icp latest chain length " # (debug_show (data_.latestTransactionIndex)));
        if (length > 0) {
          let response = await tokenActor.query_blocks({
            length = Nat64.fromNat(leng_ - data_.latestTransactionIndex);
            start = Nat64.fromNat(data_.latestTransactionIndex);
          });
          Debug.print("we got a block");
          for (transac_ in response.blocks.vals()) {
            await filterICPTransactions(transac_);
          };
          Debug.print("done looping icp transactions");
        };
        ignore indexCanisters.replace(name, { data with latestTransactionIndex = leng_ });
      } else {
        let name : Text = tokenName;
        Debug.print(tokenName # " MONITOR ACTIVE");
        let ledger = actor (data.ledgerCan) : ICRCLedgerTypes.Actor;
        //fetch the latest transaction index
        let latTransIndex = await ledger.get_blocks({
          length = 1;
          start = 1;
        });

        Debug.print(name # " latest chain length " # (debug_show (latTransIndex.chain_length)));
        //calculate the length of the transactions to fetch
        let leng_ : Nat = Nat64.toNat(latTransIndex.chain_length);
        let length : Nat = leng_ - data.latestTransactionIndex;

        if (length > 0) {
          //fetch all the transactions that have happened from the last time you fetched them
          let response = await ledger.get_transactions({
            length = leng_ - data.latestTransactionIndex;
            start = data.latestTransactionIndex;
          });
          Debug.print("we have some icrc transactions");

          for (transac_ in response.transactions.vals()) {
            await filterICRCTransactions(ledger, transac_);
          };
          Debug.print("done looping icrc transactions");

        };
        ignore indexCanisters.replace(name, { data with latestTransactionIndex = leng_ });
      };

    };
  };

  func filterICRCTransactions(ledger : ICRCLedgerTypes.Actor, transactions : ICRCLedgerTypes.Transaction) : async () {
    Debug.print("filtering icrc transactions ongoing");
    switch (transactions.transfer) {
      case (?transfer) {
        if (Principal.equal(transfer.to.owner, Principal.fromActor(this))) {

          Debug.print("icrc transfer in place");
          let tranFe = await ledger.icrc1_fee();
          //get the 99%
          let percent99ToSend = retrieveAmount(transfer.amount, 0.99);
          let percent1ToSend = retrieveAmount(transfer.amount, 0.01);
          Debug.print("99% icrc  " # debug_show (percent99ToSend));

          switch (vendorAddress) {
            case (?vendor) {
              let venP = Principal.fromText(vendor);
              if (Nat.greaterOrEqual(percent99ToSend, Nat.mul(2, tranFe))) {
                let amToSend : Nat = percent99ToSend -tranFe;
                ignore await transferICRC(ledger, amToSend, venP, 100);
                Debug.print("done sending 99% to the vendor");

                switch (commisionerAccount) {
                  case (?commissioner) {
                    let comP = Principal.fromText(commissioner);
                    if (Nat.greaterOrEqual(percent1ToSend, Nat.mul(2, tranFe))) {
                      Debug.print(" sendng 1% to the commssioner");
                      ignore await transferICRC(ledger, Nat.sub(percent1ToSend, tranFe), comP, 100);
                      Debug.print(" finished sending 1% to the commssioner");
                    } else {
                      Debug.print("comm amount too low to be sent");
                    };
                  };
                  case (null) {};
                };
              } else {
                Debug.print("99% too low to be sent");
              };

            };
            case (null) {
              //if there is no vendor,send the 99% backend to the account that deposited the funds
              Debug.print("sending 99% back to the sender, Vendor address not configured");
              ignore await transferICRC(ledger, percent99ToSend - tranFe, transfer.from.owner, 100);
            };
          };

        };
      };
      case (null) {};
    };

  };

  func retrieveAmount(amount_ : Nat, perc_ : Float) : Nat {
    return Int.abs(Float.toInt(Float.mul(Float.fromInt(amount_), perc_)));
  };

  func filterICPTransactions(blocks : ICPLedgerTypes.CandidBlock) : async () {
    Debug.print("filtering icp ongoing");
    let transactionType : ICPLedgerTypes.CandidOperation = switch (blocks.transaction.operation) {
      case (?transaction) { transaction };
      case (null) {
        #Burn {
          amount = { e8s = 0 };
          from = Blob.fromArray([]);
          spender = null;
        };
      };
    };

    let transferDetails : {
      amount : Nat64;
      from : Blob;
      to : Blob;
      isTransfer : Bool;
    } = switch (transactionType) {
      case (#Transfer details) {
        {
          amount = details.amount.e8s;
          from = details.from;
          to = details.to;
          isTransfer = true;
        };
      };
      case (_) {
        {
          amount = 0;
          from = Blob.fromArray([]);
          to = Blob.fromArray([]);
          isTransfer = false;
        };
      };
    };

    if (transferDetails.isTransfer) {
      Debug.print("here is a transfer");
      let toAccount = toHex(Blob.toArray(transferDetails.to));
      Debug.print(" to account " # toAccount);
      try {
        if (toAccount == contractAccount) {
          let transFee = await tokenActor.icrc1_fee();
          let isVendor = switch (vendorAddress) {
            case (?vendor) { { isPresent = true; id = vendor } };
            case (_) { { isPresent = false; id = "" } };
          };
          let isComm = switch (commisionerAccount) {
            case (?commissioner) { { isPresent = true; id = commissioner } };
            case (_) { { isPresent = false; id = "" } };
          };

          let percent99ToSend = retrieveAmount(Nat64.toNat(transferDetails.amount), 0.99);
          let percent1ToSend = retrieveAmount(Nat64.toNat(transferDetails.amount), 0.01);
          Debug.print(" 99% amount " # debug_show (percent99ToSend));
          Debug.print(" 1% amount " # debug_show (percent1ToSend));
          Debug.print(" transfer free " # debug_show (transFee));

          if (isVendor.isPresent) {
            let venP = Principal.fromText(isVendor.id);
            if (Nat.greaterOrEqual(percent99ToSend, Nat.mul(2, transFee))) {

              let am99Send : Nat = percent99ToSend -transFee;
              await transferIcpToPrincipal(venP, am99Send, 99);
              Debug.print("done sending to vendor");

              if (isComm.isPresent) {
                //send funds to the commissioner if they are more than the transfer fees
                Debug.print("preo to send 1% to comm");
                if (Nat.greaterOrEqual(percent1ToSend, Nat.mul(2, transFee))) {
                  let am1Send : Nat = percent1ToSend -transFee;
                  await transferIcpToPrincipal(venP, am1Send, 99);
                  Debug.print("done sending comm their portion");
                } else {
                  Debug.print("comm amount too low to be sent");
                };
              } else {
                Debug.print("no commissioner acc detected");
              };

            };

          } else {
            //send 99% back to the user

          };

        };
      } catch (error) {
        Debug.print(Error.message(error));
      };

    };

  };

  func transferIcpToPrincipal(recip_ : Principal, amount_ : Nat, per_ : Float) : async () {

    Debug.print("we are icp 2");
    let transferResult = await tokenActor.icrc1_transfer({
      amount = amount_;
      fee = null;
      created_at_time = null;
      from_subaccount = null;
      to = { owner = recip_; subaccount = null };
      memo = null;
    });

    let transID = fuzz.text.randomAlphabetic(10);
    let name_ = await tokenActor.icrc1_symbol();
    Debug.print("token symbol :" # name_);
    let newHistory : Types.ForwardTransaction = {
      tokenName = name_;
      recipient = Principal.toText(recip_);
      amount = amount_;
      percentage = per_;
      timestamp = Time.now();
      isSent = false;
      errorMessage = null;
    };

    switch (transferResult) {
      case (#Ok(number)) {
        Debug.print("icp transfer successful");
        transactionForwardHIstory.put(transID, { newHistory with isSent = true });
        // return #success(number);
      };
      case (#Err(msg)) {
        Debug.print("ICP transfer error  ");
        switch (msg) {
          case (#BadFee(number)) {
            Debug.print("Bad Fee");
            transactionForwardHIstory.put(transID, { newHistory with isSent = false; errorMessage = ?"Bad fee" });

            // return #error("Bad Fee");
          };
          case (#GenericError(number)) {
            Debug.print("err " #number.message);
            transactionForwardHIstory.put(transID, { newHistory with isSent = false; errorMessage = ?number.message });

            // return #error("Generic");
          };
          case (#InsufficientFunds(number)) {
            Debug.print("insufficient funds");
            transactionForwardHIstory.put(transID, { newHistory with isSent = false; errorMessage = ?"Insufficient Funds" });
            // return #error("insufficient funds");
          };
          case _ {
            Debug.print("ICP error err");
          };
        };
        transactionForwardHIstory.put(transID, { newHistory with isSent = false; errorMessage = ?"ICP transfer Error" });

      };
    };

  };

  func transferIcpToAccId(fee_ : Nat64, recip_ : Blob, amount_ : Nat64, per_ : Float) : async () {
    Debug.print("transfering icp to an account id");
    let transferResults = await tokenActor.transfer({
      to = recip_;
      fee = { e8s = fee_ };
      memo = 1234;
      from_subaccount = null;
      created_at_time = null;
      amount = { e8s = amount_ };
    });

    let transID = fuzz.text.randomAlphabetic(10);
    let name_ = await tokenActor.icrc1_symbol();
    Debug.print("token symbol :" # name_);
    let newHistory : Types.ForwardTransaction = {
      tokenName = name_;
      recipient = toHex(Blob.toArray(recip_));
      amount = Nat64.toNat(amount_);
      percentage = per_;
      timestamp = Time.now();
      isSent = false;
      errorMessage = null;
    };

    switch (transferResults) {
      case (#Ok(number)) {
        Debug.print("icp transfer successful");
        transactionForwardHIstory.put(transID, { newHistory with isSent = true });
        // return #success(number);
      };
      case (#Err(msg)) {
        Debug.print("ICP transfer error  ");
        switch (msg) {
          case (#BadFee(number)) {
            Debug.print("Bad Fee");
            transactionForwardHIstory.put(transID, { newHistory with isSent = false; errorMessage = ?"Bad fee" });

            // return #error("Bad Fee");
          };
          case (#TxTooOld(number)) {
            Debug.print("transaction too old " # debug_show (number.allowed_window_nanos));
            transactionForwardHIstory.put(transID, { newHistory with isSent = false; errorMessage = ?"transaction too old" });

          };
          case (#InsufficientFunds(number)) {
            Debug.print("insufficient funds");
            transactionForwardHIstory.put(transID, { newHistory with isSent = false; errorMessage = ?"Insufficient Funds" });
            // return #error("insufficient funds");
          };
          case _ {
            Debug.print("ICP error err");
          };
        };
        transactionForwardHIstory.put(transID, { newHistory with isSent = false; errorMessage = ?"ICP Error" });

      };
    };

  };

  func transferICRC(ledger : ICRCLedgerTypes.Actor, amount_ : Nat, to_ : Principal, perc_ : Float) : async Types.TransferResult {
    //public shared (message) func transfer(amount_ : Nat, to_ : Principal) : async T.TransferResult {

    let transferResult = await ledger.icrc1_transfer({
      amount = amount_;
      fee = null;
      created_at_time = null;
      from_subaccount = null;
      to = { owner = to_; subaccount = null };
      memo = null;
    });

    let transID = fuzz.text.randomAlphabetic(10);
    let name_ = await ledger.icrc1_symbol();
    Debug.print("token symbol :" # name_);
    let newHistory : Types.ForwardTransaction = {
      tokenName = name_;
      recipient = Principal.toText(to_);
      amount = amount_;
      percentage = perc_;
      timestamp = Time.now();
      isSent = false;
      errorMessage = null;

    };

    switch (transferResult) {
      case (#Ok(number)) {
        Debug.print(name_ # " transfer successful");

        transactionForwardHIstory.put(transID, { newHistory with isSent = true });
        return #success(number);
      };
      case (#Err(msg)) {
        Debug.print("ICP transfer error  ");
        switch (msg) {
          case (#BadFee(number)) {
            Debug.print("Bad Fee");
            transactionForwardHIstory.put(transID, { newHistory with isSent = false; errorMessage = ?"Bad fee" });

            return #error("Bad Fee");
          };
          case (#GenericError(number)) {
            Debug.print("err " #number.message);
            transactionForwardHIstory.put(transID, { newHistory with isSent = false; errorMessage = ?number.message });

            return #error("Generic");
          };
          case (#InsufficientFunds(number)) {
            Debug.print("insufficient funds");
            transactionForwardHIstory.put(transID, { newHistory with isSent = false; errorMessage = ?"Insufficient Funds" });
            return #error("insufficient funds");
          };
          case _ {
            Debug.print("ICP error err");
          };
        };
        transactionForwardHIstory.put(transID, { newHistory with isSent = false; errorMessage = ?"ICP Error" });
        return #error("ICP error Other");
      };
    };
  };

  //get all the logs for the forwarding history
  public query func get_payments_history() : async [(Text, Types.ForwardTransaction)] {
    return Iter.toArray(transactionForwardHIstory.entries());
  };

  //-------------------------------------Recurring payments---------------------------------------------------------

  //let the user deposit money in the special address icp controlled by the canister
  public shared ({ caller }) func depositFunds(amount : Nat) : async Types.Result<(), Text> {
    let account = toAccount({ caller; canister = Principal.fromActor(this) });
    let transferResults = await tokenActor.icrc2_transfer_from({
      to = account;
      fee = null;
      spender_subaccount = null;
      from = {
        owner = caller;
        subaccount = null;
      };
      memo = null;
      created_at_time = null;
      amount = amount;
    });

    switch (transferResults) {
      case (#Ok(num)) {
        return #ok();
      };
      case (#Err(error)) {
        return #err("transfer failed");
      };
    };
  };

  //let the user opt in for recurring payments
  public func subscribeToRecurringPayments(user : Principal) : async Types.Result<(), Text> {
    switch (recurringPayments.get(user)) {
      case (null) {
        recurringPayments.put(user, { amount = 2000; lastPaymentDate = Time.now() });
        return #ok;
      };
      case (?user) { #err "user is already subscribed" };
    };
  };

  //get all the recurring payments
  public query func get_all_recurring_users() : async [(Principal, Types.RecurringPayments)] {
    return Iter.toArray(recurringPayments.entries());
  };

  //activate the recurring payments monitor
  public func startRecurringPaymentsMonitor() : async Result.Result<Nat, Text> {
    let timer = recurringTimer<system>(#seconds(1), monitorMonthlyPayments);
    return #ok(timer);
  };

  func monitorMonthlyPayments() : async () {
    for ((userP, data) in recurringPayments.entries()) {
      if (Time.now() > data.lastPaymentDate + 3 * 60 * 1000000000) {
        Debug.print(" customer " # Principal.toText(userP) # " yes yes ready for monthly billing");
        await transferMonthlyBill(userP, data.amount);

      } else {
        Debug.print(" customer " # Principal.toText(userP) # " no no ready for monthly billing");
      };
    };
  };

  //deposit money
  public func depositTosubAccount(user : Principal) : async Types.Result<(), Text> {

    let transferResult = await tokenActor.icrc1_transfer({
      amount = 10000000;
      from_subaccount = null;
      created_at_time = null;
      fee = null;
      memo = null;
      to = {
        owner = Principal.fromActor(this);
        subaccount = ?toSubaccount(user);
      };
    });

    let payHistory : Types.RecurringPaymentHistory = {
      user = user;
      amount = 10000000;
      receiver = Principal.fromActor(this);
      isPaid = false;
      timestamp = Time.now();

    };
    let payID = fuzz.text.randomAlphabetic(10);
    switch (transferResult) {
      case (#Ok(num)) {
        recurringPayHistory.put(payID, { payHistory with isPaid = true });
        #ok;
      };
      case (#Err(error)) {
        recurringPayHistory.put(payID, { payHistory with isPaid = false });
        #err "mot done"

      };
    };
  };

  //get the user balance for the special account

  public func get_user_balance(user : Principal) : async Nat {
    let result = await tokenActor.icrc1_balance_of({
      owner = Principal.fromActor(this);
      subaccount = ?toSubaccount(user);
    });
    return result;
  };

  func transferMonthlyBill(user : Principal, amount_ : Nat) : async () {

    let transferResult = await tokenActor.icrc1_transfer({
      amount = amount_;
      from_subaccount = ?toSubaccount(user);
      created_at_time = null;
      fee = null;
      memo = null;
      to = {
        owner = Principal.fromActor(this);
        subaccount = null;
      };
    });

    let payHistory : Types.RecurringPaymentHistory = {
      user = user;
      amount = amount_;
      receiver = Principal.fromActor(this);
      isPaid = false;
      timestamp = Time.now();

    };
    let payID = fuzz.text.randomAlphabetic(10);
    switch (transferResult) {
      case (#Ok(num)) {

        recurringPayments.put(user, { amount = amount_; lastPaymentDate = Time.now() });
        recurringPayHistory.put(payID, { payHistory with isPaid = true });
      };
      case (#Err(error)) {

        switch (error) {
          case (#BadFee(number)) {
            Debug.print("Bad Fee");

          };
          case (#GenericError(number)) {
            Debug.print("err " #number.message);

          };
          case (#InsufficientFunds(number)) {
            Debug.print("insufficient funds");
          };
          case _ {
            Debug.print("ICP error err");
          };
        };
        recurringPayHistory.put(payID, { payHistory with isPaid = false })

      };
    };

  };

  //get all the recurring payment history logs
  public query func get_recurring_history() : async [(Text, Types.RecurringPaymentHistory)] {
    return Iter.toArray(recurringPayHistory.entries());
  };

};
