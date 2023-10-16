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

  const liker1 = accounts[1];
  const liker2 = accounts[2];
  const disliker1 = accounts[3];
  const disliker2 = accounts[4];

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

    const addrs = [liker1, liker2, disliker1, disliker2];

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

  it("dislike content", async () => {
    const cryeator = await CryeatorContent.deployed();

    const firstDislike = 500;
    const secondDislike = 100;

    const firstDislikeWei = numberToWei(firstDislike);
    const secondDislikeWei = numberToWei(secondDislike);

    const contractBalanceBeforeDislikes = await cryeator.balanceOf(
      cryeator.address
    );

    await cryeator.dislikeContent(accounts[0], content1, firstDislikeWei, {
      from: accounts[1],
    });
    await cryeator.dislikeContent(accounts[0], content2, secondDislikeWei, {
      from: accounts[2],
    });

    const contractBalanceAfterDislikes = await cryeator.balanceOf(
      cryeator.address
    );

    const content1Instance = await cryeator.getContent(accounts[0], content1);
    const content2Instance = await cryeator.getContent(accounts[0], content2);

    assert.equal(
      weiToNumber(contractBalanceAfterDislikes),
      weiToNumber(contractBalanceBeforeDislikes),
      "contract balance should stay them same"
    );
    assert.equal(
      weiToNumber(content1Instance.dislikes),
      firstDislike,
      "dislikes should be equal to the amount used to dislike"
    );
    assert.equal(
      weiToNumber(content2Instance.dislikes),
      secondDislike,
      "dislikes should be equal to the amount used to dislike"
    );

    assert.equal(
      content1Instance.dislikers.length,
      1,
      "disliker address not added to list of dislikers"
    );
    assert.equal(
      content2Instance.dislikers.length,
      1,
      "disliker address not added to list of dislikers"
    );

    assert.equal(
      content1Instance.dislikers[0],
      accounts[1],
      "address is not disliker"
    );
    assert.equal(
      content2Instance.dislikers[0],
      accounts[2],
      "address is not disliker"
    );
  });
});
