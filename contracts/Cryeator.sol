// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {Cryeator as CryeatorToken} from "./CryeatorToken.sol";

interface ICryeator {}

contract CryeatorProtection {
    mapping(address => mapping(string => mapping(uint256 => bool)))
        private _withdrawInSameBlock;

    function _inWithdraw(
        address _creator,
        string memory _contentID
    ) internal view returns (bool) {
        return _withdrawInSameBlock[_creator][_contentID][block.number];
    }

    function _setInWithdraw(
        address _creator,
        string memory _contentID,
        bool _status
    ) internal {
        _withdrawInSameBlock[_creator][_contentID][block.number] = _status;
    }

    modifier _noReentranceWithdraw(string memory contentID) {
        uint256 currentBlock = block.number;
        require(!_inWithdraw(msg.sender, contentID), "reentrance not allowed");
        _setInWithdraw(msg.sender, contentID, true);
        _;
        _setInWithdraw(msg.sender, contentID, true);
    }
}

contract CryeatorContent is CryeatorToken, CryeatorProtection {
    mapping(address => mapping(string => Post)) public creatorsContent;
    mapping(address => string[]) public creatorsContentIds;

    struct Post {
        bool created;
        uint256 likes;
        uint256 dislikes;
        uint256 withdrawn;
        address[] likers;
        address[] dislikers;
    }

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

    function contentExist(
        address creator,
        string memory contentID
    ) public view returns (bool) {
        return creatorsContent[creator][contentID].created;
    }

    // get creator total contents counts
    function getCreatorContentCounts(
        address creator
    ) public view returns (uint256) {
        return creatorsContentIds[creator].length;
    }

    function getCreatorContent(
        address creator,
        string memory contentID
    ) public view returns (Post memory) {
        Post memory post = creatorsContent[creator][contentID];
        if (!post.created) revert ContentNotFound();
        return post;
    }

    function getCreatorContentByIndex(
        address creator,
        uint256 contentIndex
    ) public view returns (Post memory) {
        require(getCreatorContentCounts(creator) >= contentIndex);
        string memory contentID = creatorsContentIds[creator][contentIndex];
        return getCreatorContent(creator, contentID);
    }

    // return content earning without withdrawn and dislikes
    function getContentFreeEarning(
        address creator,
        string memory contentID
    ) public view returns (uint256) {
        Post memory post = getCreatorContent(creator, contentID);
        return post.likes - (post.dislikes + post.withdrawn);
    }

    function createContent(string memory contentID) public {
        address creator = msg.sender;
        if (contentExist(creator, contentID)) revert DuplicatedContent();
        creatorsContent[creator][contentID].created = true;
        creatorsContentIds[creator].push(contentID);
        emit CreatedContent(creator, contentID);
    }

    function _likeContent(
        address _liker,
        address creator,
        string memory contentID,
        uint256 _value
    ) private {
        Post memory post = getCreatorContent(creator, contentID);
        _transfer(_liker, address(this), _value);

        if (post.dislikes >= post.likes) {
            uint256 remainContentEarning = (post.likes + _value) -
                post.withdrawn;
            uint left = post.dislikes - post.likes;
            _burn(
                address(this),
                remainContentEarning < left ? remainContentEarning : left
            );
        }

        creatorsContent[creator][contentID].likes += _value;
        creatorsContent[creator][contentID].likers.push(_liker);
        emit LikeContent(msg.sender, creator, contentID, _value);
    }

    function _dislikeContent(
        address _disliker,
        address creator,
        string memory contentID,
        uint256 _value
    ) private {
        if (!contentExist(creator, contentID)) revert ContentNotFound();

        _burn(_disliker, _value);

        uint256 remainEarning = getContentFreeEarning(creator, contentID);

        if (remainEarning >= _value) {
            // if the likes is greater than the dislikes, we will burn the worth of the current dislike
            // from the creator content earning

            // if the amount to burn is greater than of equal to the remaining amount earned from the content
            // burn remaining balance, else burn the dislike amount from the remaining earned
            _burn(
                address(this),
                remainEarning <= _value ? remainEarning : _value
            );
        }

        creatorsContent[creator][contentID].dislikes += _value;
        creatorsContent[creator][contentID].dislikers.push(_disliker);
        emit DislikeContent(_disliker, creator, contentID, _value);
    }

    function likeContent(
        address creator,
        string memory contentID,
        uint256 amount
    ) public {
        _likeContent(msg.sender, creator, contentID, amount);
    }

    function dislikeContent(
        address creator,
        string memory contentID,
        uint256 amount
    ) public {
        _dislikeContent(msg.sender, creator, contentID, amount);
    }

    function _withdrawContentEarning(
        address _creator,
        string memory _contentID,
        uint256 _value,
        address _to
    ) private _noReentranceWithdraw(_contentID) {
        Post memory post = getCreatorContent(_creator, _contentID);
        uint256 spent = post.dislikes + post.withdrawn;
        if (spent > post.likes) revert SpentIsGreaterThanEarned();

        uint256 freeReward = post.likes - spent;
        if (_value > freeReward) revert ContentRewardNotEnough();

        creatorsContent[_creator][_contentID].withdrawn += _value;
        _transfer(address(this), _creator, _value);
        emit WithdrawContentReward(_creator, _to, _contentID, _value);
    }

    // allow creator to withdraw earned reward
    function withdrawContentEarning(
        string memory contentID,
        uint256 amount,
        address withdrawTo
    ) public {
        address creator = msg.sender;
        _withdrawContentEarning(creator, contentID, amount, withdrawTo);
    }

    // withdraw all content earning
    function withdrawAllContentEarning(
        string memory contentID,
        address withdrawTo
    ) public {
        withdrawContentEarning(
            contentID,
            getContentFreeEarning(msg.sender, contentID),
            withdrawTo
        );
    }

    function likeContentWithAllContentEarning(
        address likeContentAuthor,
        string memory contentID,
        string memory likeContentID
    ) public {
        address creator = msg.sender;
        uint256 remainEarning = getContentFreeEarning(creator, contentID);

        if (remainEarning <= 0) revert WithdrawAmountTooLow();
        if (!contentExist(likeContentAuthor, likeContentID))
            revert ContentNotFound();

        creatorsContent[creator][contentID].withdrawn += remainEarning;

        // update the content creator balance
        creatorsContent[likeContentAuthor][likeContentID]
            .likes += remainEarning;
        creatorsContent[likeContentAuthor][likeContentID].likers.push(creator);

        emit WithdrawContentRewardToLikeConent(
            creator,
            likeContentAuthor,
            likeContentID,
            remainEarning
        );
        emit LikeContent(
            likeContentAuthor,
            creator,
            likeContentID,
            remainEarning
        );
    }
}
