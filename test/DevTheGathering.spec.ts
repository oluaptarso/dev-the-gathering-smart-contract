import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { constants } from "ethers";
import { ethers } from "hardhat";
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");

enum DeveloperStatus {
    IDLE,
    OPENING_BOOSTER_PACK
}

describe("DevTheGathering", () => {
    const MOCK_SUBSCRIPTION_ID = 0;
    const MOCK_LINK = constants.AddressZero;

    async function deployContract(
        vrfCoordinatorContract:
            | "MockVRFCoordinator"
            | "MockVRFCoordinatorUnfulfillable" = "MockVRFCoordinator"
    ) {

        const [owner, otherAccount] = await ethers.getSigners();

        const contractFactory = await ethers.getContractFactory("DevTheGathering");

        const vrfCoordFactory = await ethers.getContractFactory(
            vrfCoordinatorContract
        );
        const mockVrfCoordinator = await vrfCoordFactory.connect(owner).deploy();

        const contract = await contractFactory
            .connect(owner)
            .deploy(mockVrfCoordinator.address, MOCK_LINK, MOCK_SUBSCRIPTION_ID);

        return { contract, owner, otherAccount };
    }

    describe("Deployment", function () {
        it("Should have the right owner", async function () {
            const { contract, owner, otherAccount } = await loadFixture(deployContract);
            expect(await contract.owner()).to.equal(owner.address);
        });
    });

    describe("OpenBoosterPack", function () {

        it("Should have set the IDLE status", async function () {
            const { contract, owner } = await loadFixture(deployContract);
            const result = await contract.connect(owner).getMyDeveloperStatus();
            expect(result).to.equal(DeveloperStatus.IDLE);
        });

        it("Should have Not enough balance for the transaction.", async function () {
            const { contract, owner } = await loadFixture(deployContract);
            await expect(contract.connect(owner).openBoosterPack({ value: 200000 })).to.be.revertedWith("Not enough balance.");
        });

        it("Should have worked with the 50000000 value, changed the user status to OPENING_BOOSTER_PACK and trigger the BoosterOpened event.", async function () {
            const { contract, owner } = await loadFixture(deployContract);
            const result = await contract.connect(owner).openBoosterPack({ value: ethers.utils.parseEther('0.5') });
            await expect(result).to.be.not.reverted;

            await expect(await contract.connect(owner).getMyDeveloperStatus()).to.equal(DeveloperStatus.OPENING_BOOSTER_PACK);

            const tx = await result.wait();            

            await expect(result).to.emit(contract, "BoosterOpened")
                .withArgs(0, anyValue, [0,0,0]);
        });

        it("Should have set the status setted back to IDLE", async function () {       
            const { contract, owner } = await loadFixture(deployContract);
            expect(await contract.connect(owner).getMyDeveloperStatus()).to.equal(DeveloperStatus.IDLE);
        });
    })
});