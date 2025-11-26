async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying with", deployer.address);

  const AddressBook = await ethers.getContractFactory("AddressBook");
  const ab = await AddressBook.deploy();
  await ab.deployed();

  console.log("AddressBook deployed at:", ab.address);
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
