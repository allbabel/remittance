const truffleAssert = require('truffle-assertions');
const OwnedContract = artifacts.require("./Owned.sol");

contract('Owned', accounts => {

    const ownerAccount = accounts[0];
    const firstAccount = accounts[1];
    const secondAccount = accounts[2];

    it('contract should have an owner', async () => {

        const contract = await OwnedContract.deployed();
        const address = contract.owner.call({from: ownerAccount});

        assert.notEmpty(address, 'Owner address is not valid');
    });

    it('the owner should be able to change the owner', async () => {
        
        const contract = await OwnedContract.deployed();
        const txObj = await contract.changeOwner(firstAccount, {from: ownerAccount});
        
        assert.strictEqual(txObj.logs.length, 1, 'We should have an event');
        assert.strictEqual(txObj.logs[0].event, 'LogOwnerChanged');
    });

    it('only the owner can change the owner', async () => {

        const contract = await OwnedContract.deployed();

        await truffleAssert.reverts(
            contract.changeOwner(firstAccount, {from: secondAccount}),
            'Owner permission required'
        );

    });
});