const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AddressBook", function () {
  let AddressBook, ab, owner, alice, bob;

  beforeEach(async () => {
    [owner, alice, bob] = await ethers.getSigners();
    AddressBook = await ethers.getContractFactory("AddressBook");
    ab = await AddressBook.deploy();
    await ab.deployed();
  });

  it("adds, finds and lists contacts", async () => {
    // alice adds bob as a contact
    const abAlice = ab.connect(alice);
    const tx = await abAlice.addContact(bob.address, "Bob", "123", "bob@example.com");
    await tx.wait();

    const id = await abAlice.findMyContactIdByWallet(bob.address);
    expect(id.toNumber()).to.equal(1);

    const contact = await abAlice.getMyContact(1);
    expect(contact.name).to.equal("Bob");
    expect(contact.phone).to.equal("123");

    const list = await ab.listContacts(alice.address, 0, 10);
    expect(list.length).to.equal(1);
    expect(list[0].wallet).to.equal(bob.address);
  });

  it("updates and removes contacts", async () => {
    const abAlice = ab.connect(alice);
    await (await abAlice.addContact(bob.address, "Bob", "123", "bob@example.com")).wait();
    await (await abAlice.updateContact(1, bob.address, "Bobby", "999", "bobby@x.com")).wait();

    let c = await abAlice.getMyContact(1);
    expect(c.name).to.equal("Bobby");

    await (await abAlice.removeContact(1)).wait();
    await expect(abAlice.getMyContact(1)).to.be.revertedWith("contact not found");
  });
});
