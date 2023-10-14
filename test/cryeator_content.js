const CryeatorContent = artifacts.require("CryeatorPackage");

function weiToNumber(num) {
  return Number(web3.utils.fromWei(num, "ether"));
}

contract("CryeatorContent", function (accounts) {
  const content1 = "conent1ID";
  const content2 = "conent2ID";

  it("create content", async () => {
    const cryeator = await CryeatorContent.deployed();

    await cryeator.createContent(content1, { from: accounts[0] });
    await cryeator.createContent(content2, { from: accounts[0] });
    await cryeator.createContent(content1, { from: accounts[1] });

    const acc1Contents = await cryeator.getCreatorContentCounts(accounts[0]);
    const acc2Contents = await cryeator.getCreatorContentCounts(accounts[1]);

    assert.equal(acc1Contents.toNumber(), 2, "content creation not updated");
    assert.equal(acc2Contents.toNumber(), 1, "content creation not updated");
  });

  it("like content", async () => {
    const cryeator = await CryeatorContent.deployed();

    const am1 = 500;
    const am2 = 400;

    const amount1 = web3.utils.toWei(am1.toString(), "ether");
    const amount2 = web3.utils.toWei(am2.toString(), "ether");
    await cryeator.transfer(accounts[2], amount1);
    await cryeator.transfer(accounts[3], amount2);

    await cryeator.likeContent(accounts[0], content2, amount1, {
      from: accounts[2],
    });
    await cryeator.likeContent(accounts[1], content1, amount2, {
      from: accounts[3],
    });

    const acc1Content1 = await cryeator.getContent(accounts[0], content1);
    const acc1Content2 = await cryeator.getContent(accounts[0], content2);
    const acc2Content = await cryeator.getContent(accounts[1], content1);

    assert.equal(acc1Content1.likes, 0);
    assert.equal(acc1Content2.likes, amount1, "content like not updated");
    assert.equal(acc2Content.likes, amount2, "content like not updated");

    let contractBalance = await cryeator.balanceOf(cryeator.address);
    assert.equal(
      Number(web3.utils.fromWei(contractBalance, "ether")),
      am1 + am2,
      "likes not deposited to contract"
    );
  });

  it("dislike content", async () => {
    const cryeator = await CryeatorContent.deployed();
    await cryeator.transfer(accounts[4], web3.utils.toWei("1000"));

    let contractBalance = await cryeator.balanceOf(cryeator.address);

    const accContent1 = await cryeator.getContent(accounts[1], content1);
    await cryeator.dislikeContent(accounts[1], content1, accContent1.likes, {
      from: accounts[4],
    });
    assert.equal(
      Number(
        web3.utils.fromWei(await cryeator.balanceOf(cryeator.address), "ether")
      ),
      Number(web3.utils.fromWei(contractBalance, "ether")) -
        Number(web3.utils.fromWei(accContent1.likes, "ether")),
      "content balance not burned"
    );
  });

  it("repay dislikes with likes", async () => {
    const cryeator = await CryeatorContent.deployed();

    const accBalance = await cryeator.balanceOf(accounts[4]);
    let contractBalance = await cryeator.balanceOf(cryeator.address);
    let accContent1 = await cryeator.getContent(accounts[0], content1);

    assert.equal(accContent1.likes, 0);

    await cryeator.dislikeContent(accounts[0], content1, accBalance, {
      from: accounts[4],
    });
    assert.equal(
      web3.utils.fromWei(await cryeator.balanceOf(cryeator.address), "ether"),
      web3.utils.fromWei(contractBalance, "ether"),
      "contract balance changed"
    );

    accContent1 = await cryeator.getContent(accounts[0], content1);
    assert.equal(accContent1.dislikes, accBalance, "dislike not updated");
  });

  it("remove dislikes from likes", async () => {
    const cryeator = await CryeatorContent.deployed();

    let contractBalance = await cryeator.balanceOf(cryeator.address);
    let accContent1 = await cryeator.getContent(accounts[0], content1);
    await cryeator.likeContent(accounts[0], content1, accContent1.dislikes);

    assert.equal(
      web3.utils.fromWei(await cryeator.balanceOf(cryeator.address), "ether"),
      web3.utils.fromWei(contractBalance, "ether"),
      "contract balance changed"
    );

    accContent1 = await cryeator.getContent(accounts[0], content1);

    assert.equal(
      accContent1.likes,
      accContent1.dislikes,
      "likes and dislike should be the same"
    );

    const am = 500;
    const amount = web3.utils.toWei(am.toString(), "ether");
    await cryeator.likeContent(accounts[0], content1, amount);

    // assert(accContent1.likers.length > accContent1.dislikers.length);

    assert.isAbove(
      weiToNumber(await cryeator.balanceOf(cryeator.address)),
      weiToNumber(contractBalance),
      "contract balance not increase"
    );
  });

  it("withdraw content earning", async () => {
    const cryeator = await CryeatorContent.deployed();
    let accContent1 = await cryeator.getContent(accounts[0], content1);
    await cryeator.withdrawAllContentEarning(accounts[5], content1);
    const accBalance = await cryeator.balanceOf(accounts[5]);
    const withdrawn =
      weiToNumber(accContent1.likes) - weiToNumber(accContent1.dislikes);
    assert.equal(weiToNumber(accBalance), withdrawn, "content not withdrawn");
    accContent1 = await cryeator.getContent(accounts[0], content1);
    assert.equal(
      withdrawn,
      weiToNumber(accContent1.withdrawn),
      "withdrawn stats not updated"
    );
  });

  it("like content with content earning", async () => {
    const cryeator = await CryeatorContent.deployed();
    const temp1 = "postID1";
    const temp2 = "postID2";
    await cryeator.createContent(temp1, { from: accounts[5] });
    await cryeator.createContent(temp2, { from: accounts[5] });

    const contents = await cryeator.getCreatorContentCounts(accounts[5]);
    assert.equal(contents, 2, "user created two content");
    let accBalance = await cryeator.balanceOf(accounts[5]);
    await cryeator.likeContent(accounts[5], temp1, accBalance, {
      from: accounts[5],
    });

    accBalance = await cryeator.balanceOf(accounts[5]);
    assert.equal(0, weiToNumber(accBalance), "balance not deducted");

    await cryeator.likeContentWithAllContentEarning(accounts[5], temp2, temp1, {
      from: accounts[5],
    });
    let content1 = await cryeator.getContent(accounts[5], temp1);
    let content2 = await cryeator.getContent(accounts[5], temp2);
    assert.equal(
      weiToNumber(content1.likes),
      weiToNumber(content2.likes),
      "balance should be same"
    );
    assert.equal(
      weiToNumber(content1.withdrawn),
      weiToNumber(content2.likes),
      "withdrawn stats not updated"
    );
  });

  it("get content by index", async () => {
    const cryeator = await CryeatorContent.deployed();
    const temp1 = "postID1";
    const firstContentByID = await cryeator.getContent(accounts[5], temp1);
    const firstContent = await cryeator.getContentByIndex(accounts[5], 0);
    const secondContent = await cryeator.getContentByIndex(accounts[5], 1);
    assert.equal(firstContentByID.likes, firstContent.likes);
    assert.equal(firstContentByID.withdrawn, firstContent.withdrawn);
    assert.equal(secondContent.withdrawn, 0);
  });
  // it("dislike content with content earning", async () => {});

  it("get contents by range", async () => {
    const cryeator = await CryeatorContent.deployed();
    const contentsCounts = await cryeator.getCreatorContentCounts(accounts[5]);
    const contents = await cryeator.getContentsByRange(
      accounts[5],
      0,
      contentsCounts
    );
    assert.equal(contents.length, 2);
  });
});
