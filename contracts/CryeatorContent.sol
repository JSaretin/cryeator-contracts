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

    // struct Reaction {
    //     uint256 value;
    //     address addr;
    // }
    struct Post {
        bool created;
        uint256 likes;
        uint256 dislikes;
        uint256 withdrawn;
        address[] likers;
        address[] dislikers;
    }

    mapping(address => mapping(string => Post)) internal _creatorsContent;
    mapping(address => string[]) internal _creatorsContentIds;

    modifier noDuplicateContent(string memory _contentID) virtual {
        Post memory post = this.getContent(_msgSender(), _contentID);
        if (post.created) revert DuplicatedContent();
        _;
    }

    modifier _contentExist(address _creator, string memory _contentID) virtual {
        require(
            this.getContent(_creator, _contentID).created,
            "content not found"
        );
        _;
    }

    function _likeContent(
        address _liker,
        address creator,
        string memory contentID,
        uint256 _value
    ) internal virtual _contentExist(creator, contentID) {
        Post memory post = this.getContent(creator, contentID);
        _transfer(_liker, address(this), _value);

        _creatorsContent[creator][contentID].likes += _value;
        _creatorsContent[creator][contentID].likers.push(_liker);

        uint256 likes = post.likes + _value;
        if (_value > 0 && post.dislikes > post.likes) {
            if (post.dislikes > likes) _burn(address(this), _value);
            else {
                uint256 _owning = post.dislikes - post.likes;
                uint256 _contentBalance = likes - post.withdrawn;
                if (_contentBalance > _owning) _burn(address(this), _owning);
                else _burn(address(this), _contentBalance);
            }
        }
        emit LikeContent(msg.sender, creator, contentID, _value);
    }

    function _dislikeContent(
        address _disliker,
        address creator,
        string memory contentID,
        uint256 _value
    ) internal virtual _contentExist(creator, contentID) {
        Post memory post = this.getContent(creator, contentID);
        _burn(_disliker, _value);
        _creatorsContent[creator][contentID].dislikes += _value;
        _creatorsContent[creator][contentID].dislikers.push(_disliker);
        uint256 _contentBalance = post.likes - post.withdrawn;

        if (post.dislikes < post.likes && _contentBalance > 0) {
            if (_contentBalance >= _value) _burn(address(this), _value);
            else _burn(address(this), _contentBalance);
        }
        emit DislikeContent(_disliker, creator, contentID, _value);
    }

    function _withdrawContentEarning(
        address _creator,
        string memory _contentID,
        uint256 _value,
        address _to
    )
        internal
        _contentExist(_creator, _contentID)
        _noReentranceWithdraw(_contentID)
    {
        Post memory post = this.getContent(_creator, _contentID);
        if (
            post.dislikes > post.likes ||
            post.dislikes > (post.likes - post.withdrawn)
        ) revert ContentRewardIsTooLow();
        uint256 contentFreeEarning = post.likes -
            (post.withdrawn + post.dislikes);

        if (_value > contentFreeEarning) revert ContentRewardNotEnough();

        _creatorsContent[_creator][_contentID].withdrawn += _value;
        _transfer(address(this), _to, _value);
        emit WithdrawContentReward(_creator, _to, _contentID, _value);
    }

    function getCreatorContentsIds(
        address _creator
    ) external view virtual returns (string[] memory contentIDs);

    function getContent(
        address _creator,
        string memory _contentID
    ) external view virtual returns (Post memory post);

    function getContentByIndex(
        address _creator,
        uint256 _contentIndex
    ) external view virtual returns (Post memory post);

    function getContentsByRange(
        address _creator,
        uint256 _contentFromIndex,
        uint256 _contentToIndex
    ) external view virtual returns (Post[] memory posts);

    function getCreatorContentCounts(
        address _creator
    ) external view virtual returns (uint256 counts);

    function contentExist(
        address _creator,
        string memory _contentID
    ) external view virtual returns (bool);

    function createContent(
        string memory _contentID
    ) external virtual returns (bool);

    function likeContent(
        address _creator,
        string memory _contentID,
        uint256 _value
    ) external virtual returns (bool);

    function dislikeContent(
        address _creator,
        string memory _contentID,
        uint256 _value
    ) external virtual returns (bool);

    function likeContentWithContentEarning(
        address _likeContentCreator,
        string memory _likeContentID,
        string memory _contentID,
        uint256 _value
    ) external virtual returns (bool);

    function likeContentWithAllContentEarning(
        address _likeContentCreator,
        string memory _likeContentID,
        string memory _contentID
    ) external virtual returns (bool);

    function dislikeContentWithContentEarning(
        address _dislikeContentCreator,
        string memory _dislikeContentID,
        string memory _contentID,
        uint256 _value
    ) external virtual returns (bool);

    function dislikeContentWithAllContentEarning(
        address _dislikeContentCreator,
        string memory _dislikeContentID,
        string memory _contentID
    ) external virtual returns (bool);

    function withdrawContentEarning(
        address _withdrawTo,
        string memory _contentID,
        uint256 _value
    ) external virtual returns (bool);

    function withdrawAllContentEarning(
        address _withdrawTo,
        string memory _contentID
    ) external virtual returns (bool);
}

