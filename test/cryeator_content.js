const CryeatorContent = artifacts.require("CryeatorPackage");

contract("CryeatorContent", function (accounts) {
  it("creator can post content", async function () {
    const contract = await CryeatorContent.deployed();
    const contentID = "postID1";
    let authorContents = await contract.getCreatorContentCounts(accounts[1]);
    assert(authorContents.toNumber() == 0);
    await contract.createContent(contentID, { from: accounts[1] });
    authorContents = await contract.getCreatorContentCounts(accounts[1]);
    assert(authorContents.toNumber() == 1);
  });

  it("creator can not post duplicated content", async () => {});

  it("users can like existing post", async () => {
    const contract = await CryeatorContent.deployed();
    const contentID = "postID1";
    let content = await contract.getCreatorContent(accounts[1], contentID);
    assert(content.likes == 0);
    const amount = web3.utils.toWei("1000", "ether");
    await contract.likeContent(accounts[1], contentID, amount, {
      from: accounts[0],
    });
    content = await contract.getCreatorContent(accounts[1], contentID);
    assert(content.likes == amount);
  });

  it("users can dislike existing post", async () => {
    const contract = await CryeatorContent.deployed();
    const contentID = "postID1";

    const amount = web3.utils.toWei("200", "ether");
    await contract.transfer(accounts[3], amount, { from: accounts[0] });
    let balance = await contract.balanceOf(accounts[3]);
    assert(balance == amount, "wallet didn't get the transfered token");

    let content = await contract.getCreatorContent(accounts[1], contentID);
    assert(content.dislikes == 0);

    await contract.dislikeContent(accounts[1], contentID, amount, {
      from: accounts[3],
    });
    content = await contract.getCreatorContent(accounts[1], contentID);
    assert(content.dislikes == amount);
  });

 
  it("creator can withdraw content reward", async () => {
    const contract = await CryeatorContent.deployed();
    const contentID = "postID1";
    let content = await contract.getCreatorContent(accounts[1], contentID);
    assert(content.withdrawn == 0);

    const contentEarning = content.likes - content.dislikes;

    await contract.withdrawAllContentEarning(contentID, accounts[1], {
      from: accounts[1],
    });

    const balance = await contract.balanceOf(accounts[1]);
    content = await contract.getCreatorContent(accounts[1], contentID);
    assert(balance == contentEarning, "post earning did not transfer");
    assert(
      content.withdrawn == contentEarning,
      "did not update withdrawn amount"
    );

    const contractBalance = await contract.balanceOf(contract.address);
    assert(contractBalance == 0);
  });


  it("recover owing dislikes before increasing balance", async()=>{
    const contract = await CryeatorContent.deployed();
    const contentID = "postID2";
    await contract.createContent(contentID, { from: accounts[1] });

    let authorContents = await contract.getCreatorContentCounts(accounts[1]);
    assert(authorContents.toNumber() == 2);

    const amount = web3.utils.toWei('1000', 'ether')
    await contract.transfer(accounts[4], amount, {from: accounts[0]})
    await contract.transfer(accounts[5], amount, {from: accounts[0]})

    await contract.dislikeContent(accounts[1], contentID, amount, {from: accounts[4]})
    let contractBalance = await contract.balanceOf(contract.address)
    assert(contractBalance.toNumber()==0, 'dislike not burned')
    await contract.likeContent(accounts[1], contentID, amount, {from: accounts[5]})
    contractBalance = await contract.balanceOf(contract.address)
    assert(contractBalance.toNumber()==0, 'dislike debt not repayed')
  })
});
