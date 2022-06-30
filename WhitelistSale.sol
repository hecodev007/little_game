pragma solidity ^0.6.0;

import "@openzeppelin/contracts/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract WhitelistSale is ERC721 {
    bytes32 public merkleRoot;
    uint256 public nextTokenId;
    mapping(uint256 => bool) public claimed;
    event Minted(
        uint256 indexed id,
        address to
    );
    constructor(bytes32 _merkleRoot) public ERC721("NFT", "NFT") {
        merkleRoot = _merkleRoot;
    }

    function mint(bytes32[] calldata merkleProof,uint256 id) public payable {
        require(claimed[id] == false, "already claimed");
        claimed[id] = true;
        require(MerkleProof.verify(merkleProof, merkleRoot, keccak256(abi.encodePacked(msg.sender))), "invalid merkle proof");
        nextTokenId++;
        _mint(msg.sender, nextTokenId);
        emit Minted(nextTokenId,msg.sender);
    }
}