const { ethers } = require('hardhat'); 
const { expect } = require('chai');

describe('[Challenge] Truster', function () {
    let deployer, player;
    let token, pool;
    let attack;

    const TOKENS_IN_POOL = 1000000n * 10n ** 18n;

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, player] = await ethers.getSigners();

        token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();
        pool = await (await ethers.getContractFactory('TrusterLenderPool', deployer)).deploy(token.address);
        expect(await pool.token()).to.eq(token.address);

        await token.transfer(pool.address, TOKENS_IN_POOL);
        expect(await token.balanceOf(pool.address)).to.equal(TOKENS_IN_POOL);

        expect(await token.balanceOf(player.address)).to.equal(0);
    });

    it('Execution', async function () {
        const AttackFactory = await ethers.getContractFactory('AttackTruster', deployer);
        attack = await AttackFactory.connect(player).deploy(player.address,pool.address,token.address,TOKENS_IN_POOL);
    });

    after(async function () {
        /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */
        expect(await ethers.provider.getTransactionCount(player.address)).to.eq(1);

        // Player has taken all tokens from the pool
        expect(
            await token.balanceOf(player.address)
        ).to.equal(TOKENS_IN_POOL);
        expect(
            await token.balanceOf(pool.address)
        ).to.equal(0);
    });
});

