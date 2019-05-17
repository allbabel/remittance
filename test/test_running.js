const truffleAssert = require('truffle-assertions');
const RunningContract = artifacts.require("./Running.sol");

contract('Running', function(accounts) {

    const [ownerAccount, firstAccount] = accounts;
    let instance;

    beforeEach('initialise contract', async function() {

        instance = await RunningContract.new(true, {from: ownerAccount});
    });

    it('Running by default is true', async function() {

        assert.isTrue(await instance.getRunning.call());
    });

    it('the owner should be able to change running', async function() {
        
        const txObj = await instance.pause({from: ownerAccount});
        
        assert.isFalse(await instance.getRunning.call());
        assert.strictEqual(txObj.logs.length, 1, 'We should have an event');
        assert.strictEqual(txObj.logs[0].event, 'LogRunningChanged');
    });

    it('only the owner can change the running state', async function() {

        await truffleAssert.reverts(
            instance.pause({from: firstAccount}),
            'Owner permission required'
        );

    });
});