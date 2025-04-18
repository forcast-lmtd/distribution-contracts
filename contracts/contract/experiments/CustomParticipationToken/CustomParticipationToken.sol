// SPDX-License-Identifier: BSL-1.0
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
// Importing OpenZeppelin's SafeMath Implementation
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract ParticipationToken is ERC20Pausable, Initializable {
    using SafeMath for uint256;

    struct ParticipantNode {
        address prev;
        address next;
        address addr;
        uint256 balance;
    }

    bool private _lockToken;
    mapping(address => ParticipantNode) private participants;


    constructor(
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) {
    }

    function mint_participants(
        uint256 initialSupply, 
        address[] memory usersAddress, 
        uint256[] memory shares,
        bool pauseToken
    ) initializer public {
        require(usersAddress.length == shares.length, "users does not match shares");
        require(usersAddress.length > 0, "empty array not allowed");
        if (usersAddress.length > 1){
            _sendParticipation(initialSupply, usersAddress, shares);
        } else {
            _mint(usersAddress[0], initialSupply);
        }
        if (pauseToken){
            _pause();
        }
    }

    function mint_single_owner(
        uint256 initialSupply,
        address singleParticipant,
        bool pauseToken
    ) initializer public {
        _mint(singleParticipant, initialSupply);
        if (pauseToken){
            _pause();
        }
    }


    function _sendParticipation(
        uint256 initialSupply,
        address[] memory usersAddress,
        uint256[] memory shares
    ) onlyInitializing internal {
        require(usersAddress.length == shares.length, "Input inconsitency");
        uint256 _totalShare = 0;
        for (uint i = 0; i < shares.length; i++) {
            _totalShare += shares[i];
        }
        require(
            initialSupply.mod(_totalShare) == 0, 
            "Total supply is not divisible by shares sum!");

        uint256 _amount;
        for (uint i = 0; i < usersAddress.length; i++) {
            _amount = shares[i].mul(initialSupply).div(_totalShare);
            _mint(usersAddress[i], _amount);
        }
    }

    function decimals() public pure override returns (uint8) {
        return 0;
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._afterTokenTransfer(from, to, amount);

        // discont 'amount' from 'from' address
        participants[from].balance = participants[from].balance.sub(amount);
        // add 'amount' to 'to' address
        participants[to].balance = participants[to].balance.add(amount);


        // if 'to' address is new (prev=0 and next=0), set its prev and next
        // before mapping is
        //      prev <-> addr (from) <-> next
        // after it will be
        //      prev <-> addr (from) <-> addr (to) <-> next 
        // for that we do:
        //      to.prev -> from
        //      to.next -> from.next
        //      from.next -> to   
        if ((participants[to].next == address(0)) && (participants[to].prev == address(0))) {
            participants[to].next = participants[from].next;
            participants[to].prev = from;
            participants[from].next = to;
        }

        // if 'from' address is empty, remove from participants node mapping
        // before mapping is
        //      prev <-> addr (from) <-> next
        // after it will be
        //      prev <-> next
        // for this we do: 
        //      from.prev.next ->  from.next (only if from.prev != 0x0)
        //      from.next.prev -> from.prev (only if from.next != 0x0)
        //      from.prev -> 0x0
        //      from.next -> 0x0
        if (participants[from].balance == 0) {
            if (participants[from].prev != address(0)) {
                participants[participants[from].prev].next = participants[from].next;
            }
            if (participants[from].next != address(0)) {
                participants[participants[from].next].prev = participants[from].prev;
            }
            // delete participants[from];
            participants[from].prev = address(0);
            participants[from].next = address(0);
        }
    }

    function get_participant_data(address target) public view returns (ParticipantNode memory) {
        //
        return participants[target];
    }

    function left_chain_balance(address target) internal view returns (uint256 balance) {
        if (participants[target].prev != address(0)) {
            return participants[target].balance.add(left_chain_balance(participants[target].prev));
        }
        return participants[target].balance;
    }

    function right_chain_balance(address target) internal view returns (uint256 balance) {
        if (participants[target].next != address(0)) {
            return participants[target].balance.add(right_chain_balance(participants[target].next));
        }
        return participants[target].balance;
    }

    function get_total_participation_balance(address target) public view returns (uint256 balance) {
        balance = participants[target].balance;
        if (participants[target].prev != address(0)) {
            balance = balance.add(left_chain_balance(participants[target].prev));
        }
        if (participants[target].next != address(0)) {
            balance = balance.add(right_chain_balance(participants[target].next));
        }
        return balance;
    }

    /**
    the distribution will call
    - get_total_participation_balance: to check that participants balance match participation token supply
    - get_participant_data: to check that participants balance match participation token supply and do a recursive call through nodes
     */
}
