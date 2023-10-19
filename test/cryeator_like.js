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

    assert.equal(content1Instance.likes, 0, "no reaction yet");
    assert.equal(content1Instance.totalLikersCounts, 0, "no reactor yet");
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
    const firstLikeWei = numberToWei(firstLike);



    await cryeator.likeContent(accounts[0], content1, firstLikeWei, {
      from: liker1,
    });

    
    let content = await cryeator.getContent(accounts[0], content1);
    let reactions = await cryeator.getContentLikesReactions(accounts[0], content1, 1, content.totalLikersCounts)
    let totalLikes = await cryeator.getContentAddressTotalLikeValue(accounts[0], liker1, content1)

    let reaction = await cryeator.getLikeRaction(accounts[0], content1, content.totalLikersCounts)

    assert.equal(reaction.addr, liker1, "address did not match")
    assert.equal(weiToNumber(content.likes), firstLike, "like not match")
    assert.equal(content.totalLikersCounts, 1, "like reaction ID not updated")
    assert.equal(reactions.length, 1, "reactor stats not added")
    assert.equal(reactions[0].addr, liker1, "reactor address not updated")
    assert.equal(weiToNumber(totalLikes), firstLike, "total likes should equal like")

    await cryeator.likeContent(accounts[0], content1, firstLikeWei, {
      from: liker1,
    });
    

    content = await cryeator.getContent(accounts[0], content1);
    reactions = await cryeator.getContentLikesReactions(accounts[0], content1, 1, content.totalLikersCounts)
    totalLikes = await cryeator.getContentAddressTotalLikeValue(accounts[0], liker1, content1)
    
    const secondLike = firstLike * 2

    assert.equal(weiToNumber(content.likes), secondLike, "like not match")
    assert.equal(content.totalLikersCounts, 2, "like reaction ID not updated")
    assert.equal(reactions.length, 2, "reactor stats not added")
    assert.equal(reactions[1].addr, liker1, "reactor address not updated")
    assert.equal(reactions[0].addr, reactions[1].addr, "reactor is the same address")
    assert.equal(weiToNumber(totalLikes), secondLike, "total likes should equal like")
  });
});
