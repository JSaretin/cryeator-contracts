// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {CryeatorToken} from "./CryeatorToken.sol";

contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal pure virtual returns (bytes memory) {
        return msg.data;
    }

    function _getChainID() internal view virtual returns (uint256) {
        return block.chainid;
    }

    function _getBlockNumber() internal view virtual returns (uint256) {
        return block.number;
    }

    function _getBlockTimestamp() internal view virtual returns (uint256) {
        return block.timestamp;
    }
}

contract CryeatorProtection is Context {
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

abstract contract CryeatorStructure is CryeatorProtection, CryeatorToken {
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

    struct Post {
        bool created;
        uint256 likes;
        uint256 dislikes;
        uint256 withdrawn;
        uint256 burnt;
        address[] likers;
        address[] dislikers;
    }

    mapping(address => mapping(string => Post)) internal _creatorsContent;
    mapping(address => string[]) internal _creatorsContentIds;

    modifier noDuplicateContent(string memory _contentID) virtual {
        if (_creatorsContent[_msgSender()][_contentID].created) revert DuplicatedContent();
        _;
    }

    modifier _contentExist(address _creator, string memory _contentID) virtual {
        require(_creatorsContent[_creator][_contentID].created, "content not found");
        _;
    }

    function getCreatorContentsIds(address _creator) external view virtual returns (string[] memory contentIDs);
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

contract CryeatorContent is CryeatorStructure {
    function _replayContentOwing(address _creator, string memory _contentID, Post memory post) private {
        if (post.dislikes == post.burnt) return;
        (uint256 _freeLikes, uint256 _owingDebt) = this.calculateContentEarningStats(post);
        if (_owingDebt > 0 && _freeLikes > 0) { 
            uint256 toBurn = _owingDebt >= _freeLikes ? _freeLikes : _owingDebt;
            _creatorsContent[_creator][_contentID].burnt += toBurn;
            _burn(address(this), toBurn);
        }
    }

    // function _replayContentOwing(address _creator, string memory _contentID, Post memory post) private {
    //     if (post.dislikes == post.burnt) return;
        
    //     (uint256 _supposeFreeLikes, uint256 _owingDebt) = this.calculateContentEarningStats(post);
    //     if (_supposeFreeLikes <= post.burnt) return;
    //     uint256 _freeLikes = _supposeFreeLikes - post.burnt;

    //     if (_owingDebt > 0 && _freeLikes > 0) { 
    //         uint256 toBurn = _owingDebt >= _freeLikes ? _freeLikes : _owingDebt;
    //         _creatorsContent[_creator][_contentID].burnt += toBurn;
    //         _burn(address(this), toBurn);
    //     }
    // }

    function _increaseContentWithdrawn(address _creator, string memory _contentID, uint256 _value) private {
        _creatorsContent[_creator][_contentID].withdrawn += _value;
    }

    function _addNewLike(address _liker, address _creator, string memory _contentID, uint256 _value) private {
        _creatorsContent[_creator][_contentID].likes += _value;
        _creatorsContent[_creator][_contentID].likers.push(_liker);
    }

    function _addNewDislike(address _disliker, address _creator, string memory _contentID, uint256 _value) private {
        _creatorsContent[_creator][_contentID].dislikes += _value;
        _creatorsContent[_creator][_contentID].dislikers.push(_disliker);
    }

    function _likeContent(address _liker, address creator, string memory contentID, uint256 _value) internal virtual {
        Post memory post = getContent(creator, contentID);
        _transfer(_liker, address(this), _value);
        _addNewLike(_liker, creator, contentID, _value);
        post.likes += _value;
        _replayContentOwing(creator, contentID, post);
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

    function _withdrawContentEarning(address _creator, address _to, string memory _contentID, uint256 _value) internal _noReentranceWithdraw(_contentID) {
        Post memory post = getContent(_creator, _contentID);
        (uint256 _freeLikes, uint256 _owingDebt) = this.calculateContentEarningStats(post);
        if (_owingDebt > _freeLikes) revert ContentRewardIsTooLow();
        if (_value > _freeLikes) revert ContentRewardNotEnough();
        _increaseContentWithdrawn(_creator, _contentID, _value);
        _transfer(address(this), _to, _value);
        emit WithdrawContentReward(_creator, _to, _contentID, _value);
    }

    function getCreatorContentsIds(address _creator) public view override returns (string[] memory) {
        return _creatorsContentIds[_creator];
    }

    function getCreatorContentCounts(address _creator) public view override returns (uint256) {
        return getCreatorContentsIds(_creator).length;
    }

    function getContent(address _creator, string memory _contentID) public view override _contentExist(_creator, _contentID) returns (Post memory){
        return _creatorsContent[_creator][_contentID];
    }

    function getContentByIndex(address _creator, uint256 _contentIndex) public view override returns (Post memory) {
        string[] memory _contentIDs = getCreatorContentsIds(_creator);
        require(_contentIndex <= _contentIDs.length, "invalid index provided");
        return getContent(_creator, _contentIDs[_contentIndex]);
    }

    function getContentsByRange(address _creator, uint256 _contentFromIndex, uint256 _contentToIndex) public view override returns (Post[] memory posts) {
        string[] memory _contentIDs = getCreatorContentsIds(_creator);
        require( _contentFromIndex < _contentToIndex || (_contentIDs.length >= _contentFromIndex && _contentIDs.length <= _contentToIndex), "invalid range provided");

        posts = new Post[](_contentToIndex - _contentFromIndex);
        for (uint256 index = 0; index < posts.length; index++) {
            posts[index] = getContentByIndex(_creator, _contentFromIndex + index);
        }
    }

    function createContent(string memory _contentID) public override noDuplicateContent(_contentID) returns (bool) {
        address _creator = _msgSender();
        _creatorsContentIds[_creator].push(_contentID);
        _creatorsContent[_creator][_contentID].created = true;
        return true;
    }

    function likeContent(address _creator,string memory _contentID,uint256 _value) public override returns (bool) {
        _likeContent(_msgSender(), _creator, _contentID, _value);
        return true;
    }

    function dislikeContent(address _creator,string memory _contentID,uint256 _value) public override returns (bool) {
        _dislikeContent(_msgSender(), _creator, _contentID, _value);
        return true;
    }

    function likeContentWithContentEarning(address _likeContentCreator, string memory _likeContentID, string memory _contentID, uint256 _value) public override returns (bool) {
        address _creator = _msgSender();
        Post memory post = getContent(_creator, _contentID);
        Post memory likePost = getContent(_likeContentCreator, _likeContentID);

        (uint256 _freeLikes, uint256 _owingDebt) = this.calculateContentEarningStats(post);
        if (_owingDebt > _freeLikes) revert ContentRewardNotEnough();
        if (_value > _freeLikes) revert ContentRewardIsTooLow();

        _increaseContentWithdrawn(_creator, _contentID, _value);
        _addNewLike(_creator, _likeContentCreator, _likeContentID, _value);

        likePost.likes += _value;
        _replayContentOwing(_likeContentCreator, _likeContentID, likePost);
        emit LikeContent(_creator, _likeContentCreator, _likeContentID, _value);
        return true;
    }

    function likeContentWithAllContentEarning(address _likeContentCreator,string memory _likeContentID,string memory _contentID) public override returns (bool) {
        (uint256 _freeLikes, uint256 _owingDebt) = this.calculateContentEarningStats(getContent(_msgSender(), _contentID));
        if (_freeLikes < _owingDebt) revert ContentRewardIsTooLow();
        return likeContentWithContentEarning(_likeContentCreator, _likeContentID, _contentID, _freeLikes);
    }

    function dislikeContentWithContentEarning(address _dislikeContentCreator, string memory _dislikeContentID, string memory _contentID, uint256 _value) public override _contentExist(_dislikeContentCreator, _dislikeContentID) returns (bool){
        address _creator = _msgSender();
        Post memory post = getContent(_creator, _contentID);
        Post memory dislikePost = getContent(_dislikeContentCreator, _dislikeContentID);

        (uint256 _freeLikes, uint256 _owingDebt) = this.calculateContentEarningStats(post);

         if (_owingDebt > _freeLikes) revert ContentRewardIsTooLow();
         if (_value > _freeLikes) revert ContentRewardNotEnough();

        _increaseContentWithdrawn(_creator, _contentID, _value);
        _addNewDislike(_creator,_dislikeContentCreator,_dislikeContentID,_value);
        dislikePost.dislikes += _value;
        _replayContentOwing(_dislikeContentCreator, _dislikeContentID, dislikePost);
        emit DislikeContent(_creator,_dislikeContentCreator,_dislikeContentID,_value);
        return true;
    }

    function dislikeContentWithAllContentEarning(address _dislikeContentCreator, string memory _dislikeContentID, string memory _contentID) public override returns (bool) {
        Post memory post = getContent(_msgSender(), _contentID);
        (uint256 _freeLikes, uint256 _owingDebt) = this.calculateContentEarningStats(post);
        if (_owingDebt > _freeLikes) revert ContentRewardIsTooLow();
        uint256 _value = _freeLikes - post.burnt;
        return dislikeContentWithContentEarning(_dislikeContentCreator, _dislikeContentID, _contentID, _value);
    }

    function withdrawContentEarning(address _withdrawTo, string memory _contentID, uint256 _value) public override returns (bool) {
        _withdrawContentEarning(_msgSender(), _withdrawTo, _contentID, _value);
        return true;
    }

    function withdrawAllContentEarning(address _withdrawTo, string memory _contentID) public override returns (bool) {
        Post memory post = getContent(_msgSender(), _contentID);
        (uint256 _freeLikes, uint256 _owingDebt) = this.calculateContentEarningStats(post);
        if (_owingDebt > _freeLikes) revert ContentRewardIsTooLow();
        return withdrawContentEarning(_withdrawTo, _contentID, _freeLikes);
    }
}
