//
//  AccountsViewController.swift
//  Actors
//
//  Created by Dario on 10/5/15.
//  Copyright © 2015 dario. All rights reserved.
//

import Foundation
import Theater

public class Transfer : BankOp {
    let origin : ActorRef
    let destination : ActorRef
    init(origin : ActorRef, destination : ActorRef,
        sender : ActorRef, ammount : Double) {
        self.origin = origin
        self.destination = destination
        super.init(sender: sender, ammount: ammount, operationId: NSUUID())
    }
}

public class TransferResult : BankOpResult {}

public class WireTransferDrone : Actor {
    
    var transfer : Optional<Transfer> = Optional.None
    var bank : Optional<ActorRef> = Optional.None
    
    var transfering : Receive = { (actor : Actor, msg : Message) in
        
        let drone = actor as! WireTransferDrone
        
        switch(msg) {
            case is WithdrawResult:
                let w : WithdrawResult = msg as! WithdrawResult
                if w.result.isSuccess() {
                    drone.transfer!.destination ! Deposit(sender: drone.this, ammount: drone.transfer!.ammount, operationId: NSUUID())
                } else {
                    drone.bank! ! TransferResult(sender: drone.this, operationId: drone.transfer!.operationId, result: w.result)
                    drone.unbecome()
                }
                
                break
            case is DepositResult:
                let w : DepositResult = msg as! DepositResult
                drone.bank! ! TransferResult(sender: drone.this, operationId: drone.transfer!.operationId, result: w.result)
                drone.unbecome()
                break
            
            case is OnBalanceChanged:
                if let transfer = drone.transfer {
                    drone.bank! ! msg
                }
                break
            
            default:
                print("busy, go away")
        }
    }
    
    override public func receive(msg: Message) {
        switch (msg) {
            case is Transfer:
                if let _ = self.transfer {} else {
                    self.transfer = Optional.Some(msg as! Transfer)
                    self.bank = self.transfer!.sender
                    become(transfering)
                    if let transfer = self.transfer {
                        transfer.origin ! Withdraw(sender: this, ammount: transfer.ammount, operationId: NSUUID())
                    }
                }
                break
            
            default:
                super.receive(msg)
        }
    }
}


public class Bank : Actor {
    let accountA = AppActorSystem.shared.actorOf(Account)
    let accountB = AppActorSystem.shared.actorOf(Account)
    var accountALabel : Optional<UILabel> = Optional.None
    var accountBLabel : Optional<UILabel> = Optional.None
    
    public var transfers : [String:(Transfer, Optional<TransferResult>)] = [String : (Transfer, Optional<TransferResult>)]()
    
    @objc func onClickBtoA(click: UIButton) {
        this ! Transfer(origin: accountB, destination: accountA, sender: this, ammount: 1)
    }
    
    @objc func onClickAtoB(click: UIButton) {
        this ! Transfer(origin: accountA, destination: accountB, sender: this, ammount: 1)
    }
    
    @objc func accountBalanceChanged(notif : NSNotification) {
        let account = notif.object as! Account
        ^{
            switch (account.this.path.asString) {
            case self.accountA.path.asString:
                account.balance().map({ (balance : Double) -> (Void) in
                    self.accountALabel?.text =  String(balance)
                })
                break;
            case self.accountB.path.asString:
                account.balance().map({ (balance : Double) -> (Void) in
                    self.accountBLabel?.text =  String(balance)
                })
            
                break;
            default:
                print("account not found \(account.this.path.asString)")
                
            }
        }
    }
    
    override public func receive(msg: Message) {
        switch(msg) {
            case is Transfer:
                let w = msg as! Transfer
                if self.transfers.keys.contains(w.operationId.UUIDString) == false {
                    self.transfers[w.operationId.UUIDString] = (w,Optional.None)
                    let wireTransfer = context.actorOf(WireTransferDrone) //We need to add timeout
                    wireTransfer ! w
                }
            break
            
            case is TransferResult:
                let w = msg as! TransferResult
                let uuid = w.operationId.UUIDString
                if let transfer = self.transfers[uuid] {
                    self.transfers[uuid] = (transfer.0, w)
                }
                
                if w.result.isFailure() {
                    ^{
                        let v = self.transfers[uuid]!
                        UIAlertView(title: "Transaction error from:\(v.0.origin.path.asString) to:\(v.0.destination.path.asString)", message: "\(w.result.description())", delegate: nil, cancelButtonTitle: "ok").show()
                    }
                }
                
                w.sender! ! Harakiri(sender: this)
                
            break
            
            case is HookupViewController:                
                let w = msg as! HookupViewController
                ^{
                    w.ctrl.bToA.addTarget(self, action: "onClickBtoA:", forControlEvents: .TouchUpInside)
                    w.ctrl.aToB.addTarget(self, action: "onClickAtoB:", forControlEvents: .TouchUpInside)
                    self.accountALabel = w.ctrl.accountABalance
                    self.accountBLabel = w.ctrl.accountBBalance
                }
                accountA ! SetAccountNumber(accountNumber: "AccountA", operationId: NSUUID())
                accountB ! SetAccountNumber(accountNumber: "AccountB", operationId: NSUUID())
                
                print("accountA \(accountA.path.asString)")
                print("accountB \(accountB.path.asString)")
            
                accountA ! Deposit(sender: this, ammount: 10, operationId: NSUUID())
                accountB ! Deposit(sender: this, ammount: 10, operationId: NSUUID())
                break;
            
            case is OnBalanceChanged:
                let w = msg as! OnBalanceChanged
                ^{
                    if let account : ActorRef = w.sender {
                        print("account.path.asString \(account.path.asString)" )
                        switch (account.path.asString) {
                            case self.accountA.path.asString:
                                self.accountALabel?.text = w.balance.description
                                break;
                            case self.accountB.path.asString:
                                self.accountBLabel?.text = w.balance.description
                                break;
                            default:
                                print("account not found \(account.path.asString)")
                            
                        }
                   }
                
                }
        
                break;
            default:
                super.receive(msg)
        }
        
    }
    
    @objc public override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        print("got called")
    }
    
    deinit {
    }
    
}

class HookupViewController: Message {
    let ctrl : AccountsViewController
    
    init(ctrl : AccountsViewController) {
        self.ctrl = ctrl
        super.init(sender: Optional.None)
    }
}

public class AccountsViewController : UIViewController {
    
    let  bank : ActorRef = AppActorSystem.shared.actorOf(Bank)
    
    @IBOutlet weak var bToA: UIButton!
    @IBOutlet weak var accountABalance: UILabel!
    @IBOutlet weak var aToB: UIButton!
    @IBOutlet weak var accountBBalance: UILabel!
    
    override public func viewDidLoad() {
        bank ! HookupViewController(ctrl: self)
    }
}