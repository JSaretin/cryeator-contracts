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

  it("like content", async () => {
    const cryeator = await CryeatorContent.deployed();

    const firstLike = 500;
    const secondLike = 100;

    const firstLikeWei = numberToWei(firstLike);
    const secondLikeWei = numberToWei(secondLike);

    const contractBalanceBeforeLikes = await cryeator.balanceOf(
      cryeator.address
    );

    await cryeator.likeContent(accounts[0], content1, firstLikeWei, {
      from: liker1,
    });
    await cryeator.likeContent(accounts[0], content2, secondLikeWei, {
      from: liker2,
    });

    const contractBalanceAfterLikes = await cryeator.balanceOf(
      cryeator.address
    );

    const content1Instance = await cryeator.getContent(accounts[0], content1);
    const content2Instance = await cryeator.getContent(accounts[0], content2);

    assert.equal(
      weiToNumber(content1Instance.likes),
      firstLike,
      "likes should be equal to the amount used to like"
    );
    assert.equal(
      weiToNumber(content2Instance.likes),
      secondLike,
      "likes should be equal to the amount used to like"
    );

    assert.equal(
      content1Instance.likers.length,
      1,
      "liker address not added to list of likers"
    );
    assert.equal(
      content2Instance.likers.length,
      1,
      "liker address not added to list of likers"
    );

    assert.equal(
      content1Instance.likers[0],
      accounts[1],
      "address is not liker"
    );
    assert.equal(
      content2Instance.likers[0],
      accounts[2],
      "address is not liker"
    );
    assert.equal(
      weiToNumber(contractBalanceAfterLikes),
      weiToNumber(contractBalanceBeforeLikes) + firstLike + secondLike,
      "token not deposited to contract"
    );
  });
});
