// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "../libraries/InitializableOwner.sol";
//import "../interfaces/IDsgNft.sol";
import "../libraries/LibPart.sol";
import "../libraries/Random.sol";
import "./CrystalNft.sol";
import "hardhat/console.sol";
import "../InvitePool.sol";


contract DsgNft is ERC721, InitializableOwner, ReentrancyGuard, Pausable
{
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private _minters;
    InvitePool public  inviteLayer;
    using Strings for uint256;
    mapping(address => uint256) UserChance;

    event Minted(
        uint256 indexed id,
        address to
    );
    event BatchMinted(
        uint256[] id,
        address to
    );
    event Upgraded(uint256 indexed id0, uint256 indexed id1, uint256 new_id, address user);
    event ComposeNft(uint256 indexed id0, uint256 indexed id1, uint256 new_id, address user, uint256 compose_id);
    /*
     *     bytes4(keccak256('getRoyalties(uint256)')) == 0xbb3bafd6
     *     bytes4(keccak256('sumRoyalties(uint256)')) == 0x09b94e2a
     *
     *     => 0xbb3bafd6 ^ 0x09b94e2a == 0xb282e1fc
     */
    bytes4 private constant _INTERFACE_ID_GET_ROYALTIES = 0xbb3bafd6;
    bytes4 private constant _INTERFACE_ID_ROYALTIES = 0xb282e1fc;

    uint256 private _tokenId;
    string private _baseURIVar;

    IERC20 public _token;//egc
    IERC20 public _busd;
    CrystalNft private _crystalNft;
    address public _feeWallet;

    string private _name;
    string private _symbol;

    uint256 public price;
    uint256 public price_busd;
    // mapping(uint256 => LibPart.NftInfo) private _nfts;
    address public _teamWallet;
    address public _rewardWallet;
    constructor(string memory name_,
        string memory symbol_,
        address teamAddress,
        string memory baseURI_) public ERC721("", "")
    {
        super._initialize();
        initialize(name_, symbol_, teamAddress, baseURI_);
    }

    function initialize(
        string memory name_,
        string memory symbol_,
        address teamAddress,
        string memory baseURI_
    ) internal {
        _tokenId = 1000;

        _registerInterface(_INTERFACE_ID_GET_ROYALTIES);
        _registerInterface(_INTERFACE_ID_ROYALTIES);
        _name = name_;
        _symbol = symbol_;
        _baseURIVar = baseURI_;
        _teamWallet = teamAddress;
    }


    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function setBaseURI(string memory uri) public onlyOwner {
        _baseURIVar = uri;
    }

    function baseURI() public view override returns (string memory) {
        return _baseURIVar;
    }

    function setFeeWallet(address feeWallet_) public onlyOwner {
        _feeWallet = feeWallet_;
    }

    function setRewardWallet(address rewardWallet) public onlyOwner {
        _rewardWallet = rewardWallet;
    }

    function setCrystalNft(address crystalNft_) public onlyOwner {
        _crystalNft = CrystalNft(crystalNft_);
    }

    function setPrice(uint256 price_, uint256 price_busd_) public onlyOwner {
        price = price_;
        price_busd = price_busd_;
    }

    function setFeeToken(address token, address token_other) public onlyOwner {
        _token = IERC20(token);
        _busd = IERC20(token_other);
    }


    function _doMint(
        address to
    ) internal returns (uint256) {
        _tokenId++;


        _mint(to, _tokenId);

        emit Minted(_tokenId, to);
        return _tokenId;
    }

    function batchMint(
        address to, uint256 amount
    ) public payable nonReentrant {
        require(amount >= 5, "low amount");
        require(_teamWallet != address(0), "_teamWallet");
        require(address(_token) != address(0) || address(_busd) != address(0),"_token not set");
        //SafeERC20.safeTransferETH(_teamWallet, msg.value);
        if (address(_token) != address(0)) {
            SafeERC20.safeTransferFrom(_token, msg.sender, _teamWallet, price.mul(amount));

        }

        if (address(_busd) != address(0)) {
            address upper = inviteLayer.getOneUpper(msg.sender);
            uint256 money = price_busd.mul(amount);
            if (upper != address(0)) {
                SafeERC20.safeTransferFrom(_busd, msg.sender, upper, money.mul(5).div(100));
            }
            if (_rewardWallet != address(0)) {
                SafeERC20.safeTransferFrom(_busd, msg.sender, _rewardWallet, money.mul(15).div(100));
            }
            SafeERC20.safeTransferFrom(_busd, msg.sender, _teamWallet, money.mul(80).div(100));
        }
        if (getReward(msg.sender) == true) {
            _crystalNft.mint(msg.sender);
        }
        uint256[] memory nftIds = new uint256[](amount);
        for (uint256 i = 0; i < amount; i++) {
            nftIds[i] = _doMint(to);
        }
        emit BatchMinted(nftIds, to);
    }

    function getReward(address user) internal returns (bool){
        uint256 seed = Random.computerSeed() / 23 % 100;
        uint256 chance = UserChance[user];
        if (chance > 0) {
            UserChance[user] = chance + 5;
            if (seed <= chance + 5) {
                UserChance[user] = 0;
                return true;
            } else {
                return false;
            }

        } else {
            UserChance[user] = 5;
            if (seed <= 1) {
                UserChance[user] = 0;
                return true;
            } else {
                return false;
            }

        }

    }

    function mint(
        address to
    ) public payable nonReentrant returns (uint256 tokenId){
        //  require(msg.value >= price, "low price");

        //SafeERC20.safeTransferETH(_teamWallet, msg.value);
        if (address(_token) != address(0)) {
            SafeERC20.safeTransferFrom(_token, msg.sender, _teamWallet, price);
        }

        if (address(_busd) != address(0)) {
            SafeERC20.safeTransferFrom(_busd, msg.sender, _teamWallet, price_busd);
        }
        tokenId = _doMint(to);
    }

    function upgradeNft(uint256 nftId1, uint256 nftId2) public nonReentrant whenNotPaused
    {
        burn_inter(nftId1);
        burn_inter(nftId2);
        uint256 tokenId = _doMint(msg.sender);
        emit Upgraded(nftId1, nftId2, tokenId, msg.sender);
    }

    function composeNft(uint256 nftId1, uint256 nftId2, uint256 composeId) public nonReentrant whenNotPaused
    {
        burn_inter(nftId1);
        burn_inter(nftId2);
        uint256 tokenId = _doMint(msg.sender);
        //ComposeNft
        emit ComposeNft(nftId1, nftId2, tokenId, msg.sender, composeId);
    }

    function getCurId() public view returns (uint256){
        return _tokenId;
    }

    function burn(uint256 tokenId) public {
        address owner = ERC721.ownerOf(tokenId);
        require(_msgSender() == owner, "caller is not the token owner");

        _burn(tokenId);
    }

    function burn_inter(uint256 tokenId) internal {
        address owner = ERC721.ownerOf(tokenId);
        require(_msgSender() == owner, "caller is not the token owner");

        _burn(tokenId);
    }
}
