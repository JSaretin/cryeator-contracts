const CryeatorContent = artifacts.require("CryeatorContent");

function weiToNumber(num) {
  return Number(web3.utils.fromWei(num, "ether"));
}
function numberToWei(num) {
  return web3.utils.toWei(num.toString(), "ether");
}

contract("CryeatorContent", function (accounts) {
  const content1 = "awesomecontent1ID";
  const content2 = "awesomecontent2ID";
  const content3 = "awesomecontent3ID";

  const liker1 = accounts[1];
  const liker2 = accounts[2];
  const disliker1 = accounts[3];
  const disliker2 = accounts[4];
  const disliker3 = accounts[7];

  it("creates content", async () => {
    const cryeator = await CryeatorContent.deployed();
    await cryeator.createContent(content1);
    await cryeator.createContent(content2);

    let content1Instance = await cryeator.getContent(accounts[0], content1);
    let content2Instance = await cryeator.getContent(accounts[0], content2);

    assert.equal(content1Instance.likes, 0, "no reaction yet");
    assert.equal(content2Instance.likes, 0, "no reaction yet");
    assert.equal(content1Instance.likers.length, 0, "no reactor yet");
    assert.equal(content2Instance.likers.length, 0, "no reactor yet");
  });

  it("should transfer token to reactor", async () => {
    const cryeator = await CryeatorContent.deployed();

    const amount = 5000;
    const weiAmount = numberToWei(amount);

    const addrs = [liker1, liker2, disliker1, disliker2, disliker3];

    await Promise.all(
      addrs.map(async (addr) => {
        await cryeator.transfer(addr, weiAmount);
      })
    );

    const balances = await Promise.all(
      addrs.map(async (addr) => {
        return await cryeator.balanceOf(addr);
      })
    );

    const gotToken =
      balances.filter((bal) => weiToNumber(bal) == amount).length ==
      addrs.length;

    assert.isTrue(gotToken, "address not credited");
  });

  
  it("can like with allowance", async()=>{
    const cryeator = await CryeatorContent.deployed();
    
    const liker = accounts[9]
    
    const walletBalance = await cryeator.balanceOf(liker1)
    await cryeator.approve(liker, walletBalance, {from: liker1});
    let allowance = await cryeator.allowance(liker1, liker)

    assert.equal(weiToNumber(allowance), weiToNumber(walletBalance), "spending not allowed")
    await cryeator.likeContentFrom(liker1, accounts[0], content1, walletBalance, {from: liker});

    let contentToLike = await cryeator.getContent(accounts[0], content1)
    assert.equal(weiToNumber(contentToLike.likes), weiToNumber(walletBalance), "like from did not excute")
    assert.equal(contentToLike.likers[0], liker1, "address should be added to likers list")

    allowance = await cryeator.allowance(liker1, liker)
    assert.equal(weiToNumber(allowance), 0, "allowance not updated after transfrom from")
  })

  it("allow another address to spend content earning", async()=>{
    const cryeator = await CryeatorContent.deployed();

    const spender = accounts[8]
    let content = await cryeator.getContent(accounts[0], content1)
    const toAllow = weiToNumber(content.likes) * 2
    let allowance = await cryeator.getContentAllowance(accounts[0], spender, content1)
    assert.equal(allowance, 0);

    await cryeator.increaseContentAllowance(spender, content1, numberToWei(toAllow))
    allowance = await cryeator.getContentAllowance(accounts[0], spender, content1)
    assert.equal(weiToNumber(allowance), toAllow, "content allowance not increase");

    const accBalance = await cryeator.balanceOf(spender)
    await cryeator.withdrawContentFrom(accounts[0], spender, content1, content.likes, {from: spender})
    const accAferBalance = await cryeator.balanceOf(spender)
    assert.equal(weiToNumber(accAferBalance), weiToNumber(accBalance) + weiToNumber(content.likes), "to wallet should be increased")

    allowance = await cryeator.getContentAllowance(accounts[0], spender, content1)  
    assert.equal(weiToNumber(allowance), weiToNumber(content.likes), "allowance should be reduced")
    await cryeator.decreaseContentAllowance(spender, content1, content.likes)
    
    allowance = await cryeator.getContentAllowance(accounts[0], spender, content1)  
    assert.equal(weiToNumber(allowance), 0, "allowance not decrease")

  })
});
