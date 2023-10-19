// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {CryeatorToken} from "./CryeatorToken.sol";


contract CryeatorProtection is CryeatorToken {
    mapping(address => mapping(string => mapping(uint256 => bool)))
        private _withdrawInSameBlock;

    function _inWithdraw(
        address _creator,
        string memory _contentID
    ) internal view returns (bool) {
        return _withdrawInSameBlock[_creator][_contentID][_getBlockNumber()];
    }

    function _setInWithdraw(
        address _creator,
        string memory _contentID,
        bool _status
    ) internal {
        _withdrawInSameBlock[_creator][_contentID][_getBlockNumber()] = _status;
    }

    modifier _noReentranceWithdraw(string memory contentID) {
        uint256 currentBlock = _getBlockNumber();
        require(
            !_inWithdraw(_msgSender(), contentID),
            "reentrance not allowed"
        );
        _setInWithdraw(_msgSender(), contentID, true);
        _;
        _setInWithdraw(_msgSender(), contentID, true);
    }
}

abstract contract CryeatorStructure is CryeatorProtection {
    event CreatedContent(address indexed author, string indexed contentID);
    event WithdrawContentReward(
        address indexed author,
        address indexed withdrawTo,
        string indexed contentID,
        uint256 amount
    );

    event LikeContent(
        address indexed liker,
        address indexed creator,
        string indexed contentID,
        uint256 amount
    );
    event DislikeContent(
        address indexed liker,
        address indexed creator,
        string indexed contentID,
        uint256 amount
    );
    event WithdrawContentRewardToLikeConent(
        address indexed author,
        address indexed likedContentAuthor,
        string indexed likedContentID,
        uint256 amount
    );

    error DuplicatedContent();
    error ContentNotFound();
    error ContentRewardNotEnough();
    error WithdrawAmountTooLow();
    error SpentIsGreaterThanEarned();
    error ContentRewardIsTooLow();

    struct Reaction {
        uint256 value;
        address addr;
    }

    struct Post {
        bool created;
        uint256 likes;
        uint256 dislikes;
        uint256 withdrawn;
        uint256 burnt;

        uint256 totalLikersCounts;
        uint256 totalDislikersCounts;
    }

    struct CreatorStats {
        string[] ids;
        uint256 totalContent;
    }
    
    // creator => contentID => (like / dislike) => reactor => totalReaction
    mapping(address=>mapping(string=>mapping(bool=>mapping(address=>uint256)))) internal _totalReactions;
    
    // creator => contentID => (like / dislike) => reactionID => Reaction
    mapping(address=>mapping(string=>mapping(bool=>mapping(uint256=>Reaction)))) internal _reactions;
    
    // creator => contentID => Post data
    mapping(address => mapping(string => Post)) internal _creatorsContent;

    // creator => total content stats
    mapping(address => CreatorStats) internal _creatorsContentIds;

    modifier noDuplicateContent(string memory _contentID) virtual {
        if (_creatorsContent[_msgSender()][_contentID].created) revert DuplicatedContent();
        _;
    }

    modifier _contentExist(address _creator, string memory _contentID) virtual {
        require(_creatorsContent[_creator][_contentID].created, "content not found");
        _;
    }

    function getCreatorContentsIds(address _creator, uint256 _fromIndex, uint256 _toIndex) external view virtual returns (string[] memory contentIDs);
    function getContent(address _creator,string memory _contentID) external view virtual returns (Post memory post);
    function getContentByIndex(address _creator, uint256 _contentIndex) external view virtual returns (Post memory post);
    function getContentsByRange(address _creator, uint256 _contentFromIndex, uint256 _contentToIndex) external view virtual returns (Post[] memory posts);
    function getCreatorContentCounts(address _creator) external view virtual returns (uint256 counts);

    function calculateContentEarningStats(Post memory post) external pure virtual returns (uint256 _freeContentEarning, uint256 _contentOwing){ 
        uint256 _free = (post.likes - (post.withdrawn + post.burnt));
        return (_free, post.dislikes - post.burnt);
    }

    function getContentBalance(address _creator, string memory _contentID) external view virtual returns (uint256 _freeContentEarning, uint256 _contentOwing){
        Post memory post = this.getContent(_creator, _contentID);
        return this.calculateContentEarningStats(post);
    }

    function createContent(string memory _contentID) external virtual returns (bool);
    function likeContent(address _creator, string memory _contentID, uint256 _value) external virtual returns (bool);
    function dislikeContent(address _creator,string memory _contentID,uint256 _value) external virtual returns (bool);
    function likeContentWithContentEarning(address _likeContentCreator, string memory _likeContentID, string memory _contentID, uint256 _value) external virtual returns (bool);
    function likeContentWithAllContentEarning(address _likeContentCreator, string memory _likeContentID, string memory _contentID) external virtual returns (bool);
    function dislikeContentWithContentEarning(address _dislikeContentCreator, string memory _dislikeContentID, string memory _contentID, uint256 _value) external virtual returns (bool);
    function dislikeContentWithAllContentEarning(address _dislikeContentCreator, string memory _dislikeContentID, string memory _contentID) external virtual returns (bool);
    function withdrawContentEarning(address _withdrawTo, string memory _contentID, uint256 _value) external virtual returns (bool);
    function withdrawAllContentEarning(address _withdrawTo,string memory _contentID) external virtual returns (bool);
}


