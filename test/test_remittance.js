const truffleAssert = require('truffle-assertions');
const RemittanceContract = artifacts.require("./Remittance.sol");

contract('Remittance', function(accounts) {

    [ownerAccount, firstAccount] = accounts;
    const password1 = 'password1';
    const password2 = 'password2';
    
    const falsePassword1 = 'something';
    const falsePassword2 = 'something else';

    let instance;
    const valueToSend = web3.utils.toWei('0.1', 'ether');

    beforeEach('initialise contract', done => {

        RemittanceContract.new({from: ownerAccount})
            .then(_instance => {
                instance = _instance;
                done();
            })
            .catch(done);
    });
    
    it('Running by default is true', done => {

        instance.getRunning.call()
            .then(running => {
                assert.isTrue(running);
                done();
            })
            .catch(done);
    });

    it('Should be locked after a successful deposit', function(done) {

        instance.deposit(web3.utils.keccak256(password1), web3.utils.keccak256(password2), 
                        {from:ownerAccount, value:valueToSend})
            .then(function(txObj) {
                
                assert.strictEqual(txObj.logs.length, 1, 'We should have an event');
                assert.strictEqual(txObj.logs[0].event, 'LogDeposit');
                
                truffleAssert.reverts(
                    instance.deposit(web3.utils.keccak256(password1), web3.utils.keccak256(password2),
                                    {from:ownerAccount, value:valueToSend}), 
                    'Remittance is locked'
                );
                
                done();
            })
            .catch(done);
    });

    it('Deposit should revert if no value', function() {

        truffleAssert.reverts(
            instance.deposit(web3.utils.keccak256(password1), web3.utils.keccak256(password2), 
                            {from:ownerAccount, value:'0'}),
            'Need to deposit something');
    });

    it('Should be unable to withdraw deposit with invalid passwords', function(done) {

        instance.deposit(web3.utils.keccak256(password1), web3.utils.keccak256(password2), 
                        {from:ownerAccount, value:valueToSend})
            .then(function(txObj) {
                
                assert.strictEqual(txObj.logs.length, 1, 'We should have an event');
                assert.strictEqual(txObj.logs[0].event, 'LogDeposit');
                
                truffleAssert.reverts(
                    instance.withdraw(  web3.utils.stringToHex(falsePassword1), web3.utils.stringToHex(falsePassword2), 
                                        {from:firstAccount}),
                    'Invalid answer'
                );
                
                done();
            })
            .catch(done);
    });

    it('Should be unable to withdraw if locked', function() {

        truffleAssert.reverts(
            instance.withdraw(  web3.utils.stringToHex(falsePassword1), 
                                web3.utils.stringToHex(falsePassword2), 
                                {from:ownerAccount}),
            'Remittance is unlocked');
    });

    it('Should be able to withdraw deposit with valid passwords', function(done) {

        instance.deposit(web3.utils.keccak256(password1), web3.utils.keccak256(password2), 
                        {from:ownerAccount, value:valueToSend})
            .then(function(txObj) {
                
                assert.strictEqual(txObj.logs.length, 1, 'We should have an event');
                assert.strictEqual(txObj.logs[0].event, 'LogDeposit');
                
                return instance.withdraw(   web3.utils.stringToHex(password1), 
                                            web3.utils.stringToHex(password2), 
                                            {from:firstAccount});
            })
            .then(function(txObj) {
                
                assert.strictEqual(txObj.logs.length, 1, 'We should have an event');
                assert.strictEqual(txObj.logs[0].event, 'LogTransfer');
                
                done();
            })
            .catch(done);
    });

});