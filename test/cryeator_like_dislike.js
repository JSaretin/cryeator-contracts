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

  const withdrawTo1 = accounts[5];
  const withdrawTo2 = accounts[6];

  const likeAmount1 = 1000;
  const likeAmount2 = 800;
  const dislikeAmount1 = 700;
  const dislikeAmount2 = 2000;

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

  it("like content", async () => {
    const cryeator = await CryeatorContent.deployed();

    const firstLikeWei = numberToWei(likeAmount1);
    const secondLikeWei = numberToWei(likeAmount2);

    await cryeator.likeContent(accounts[0], content1, firstLikeWei, {
      from: liker1,
    });
    await cryeator.likeContent(accounts[0], content2, secondLikeWei, {
      from: liker2,
    });

    content1Instance = await cryeator.getContent(accounts[0], content1);
    content2Instance = await cryeator.getContent(accounts[0], content2);
    const contractBalance = await cryeator.balanceOf(cryeator.address);

    assert.equal(weiToNumber(contractBalance), likeAmount1 + likeAmount2);
    assert.equal(
      weiToNumber(content1Instance.likes),
      likeAmount1,
      "likes should be equal to the amount used to like"
    );
    assert.equal(
      weiToNumber(content2Instance.likes),
      likeAmount2,
      "likes should be equal to the amount used to like"
    );
  });

  it("remove dislike from like on-dislike", async () => {
    const cryeator = await CryeatorContent.deployed();

    const firstDislikeWei = numberToWei(dislikeAmount1);

    let contractBalanceBeforeDislike = await cryeator.balanceOf(
      cryeator.address
    );

    await cryeator.dislikeContent(accounts[0], content1, firstDislikeWei, {
      from: disliker1,
    });

    let contractBalanceAfterDislike = await cryeator.balanceOf(
      cryeator.address
    );
    assert.equal(
      weiToNumber(contractBalanceAfterDislike),
      weiToNumber(contractBalanceBeforeDislike) - dislikeAmount1,
      "dislike not remove from content earning"
    );
  });

  it("repay dislike with new like", async () => {
    const cryeator = await CryeatorContent.deployed();

    await cryeator.createContent(content3);

    const dislikeAmount = numberToWei(dislikeAmount2);

    let contractBalanceBeforeDislike = await cryeator.balanceOf(
      cryeator.address
    );

    await cryeator.dislikeContent(accounts[0], content3, dislikeAmount, {
      from: disliker2,
    });

    const likeAmount = numberToWei(dislikeAmount2 * 2);

    await cryeator.likeContent(accounts[0], content3, likeAmount);

    let contractBalanceAfter = await cryeator.balanceOf(cryeator.address);

    const content = await cryeator.getContent(accounts[0], content3);

    assert.equal(
      weiToNumber(contractBalanceAfter),
      weiToNumber(contractBalanceBeforeDislike) + dislikeAmount2,
      "like should repay debt"
    );

    assert.isAbove(
      weiToNumber(content.likes),
      weiToNumber(content.dislikes),
      "like should be greater than likes"
    );
  });

  it("should withdraw like", async () => {
    const cryeator = await CryeatorContent.deployed();

    const content = await cryeator.getContent(accounts[0], content3);

    const withdrawAmount =
      weiToNumber(content.likes) - weiToNumber(content.dislikes);

    await cryeator.withdrawContentEarning(
      withdrawTo1,
      content3,
      numberToWei(withdrawAmount)
    );

    const walletAfterBalance = await cryeator.balanceOf(withdrawTo1);
    assert(
      weiToNumber(walletAfterBalance),
      withdrawAmount,
      "withdraw did not process"
    );
  });

  it("can dislike content after withdraw", async () => {
    const cryeator = await CryeatorContent.deployed();

    const oldContent = await cryeator.getContent(accounts[0], content3);
    const likes = weiToNumber(oldContent.likes);
    const canWithdrawAmount = likes - weiToNumber(oldContent.dislikes);
    const dislikeAmount = parseInt(likes / 4);
    assert.equal(
      weiToNumber(oldContent.likes) -
        (weiToNumber(oldContent.withdrawn) + weiToNumber(oldContent.dislikes)),
      0,
      "withdraw did not process"
    );

    assert.equal(
      weiToNumber(oldContent.withdrawn),
      canWithdrawAmount,
      "content can withdraw should be zero"
    );

    const contractBalance = await cryeator.balanceOf(cryeator.address);

    // dislike with amount less than earned
    await cryeator.dislikeContent(
      accounts[0],
      content3,
      numberToWei(dislikeAmount),
      { from: disliker3 }
    );

    const newContent = await cryeator.getContent(accounts[0], content3);

    let newContractBalance = await cryeator.balanceOf(cryeator.address);

    assert.equal(
      weiToNumber(oldContent.dislikes) + dislikeAmount,
      weiToNumber(newContent.dislikes)
    );
    assert.equal(
      weiToNumber(contractBalance),
      weiToNumber(newContractBalance),
      "contract balance should stay the same"
    );

    // remove dislike from like when a new like arrive

    await cryeator.likeContent(
      accounts[0],
      content3,
      numberToWei(dislikeAmount * 2)
    );
    newContractBalance = await cryeator.balanceOf(cryeator.address);

    assert.equal(
      weiToNumber(contractBalance) + dislikeAmount,
      weiToNumber(newContractBalance),
      "debt should be repaid and contract balance should stay the same"
    );

    const walletBalance = await cryeator.balanceOf(withdrawTo2);
    await cryeator.withdrawAllContentEarning(withdrawTo2, content3);
    const newWalletBalance = await cryeator.balanceOf(withdrawTo2);
    assert.equal(
      weiToNumber(newWalletBalance),
      weiToNumber(walletBalance) + dislikeAmount,
      "wallet did not get content token"
    );
  });
});