abstract contract ContentGetters is CryeatorStructure {

    
    // get a total of all creator's content
    function getCreatorContentCounts(address _creator) public view override returns (uint256) {
        return _creatorsContentIds[_creator].totalContent;
    }

    // get creator's content IDs (return all the address of the content that has be created by a user)
    function getCreatorContentsIds(address _creator, uint256 _fromIndex, uint256 _toIndex) public view override returns (string[] memory ids) {
        uint256 totalCreatorContent = getCreatorContentCounts(_creator);
        require(_fromIndex <= totalCreatorContent && _toIndex <= totalCreatorContent, "invalid index provided");
        ids = new string[](_toIndex-_fromIndex);
        for (uint256 index; index<ids.length; index++){
            ids[index] = getIndexID(_creator, _fromIndex + index);
        }
    }

    function getIndexID(address _creator, uint256 _contentIndex) public view returns(string memory _contentID) {
        uint256 totalCreatorContent = getCreatorContentCounts(_creator);
        require(_contentIndex <= totalCreatorContent, "invalid index provided");
        _contentID = _creatorsContentIds[_creator].ids[_contentIndex];
    }

    // get creator's content, throw a error if the content is not found
    function getContent(address _creator, string memory _contentID) public view override _contentExist(_creator, _contentID) returns (Post memory){
        return _creatorsContent[_creator][_contentID];
    }

    // get creator content by the ID index
    function getContentByIndex(address _creator, uint256 _contentIndex) public view override returns (Post memory) {
        return getContent(_creator, getIndexID(_creator, _contentIndex));
    }

    // get a range of creator's content
    function getContentsByRange(address _creator, uint256 _contentFromIndex, uint256 _contentToIndex) public view override returns (Post[] memory posts) {
        string[] memory _ids = getCreatorContentsIds(_creator, _contentFromIndex, _contentToIndex);
        posts = new Post[](_ids.length);
        for (uint256 index; index < posts.length; index++) {
            posts[index] = getContentByIndex(_creator, _contentFromIndex + index);
        }
    }


    function getLikeRaction(address _creator, string memory _contentID, uint256 _reactionID) public view returns(Reaction memory reaction){
        require(_reactionID <= getContent(_creator, _contentID).totalLikersCounts, "invalid like ID");
        reaction = _reactions[_creator][_contentID][true][_reactionID];
    }

    function getDislikeRaction(address _creator, string memory _contentID, uint256 _reactionID) public view returns(Reaction memory reaction){
        require(_reactionID <= getContent(_creator, _contentID).totalDislikersCounts, "invalid dislike ID");
        reaction = _reactions[_creator][_contentID][false][_reactionID];
    }

    // get content likes reactions 
    function getContentLikesReactions(address _creator, string memory _contentID, uint256 _fromReactionID, uint256 _toReactionID) public view returns(Reaction[] memory reactions){
        // require(_fromReactionID != 0 && _toReactionID != 0, "invalid reaction ID");
        uint256 totalLikersCounts = getContent(_creator, _contentID).totalLikersCounts;
        require(_fromReactionID <= totalLikersCounts && _toReactionID <= totalLikersCounts, "invalid reaction IDs provided");
        reactions = new Reaction[]((_toReactionID - _fromReactionID) + 1);

        for ( uint256 index; index < reactions.length; index++){
            reactions[index] = getLikeRaction(_creator, _contentID, _fromReactionID+index);
        }
    }

    function getContentDislikesReactions(address _creator, string memory _contentID, uint256 _fromReactionID, uint256 _toReactionID) public view returns(Reaction[] memory reactions){
        // require(_fromReactionID != 0 && _toReactionID != 0, "invalid reaction ID");
        uint256 totalDislikersCounts = getContent(_creator, _contentID).totalDislikersCounts;
        require(_fromReactionID <= totalDislikersCounts && _toReactionID <= totalDislikersCounts, "invalid range provided");
        reactions = new Reaction[]((_toReactionID - _fromReactionID) + 1);

        for ( uint256 index; index < reactions.length; index++){
            reactions[index] = getDislikeRaction(_creator, _contentID, _fromReactionID+index);
        }
    }

    function _getTotalReaction(address _creator, address _reactor, string memory _contentID, bool isLike) private view returns(uint256){
        return _totalReactions[_creator][_contentID][isLike][_reactor];
    }

    function getContentAddressTotalLikeValue(address _creator, address _reactor, string memory _contentID) public view returns(uint256){
        return _getTotalReaction(_creator, _reactor, _contentID, true);
    }

    function getContentAddressTotalDislikeValue(address _creator, address _reactor, string memory _contentID) public view returns(uint256){
        return _getTotalReaction(_creator, _reactor, _contentID, false);
    }

}

