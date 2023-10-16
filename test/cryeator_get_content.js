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

  it("create and get total content counts", async () => {
    const cryeator = await CryeatorContent.deployed();
    const ids = [content1, content2, content3];
    await Promise.all(
      ids.map(async (id) => {
        await cryeator.createContent(id);
      })
    );

    const contentCounts = await cryeator.getCreatorContentCounts(accounts[0]);
    assert.equal(
      contentCounts.toNumber(),
      ids.length,
      "length should be the same with ids length"
    );
  });

  it("get content by ID", async () => {
    const cryeator = await CryeatorContent.deployed();
    const contentByID = await cryeator.getContent(accounts[0], content1);
    assert.equal(weiToNumber(contentByID.likes), 0);
  });

  it("get content by Index", async () => {
    const cryeator = await CryeatorContent.deployed();
    const contentByIndex = await cryeator.getContentByIndex(accounts[0], 0);
    assert.equal(weiToNumber(contentByIndex.likes), 0);
  });

  it("get range of content", async () => {
    const cryeator = await CryeatorContent.deployed();
    const contentCounts = await cryeator.getCreatorContentCounts(accounts[0]);
    const contents = await cryeator.getContentsByRange(
      accounts[0],
      1,
      contentCounts
    );
    assert.equal(contents.length, 2, "should return 2 content");
  });
});
