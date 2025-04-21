// SPDX-License-Identifier: BSL-1.0
pragma solidity >=0.8.0 <0.9.0;


/**
    merkle tree 
    
    option A: contract keeps tracks of distribution root hash and address withdraw status

    The distribution computation is made offchain and the amounts to withdraw
    from each distribution are stored in a merkle tree. The contract store the head
    of each one of these merkle trees and a boolean indicator for each address to check 
    if already withdraw that distribution amount or not.

    user can only withdraw from especific distributions. For each withdraw it validates the
    merkle three and check if the address already withdraw that amount. If not, proceed with the withdraw

    option B: contract keep tracks of distribution root hash only

    - distribution computed on a secure offchain server, merkle tree uploaded to the contract
    - the contract dont know which address already withdraw, all its controlled by the secure offchain server.
    - on each withdraw, the contract verifies the merkle tree
    - each withdraw can interact with 1 distribution (merkle tree)

    We will use option A
 */

contract MerkleTreeDistribution {

    struct DistributionNode {
        bool set;
        bytes32 previous;
        mapping(address => bool) claimed;
    }
    mapping(bytes32 => DistributionNode) private distributionSequence;

    bytes32 private distributionHead;
    bytes32 private emptyHash = 0x0000000000000000000000000000000000000000000000000000000000000000;

    constructor() {
        distributionHead = emptyHash;
    }

    function addNewDistributionHead(bytes32 _head) public {
        DistributionNode storage node = distributionSequence[_head]; 
        require(node.set == false, "Head already set");
        node.previous = distributionHead;
        node.set = true;
        distributionHead = _head;
    }

    function getDistributionSequence(uint8 maxDepth) public view returns (bytes32[] memory) {
        require(maxDepth > 0, "maxDepth must be greater than 0");
        bytes32[] memory result = new bytes32[](maxDepth);
        bytes32 head = distributionHead;
        uint8 step = 0;
        while (head != emptyHash) {
            result[step] = head;
            head = distributionSequence[head].previous;
            step++;
        }
        return result;
    }

    function addressWithdrawPath(address _address) public view returns (bytes32 head, bytes32 tail, uint256 span) {
        if (distributionSequence[distributionHead].claimed[_address]) {
            // address already claimed
            return (emptyHash, emptyHash, 0);
        }

        head = distributionHead;
        tail = emptyHash;
        span = 1;
        bytes32 pointer = head;
        while (pointer != emptyHash && distributionSequence[pointer].claimed[_address] == false) {
            tail = pointer;
            span++;
            pointer = distributionSequence[pointer].previous;
        }
    }

    function verifyHash(bytes32[] memory _verifyPath, bytes32 _distributionHash, address _address, uint256 _value) public view returns (bool) {
        // do the merkle tree verification algorithm
        
        bytes32 estimated = keccak256(abi.encodePacked(_address, _value));
        for (uint256 i = 0; i < _verifyPath.length; i++) {
            estimated = keccak256(abi.encodePacked(estimated, _verifyPath[i]));
        }
        // at the end, estimated should be equal to _distributionHash
        return estimated == _distributionHash;
    }
}