abstract contract CoreSetters is ContentGetters {
    error ValueGreaterThanAllowance(uint256 allowance, uint256 spending);
    error LowBalance(uint256 balance, uint256 spending);


    function _replayContentOwing(address _creator, string memory _contentID, Post memory post) internal {
        if (post.dislikes == post.burnt) return;
        (uint256 _freeLikes, uint256 _owingDebt) = this.calculateContentEarningStats(post);
        if (_owingDebt > 0 && _freeLikes > 0) { 
            uint256 toBurn = _owingDebt >= _freeLikes ? _freeLikes : _owingDebt;
            _creatorsContent[_creator][_contentID].burnt += toBurn;
            _burn(address(this), toBurn);
            // stats.burnt += toBurn;
        }
    }

    function _increaseContentWithdrawn(address _creator, string memory _contentID, uint256 _value) internal {
        _creatorsContent[_creator][_contentID].withdrawn += _value;
    }

    function _addReaction(address _reactor, address _creator, string memory _contentID, uint256 _value, bool isLike) private {
        uint256 _reactionID;
        if (isLike) {
            _creatorsContent[_creator][_contentID].likes += _value;
            _creatorsContent[_creator][_contentID].totalLikersCounts++;
            _reactionID = getContent(_creator, _contentID).totalLikersCounts;
        }
        else {
            _creatorsContent[_creator][_contentID].dislikes += _value;
            _creatorsContent[_creator][_contentID].totalDislikersCounts++;
            _reactionID = getContent(_creator, _contentID).totalDislikersCounts;
        }
        _reactions[_creator][_contentID][isLike][_reactionID].addr = _reactor;
        _reactions[_creator][_contentID][isLike][_reactionID].value = _value;
        _totalReactions[_creator][_contentID][isLike][_reactor] += _value; 
    }

    function _addNewLike(address _liker, address _creator, string memory _contentID, uint256 _value) internal {
       _addReaction(_liker, _creator, _contentID, _value, true);
    }

    function _addNewDislike(address _disliker, address _creator, string memory _contentID, uint256 _value) internal {
       _addReaction(_disliker, _creator, _contentID, _value, false);
    }


    function _likeContent(address _liker, address creator, string memory contentID, uint256 _value) internal virtual {
        Post memory post = getContent(creator, contentID);
        _transfer(_liker, address(this), _value);
        _addNewLike(_liker, creator, contentID, _value);
        post.likes += _value;
        _replayContentOwing(creator, contentID, post);
        // stats.deposits += _value;
        emit LikeContent(msg.sender, creator, contentID, _value);
    }

    function _dislikeContent(address _disliker, address creator, string memory contentID, uint256 _value) internal virtual {
        Post memory post = getContent(creator, contentID);
        _burn(_disliker, _value);
        _addNewDislike(_disliker, creator, contentID, _value);
        post.dislikes += _value;
        _replayContentOwing(creator, contentID, post);
        emit DislikeContent(_disliker, creator, contentID, _value);
    }

    function _likeContentWithContentEarning(address _creator, address _likeContentCreator, string memory _likeContentID, string memory _contentID, uint256 _value) internal {
        Post memory post = getContent(_creator, _contentID);
        Post memory likePost = getContent(_likeContentCreator, _likeContentID);

        (uint256 _freeLikes,) = this.calculateContentEarningStats(post);
        if (_value > _freeLikes) revert ContentRewardIsTooLow();

        _increaseContentWithdrawn(_creator, _contentID, _value);
        _addNewLike(_creator, _likeContentCreator, _likeContentID, _value);

        likePost.likes += _value;
        _replayContentOwing(_likeContentCreator, _likeContentID, likePost);
        emit LikeContent(_creator, _likeContentCreator, _likeContentID, _value);
    }

    function _likeContentFrom(address _spender, address _liker, address _creator, string memory _contentID, uint256 _value) internal {
        uint256 allowed = allowance(_liker, _spender);
        if (_value > allowed) revert ValueGreaterThanAllowance({allowance: allowed, spending: _value});
        uint256 balance = balanceOf(_liker);
        if(_value > balance) revert LowBalance({balance: balance, spending: _value});
        _updateAllowance(_liker, _spender, allowance(_liker, _spender) - _value);
        _likeContent(_liker, _creator, _contentID, _value);
    }

    function _dislikeContentWithContentEarning(address _creator, address _dislikeContentCreator, string memory _dislikeContentID, string memory _contentID, uint256 _value) internal{
        Post memory dislikePost = getContent(_dislikeContentCreator, _dislikeContentID);
        Post memory post = getContent(_creator, _contentID);

        (uint256 _freeLikes, ) = this.calculateContentEarningStats(post);
        if (_value > _freeLikes) revert ContentRewardNotEnough();

        _increaseContentWithdrawn(_creator, _contentID, _value);
        _addNewDislike(_creator,_dislikeContentCreator,_dislikeContentID,_value);
        dislikePost.dislikes += _value;
        _replayContentOwing(_dislikeContentCreator, _dislikeContentID, dislikePost);
        emit DislikeContent(_creator,_dislikeContentCreator,_dislikeContentID,_value);
    }

    function _withdrawContentEarning(address _creator, address _to, string memory _contentID, uint256 _value) internal _noReentranceWithdraw(_contentID) {
        (uint256 _freeLikes, ) = this.calculateContentEarningStats(getContent(_creator, _contentID));
        if (_value > _freeLikes) revert ContentRewardNotEnough();
        _increaseContentWithdrawn(_creator, _contentID, _value);
        _transfer(address(this), _to, _value);
        // stats.withdrawn += _value;
        emit WithdrawContentReward(_creator, _to, _contentID, _value);
    }
}


