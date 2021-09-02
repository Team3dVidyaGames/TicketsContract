const Tickets = artifacts.require("Tickets");
const { assert } = require("chai");
const { BN, toWei } = require("web3-utils");
const timeMachine = require('ganache-time-traveler');

contract("Vault", (accounts) => {
    let tickets_contract;

    before(async () => {
        await Tickets.new(
            "0xdD3782915140c8f3b190B5D67eAc6dc5760C46E9",   // Chainlink VRF Coordinator address
            "0xa36085F69e2889c224210F603D836748e7dC0088",   // LINK token address
            "0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4",   // Key Hash
            1, // fee
            { from: accounts[0] }
        ).then((instance) => {
            tickets_contract = instance;
        });
    });

    describe("Claim Ticket", () => {
        it("Each ticket is 0.1 ETH.", async () => {

            try {
                await tickets_contract.claimTicket("https://team3d.io/ticket.png", {value: new BN('1000000000000000000'), from: accounts[1]});
            } catch (error) {
                thrownError = error;
            }

            assert.include(
                thrownError.message,
                'Tickets: Tickets go for 0.1 ETH each.',
            )
        });

        it("Claiming ticket is working", async () => {
            await tickets_contract.claimTicket("https://team3d.io/ticket.png", {value: new BN('100000000000000000'), from: accounts[1]});
            await tickets_contract.claimTicket("https://team3d.io/ticket.png", {value: new BN('100000000000000000'), from: accounts[2]});
            await tickets_contract.claimTicket("https://team3d.io/ticket.png", {value: new BN('100000000000000000'), from: accounts[3]});
        });

    });
});