contract CryeatorContent is CryeatorStructure {
    function getCreatorContentsIds(
        address _creator
    ) public view override returns (string[] memory contentIDs) {
        contentIDs = _creatorsContentIds[_creator];
    }

    function getCreatorContentCounts(
        address _creator
    ) public view override returns (uint256) {
        return getCreatorContentsIds(_creator).length;
    }

    function getContent(
        address _creator,
        string memory _contentID
    ) public view override returns (Post memory post) {
        post = _creatorsContent[_creator][_contentID];
    }

    function contentExist(
        address _creator,
        string memory _contentID
    ) external view override returns (bool created) {
        created = getContent(_creator, _contentID).created;
    }

    function getContentByIndex(
        address _creator,
        uint256 _contentIndex
    ) public view override returns (Post memory post) {
        string[] memory _contentIDs = getCreatorContentsIds(_creator);
        require(_contentIndex <= _contentIDs.length, "invalid range provided");
        post = getContent(_creator, _contentIDs[_contentIndex]);
    }

    function getContentsByRange(
        address _creator,
        uint256 _contentFromIndex,
        uint256 _contentToIndex
    ) public view override returns (Post[] memory posts) {
        string[] memory _contentIDs = getCreatorContentsIds(_creator);
        require(
            _contentFromIndex < _contentToIndex ||
                (_contentIDs.length >= _contentFromIndex &&
                    _contentIDs.length <= _contentToIndex),
            "invalid range provided"
        );

        posts = new Post[](_contentToIndex - _contentFromIndex);

        for (uint256 index = 0; index < posts.length; index++) {
            posts[index] = getContentByIndex(
                _creator,
                _contentFromIndex + index
            );
        }
    }

    function createContent(
        string memory _contentID
    ) public override noDuplicateContent(_contentID) returns (bool) {
        address _creator = _msgSender();
        _creatorsContentIds[_creator].push(_contentID);
        _creatorsContent[_creator][_contentID].created = true;
        return true;
    }

    function likeContent(
        address _creator,
        string memory _contentID,
        uint256 _value
    ) public override returns (bool success) {
        _likeContent(_msgSender(), _creator, _contentID, _value);
        success = true;
    }

    function dislikeContent(
        address _creator,
        string memory _contentID,
        uint256 _value
    ) public override returns (bool success) {
        _dislikeContent(_msgSender(), _creator, _contentID, _value);
        success = true;
    }

    function likeContentWithContentEarning(
        address _likeContentCreator,
        string memory _likeContentID,
        string memory _contentID,
        uint256 _value
    )
        public
        override
        _contentExist(_msgSender(), _contentID)
        _contentExist(_likeContentCreator, _likeContentID)
        returns (bool success)
    {
        address _creator = _msgSender();
        Post memory post = getContent(_creator, _contentID);
        if (
            post.dislikes > post.likes ||
            post.dislikes > (post.likes - post.withdrawn)
        ) revert ContentRewardIsTooLow();
        uint256 canSpend = post.likes - (post.dislikes + post.withdrawn);
        if (canSpend < _value) revert ContentRewardNotEnough();

        _creatorsContent[_creator][_contentID].withdrawn += _value;
        _creatorsContent[_likeContentCreator][_likeContentID].likes += _value;
        _creatorsContent[_likeContentCreator][_likeContentID].likers.push(
            _creator
        );
        emit LikeContent(_creator, _likeContentCreator, _likeContentID, _value);
        success = true;
    }

    function likeContentWithAllContentEarning(
        address _likeContentCreator,
        string memory _likeContentID,
        string memory _contentID
    )
        public
        override
        _contentExist(_msgSender(), _contentID)
        _contentExist(_likeContentCreator, _likeContentID)
        returns (bool)
    {
        Post memory post = getContent(_msgSender(), _contentID);
        if (
            post.dislikes > post.likes ||
            post.dislikes > (post.likes - post.withdrawn)
        ) revert ContentRewardIsTooLow();
        uint256 _value = post.likes - (post.dislikes + post.withdrawn);
        if (_value == 0) revert ContentRewardIsTooLow();
        likeContentWithContentEarning(
            _likeContentCreator,
            _likeContentID,
            _contentID,
            _value
        );
        return true;
    }

    function dislikeContentWithContentEarning(
        address _dislikeContentCreator,
        string memory _dislikeContentID,
        string memory _contentID,
        uint256 _value
    )
        public
        override
        _contentExist(_msgSender(), _contentID)
        _contentExist(_dislikeContentCreator, _dislikeContentID)
        returns (bool)
    {
        address _creator = _msgSender();
        Post memory post = getContent(_creator, _contentID);
        if (
            post.dislikes > post.likes ||
            post.dislikes > (post.likes - post.withdrawn)
        ) revert ContentRewardIsTooLow();
        uint256 canSpend = post.likes - (post.dislikes + post.withdrawn);
        if (canSpend < _value) revert ContentRewardNotEnough();

        _creatorsContent[_creator][_contentID].withdrawn += _value;
        // Post memory likeContent = getContent(_creator, _contentID);
        _creatorsContent[_dislikeContentCreator][_dislikeContentID]
            .dislikes += _value;
        _creatorsContent[_dislikeContentCreator][_dislikeContentID]
            .dislikers
            .push(_creator);
        emit DislikeContent(
            _creator,
            _dislikeContentCreator,
            _dislikeContentID,
            _value
        );
        return true;
    }

    function dislikeContentWithAllContentEarning(
        address _dislikeContentCreator,
        string memory _dislikeContentID,
        string memory _contentID
    ) public override returns (bool) {
        address _creator = _msgSender();
        Post memory post = getContent(_creator, _contentID);
        if (
            post.dislikes > post.likes ||
            post.dislikes > (post.likes - post.withdrawn)
        ) revert ContentRewardIsTooLow();
        uint256 _value = post.likes - (post.dislikes + post.withdrawn);
        if (_value == 0) revert ContentRewardIsTooLow();
        dislikeContentWithContentEarning(
            _dislikeContentCreator,
            _dislikeContentID,
            _contentID,
            _value
        );
        return true;
    }

    function withdrawContentEarning(
        address _withdrawTo,
        string memory _contentID,
        uint256 _value
    ) external override returns (bool) {
        _withdrawContentEarning(_msgSender(), _contentID, _value, _withdrawTo);
        return true;
    }

    function withdrawAllContentEarning(
        address _withdrawTo,
        string memory _contentID
    ) external override returns (bool) {
        address _creator = _msgSender();
        Post memory post = getContent(_creator, _contentID);
        if (
            post.dislikes > post.likes ||
            post.dislikes > (post.likes - post.withdrawn)
        ) revert ContentRewardIsTooLow();

        _withdrawContentEarning(
            _creator,
            _contentID,
            post.likes - (post.dislikes + post.withdrawn),
            _withdrawTo
        );

        return true;
    }
}