contract CryeatorContent is CoreSetters {
    mapping(address=>mapping(address=>mapping(string=>uint256))) private _contentAllowance;

    event ApproveContent(address indexed _owner, address indexed _spender, string indexed _contentID, uint256 _value);

    struct CryeatorStats{
        uint256 deposits;
        uint256 withdrawn;
        uint256 burnt;
        uint256 contents;
    }

    CryeatorStats public stats;

    

    // return cryeator's stats
    function getStats() public view returns(CryeatorStats memory){
        return stats;
    }

     // allow creator to create new content (duplicate content not allowed)
    function createContent(string memory _contentID) public override noDuplicateContent(_contentID) returns (bool) {
        address _creator = _msgSender();
        _creatorsContent[_creator][_contentID].created = true;
        _creatorsContentIds[_creator].ids.push(_contentID);
        _creatorsContentIds[_creator].totalContent++;
        // stats.contents++;
        return true;
    }


    // like creators content with token
    function likeContent(address _creator, string memory _contentID, uint256 _value) public override returns (bool) {
        _likeContent(_msgSender(), _creator, _contentID, _value);
        return true;
    }

    // dislike content with token
    function dislikeContent(address _creator,string memory _contentID,uint256 _value) public override returns (bool) {
        _dislikeContent(_msgSender(), _creator, _contentID, _value);
        return true;
    }

    // allow a creator to like another creator's content with part of their content earning that is avalible
    function likeContentWithContentEarning(address _likeContentCreator, string memory _likeContentID, string memory _contentID, uint256 _value) public override returns (bool) {
        _likeContentWithContentEarning(_msgSender(), _likeContentCreator, _likeContentID, _contentID, _value);
        return true;
    }

    // allow a creator to like another creator's content with all their content earning that is avalible
    function likeContentWithAllContentEarning(address _likeContentCreator,string memory _likeContentID,string memory _contentID) public override returns (bool) {
        (uint256 _freeLikes, ) = this.calculateContentEarningStats(getContent(_msgSender(), _contentID));
        return likeContentWithContentEarning(_likeContentCreator, _likeContentID, _contentID, _freeLikes);
    }

    // allow a creator to dislike another creator's content with part of their content earning that is avalible
    function dislikeContentWithContentEarning(address _dislikeContentCreator, string memory _dislikeContentID, string memory _contentID, uint256 _value) public override returns (bool){
        _dislikeContentWithContentEarning(_msgSender(), _dislikeContentCreator, _dislikeContentID, _contentID, _value);
        return true;
    }

    // allow a creator to dislike another creator's content with all their content earning that is avalible
    function dislikeContentWithAllContentEarning(address _dislikeContentCreator, string memory _dislikeContentID, string memory _contentID) public override returns (bool) {
        Post memory post = getContent(_msgSender(), _contentID);
        (uint256 _freeLikes,) = this.calculateContentEarningStats(post);
        return dislikeContentWithContentEarning(_dislikeContentCreator, _dislikeContentID, _contentID, _freeLikes);
    }

    // allow a creator to withdraw part of the content that is avalible to another address
    function withdrawContentEarning(address _withdrawTo, string memory _contentID, uint256 _value) public override returns (bool) {
        _withdrawContentEarning(_msgSender(), _withdrawTo, _contentID, _value);
        return true;
    }

    // allow a creator to withdraw all content earning that is avalible to another address
    function withdrawAllContentEarning(address _withdrawTo, string memory _contentID) public override returns (bool) {
        Post memory post = getContent(_msgSender(), _contentID);
        (uint256 _freeLikes, uint256 _owingDebt) = this.calculateContentEarningStats(post);
        if (_owingDebt > _freeLikes) revert ContentRewardIsTooLow();
        return withdrawContentEarning(_withdrawTo, _contentID, _freeLikes);
    }

    // get the content allowance an address can spend on behalf of a creator
    function getContentAllowance(address _owner, address _spender, string memory _contentID) public view _contentExist(_owner, _contentID) returns(uint256){
        return _contentAllowance[_owner][_spender][_contentID];
    }

    // use to set content allowance
    function _approveContent(address _owner, address _spender, string memory _contentID, uint256 _value) private {
        _contentAllowance[_owner][_spender][_contentID] = _value;
    }

    // approve content to another address to spend content earning in behalf of the content creator
    function approveContent(address _spender, string memory _contentID, uint256 _value) public _contentExist(_msgSender(), _contentID) returns(bool){
        address _owner = _msgSender();
        _approveContent(_owner, _spender, _contentID, _value);
        emit ApproveContent(_owner, _spender, _contentID, _value);
        return true;
    }

    // increase content allowance for an address
    function increaseContentAllowance(address _spender, string memory _contentID, uint256 _value) public _contentExist(_msgSender(), _contentID) returns(bool){
        uint256 contentAllowance = getContentAllowance(_msgSender(), _spender, _contentID);
        approveContent(_spender, _contentID, contentAllowance + _value);
        return true;
    }
    
    // decrease content spending allowance for an address
    function decreaseContentAllowance(address _spender, string memory _contentID, uint256 _value) public _contentExist(_msgSender(), _contentID) returns(bool){
        uint256 contentAllowance = getContentAllowance(_msgSender(), _spender, _contentID);
        approveContent(_spender, _contentID, contentAllowance - _value);
        return true;
    }

    // allow another address to spend creator's content earning
    function withdrawContentFrom(address _creator, address _withdrawTo, string memory _contentID, uint256 _value) public {
        address _spender = _msgSender();
        uint256 contentAllowance = getContentAllowance(_creator, _spender, _contentID);
        if (_value > contentAllowance) revert ValueGreaterThanAllowance({allowance: contentAllowance,spending: _value});
        
        (uint256 _freeLikes, ) = this.calculateContentEarningStats(getContent(_creator, _contentID));
        if (_value > _freeLikes) revert ContentRewardNotEnough();

        _approveContent(_creator, _spender, _contentID, contentAllowance - _value);
        _withdrawContentEarning(_creator, _withdrawTo, _contentID, _value);
    }

    // like content using ERC20 allowance
    function likeContentFrom(address _liker, address _creator, string memory _contentID, uint256 _value) public returns(bool){
        _likeContentFrom(_msgSender(), _liker, _creator, _contentID, _value);
        return true;
    }
}
