const Cryeator = artifacts.require("CryeatorToken");

contract("Cryeator", function (accounts) {

  it("can toggle tax", async () => {
    const contract = await Cryeator.deployed();
    let status = await contract.taxStatus();
    assert(status == false);
    await contract.toggleTaxStatus({ from: accounts[0] });
    status = await contract.taxStatus();
    assert(status == true, "status not updated after toggle");
  });

  it("won't collect tax from team", async () => {
    const contract = await Cryeator.deployed();
    let isTeam = await contract.isTaxFree(accounts[0]);
    assert(isTeam == true);
    assert(isTeam != (await contract.isTaxFree(accounts[1])));

    const amount = web3.utils.toWei("100", "ether");
    await contract.transfer(accounts[1], amount, { from: accounts[0] });

    let bal = await contract.balanceOf(accounts[1]);

    assert(bal == amount, "balance not updated");

    let oldTotalSupply = await contract.totalSupply();
    await contract.transfer(accounts[2], amount, { from: accounts[1] });

    bal = await contract.balanceOf(accounts[2]);

    assert(bal == web3.utils.toWei("94", "ether"), "tax not removed");

    let newTotalSupply = await contract.totalSupply();

    assert(oldTotalSupply != newTotalSupply, "token not burned");
  });

  it("can add team wallet", async () => {
    const contract = await Cryeator.deployed();
    let isTeam = await contract.isTaxFree(accounts[4]);
    assert(isTeam == false);
    await contract.addTaxFree(accounts[4], { from: accounts[0] });
    isTeam = await contract.isTaxFree(accounts[4]);
    assert(isTeam == true);
  });

  it("can remove team wallet", async () => {
    const contract = await Cryeator.deployed();
    let isTeam = await contract.isTaxFree(accounts[4]);
    assert(isTeam == true);
    await contract.removeTaxFree(accounts[4], { from: accounts[0] });
    isTeam = await contract.isTaxFree(accounts[4]);
    assert(isTeam != true);
  });

  it("can approve to wallet", async()=>{
    const contract = await Cryeator.deployed();
    let allowance = await contract.allowance(accounts[0], accounts[3])
    assert(allowance.toNumber() == 0)

    const amount = web3.utils.toWei('1000', 'ether')

    await contract.approve(accounts[3], amount, {from: accounts[0]})
    allowance = await contract.allowance(accounts[0], accounts[3])
    assert(allowance == amount, "approval not granted")
    
    await contract.transferFrom(accounts[0], accounts[3], amount, {from: accounts[3]});

    allowance = await contract.allowance(accounts[0], accounts[3])
    assert(allowance.toNumber() == 0, "allownace not decreased")

    const balance = await contract.balanceOf(accounts[3])
    assert(balance == amount, "transferFrom did not work")
  })
});
