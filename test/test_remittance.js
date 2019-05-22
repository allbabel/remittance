const truffleAssert = require('truffle-assertions');
const RemittanceContract = artifacts.require("./Remittance.sol");

contract('Remittance', function(accounts) {

    [ownerAccount, firstAccount] = accounts;
    const password1 = 'password1';
    const password2 = 'password2';
    
    const falsePassword1 = 'something';
    const falsePassword2 = 'something else';
    const timeout = 60 * 60 * 24;

    let instance;
    const valueToSend = web3.utils.toWei('0.1', 'ether');
    const passwordHash = web3.utils.soliditySha3(web3.eth.abi.encodeParameters(['string','string'], [password1, password2]));
    
    beforeEach('initialise contract', () => {

        return RemittanceContract.new({from: ownerAccount})
            .then(_instance => {
                instance = _instance;
            })
            .catch(console.err);
    });
    
    it('Running by default is true', () => {

        return instance.getRunning.call()
            .then(running => {
                assert.isTrue(running);
            })
            .catch(console.err);
    });

    it('Should emit on deposit', function() {
        return instance.deposit(passwordHash, 
                                timeout,
                                {from:ownerAccount, value:valueToSend})
            .then(function(txObj) {
                
                assert.strictEqual(txObj.logs.length, 1, 'We should have an event');
                assert.strictEqual(txObj.logs[0].event, 'LogDeposit');
                
            })
            .catch(console.err);
    });

    it('Should be unable to deposit after a successful deposit', function() {

        return instance.deposit(passwordHash, 
                                timeout,
                                {from:ownerAccount, value:valueToSend})
            .then(function(txObj) {
                
                truffleAssert.reverts(
                    instance.deposit(passwordHash, 
                                    timeout,
                                    {from:ownerAccount, value:valueToSend}), 
                    'Deposit exists'
                );
            })
            .catch(console.err);
    });

    it('Deposit should revert if no value', function() {

        return truffleAssert.reverts(
                instance.deposit(   passwordHash, 
                                    timeout,
                                    {from:ownerAccount, value:'0'}),
                'Need to deposit something');
    });

    it('Should be unable to withdraw deposit with invalid passwords', function() {

        return instance.deposit(    passwordHash, 
                                    timeout,
                                    {from:ownerAccount, value:valueToSend})
            .then(function(txObj) {
                
                truffleAssert.reverts(
                    instance.withdraw(  ownerAccount, 
                                        web3.utils.stringToHex(falsePassword1), 
                                        web3.utils.stringToHex(falsePassword2), 
                                        {from:firstAccount}),
                    'Invalid answer'
                );
            })
            .catch(console.err);
    });

    it('Should be unable to withdraw if not already deposited', function() {

        return truffleAssert.reverts(
            instance.withdraw(  ownerAccount,
                                web3.utils.stringToHex(password1), 
                                web3.utils.stringToHex(password2), 
                                {from:ownerAccount}),
            'Invalid deposit');
    });

    it('Should be able to withdraw deposit with valid passwords', function() {

        let originalBalance;
        let txFee;

        return web3.eth.getBalance(firstAccount).
            then(function(balance) {
                originalBalance = web3.utils.toBN(balance);
                return instance.deposit(passwordHash,
                                        timeout, 
                                        {from:ownerAccount, value:valueToSend})        
            })
            .then(function(txObj) {
                
                assert.strictEqual(txObj.logs.length, 1, 'We should have an event');
                assert.strictEqual(txObj.logs[0].event, 'LogDeposit');

                return instance.withdraw(   ownerAccount,
                                            web3.utils.stringToHex(password1), 
                                            web3.utils.stringToHex(password2), 
                                            {from:firstAccount});
            })
            .then(function(txObj) {
                
                assert.strictEqual(txObj.logs.length, 1, 'We should have an event');
                assert.strictEqual(txObj.logs[0].event, 'LogTransfer');

                web3.eth.getTransaction(txObj.receipt.transactionHash, function(err, tx) {
                    
                    txFee = web3.utils.toBN(tx.gasPrice * txObj.receipt.gasUsed);
                    
                    web3.eth.getBalance(firstAccount, function(err, balance) {

                        const newBalance = web3.utils.toBN(balance);
                        assert.strictEqual( originalBalance.add(web3.utils.toBN(valueToSend)).sub(txFee).toString(10), 
                                            newBalance.toString(10),
                                            'New balance is not correct');
                    });
                });
            })
            .catch(console.err);
    });

    it("Owner shouldn't be able to withdraw deposit with valid passwords until expired", function() {

        return instance.deposit(   passwordHash,
                            timeout, 
                            {from:firstAccount, value:valueToSend})        
            .then(function(txObj) {
                
                truffleAssert.reverts(
                    instance.ownerWithdraw( firstAccount,
                                            {from:ownerAccount}),
                    'Deposit is not expired');
            })
            .catch(console.err);
    });

    it('Contract should have a cut of the action', function() {

        return instance.setDepositFee('100', {from: ownerAccount})
            .then(function() {
                
                return instance.depositFee();
            })
            .then(function(depositFee) {

                assert.strictEqual('100', depositFee.toString(), 'Deposit fee is not set');

                return instance.deposit(passwordHash, 
                                        timeout,
                                        {from:ownerAccount, value:valueToSend});
            })
            .then(function(txObj) {
                
                assert.strictEqual(txObj.logs.length, 1, 'We should have an event');
                assert.strictEqual(txObj.logs[0].event, 'LogDeposit');
                
                return instance.withdraw(   ownerAccount,
                                            web3.utils.stringToHex(password1), 
                                            web3.utils.stringToHex(password2), 
                                            {from:firstAccount});
            })
            .then(function(txObj) {
                
                assert.strictEqual(txObj.logs.length, 1, 'We should have an event');
                assert.strictEqual(txObj.logs[0].event, 'LogTransfer');
                
                return web3.eth.getBalance(instance.address);
            })
            .then(function(balance) {
                
                assert.strictEqual(balance, '100', 'The contract should have 100 Wei cut');
                
                return instance.withdrawDepositFees();
            })
            .then(function(txObj) {

                assert.strictEqual(txObj.logs.length, 1, 'We should have an event');
                assert.strictEqual(txObj.logs[0].event, 'LogWithdraw');
            })
            .catch(console.err);
    });
});