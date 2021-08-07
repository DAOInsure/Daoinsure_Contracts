pragma experimental ABIEncoderV2;
pragma solidity ^0.5.0;

// To do
// Connecting to Superfluid
// ERC20 DAO Token

interface IVoteCount {
    function balanceOf(address _userAddress) external view returns (uint256);
}

interface ISendClaimAmount {
    function withdrawAmount(address _recipient, uint256 _amount) external;
}

interface IChainlinkData {
    function requestWeatherData(
        string calldata _lat,
        string calldata _lon,
        string calldata _dt,
        uint256 proposalId
    ) external returns (bytes32);

    function getRain() external returns (uint256);
}

contract Governance {
    // 🚨 Address of ISuperToken needs to be initialised after contract deployment
    address public daoInsureTokenAddress;
    address public superAppContractAddress;

    uint256 public proposalIdNumber;

    int256 public daoMemberCount;

    IChainlinkData chainlinkContract;

    uint256[] public arr;

    struct Proposal {
        uint256 proposalId;
        address userAddress;
        string proposalString;
        uint256 claimAmount;
        uint256 yesVotes;
        uint256 noVotes;
        bool voting;
        bool passed;
        uint256 endTime;
        string ipfsHash;
        string dateOfIncident;
        uint256 rainData;
    }

    struct Member {
        address memberAddress;
        string lat;
        string long;
        uint256 votes;
        uint256 proposals;
    }

    constructor(address _add) public {
        proposalIdNumber = 0;
        daoMemberCount = 0;
        chainlinkContract = IChainlinkData(_add);
    }

    modifier daoMember() {
        require(
            countVotes(daoInsureTokenAddress, msg.sender) > 0,
            "You are not a DAO member"
        );
        _;
    }

    modifier onlyAdmin() {
        require(
            msg.sender == 0xbbbaaD77908e7143B6b4D5922fd201cd08568f63,
            "You are not an admin"
        );
        _;
    }

    mapping(uint256 => Proposal) public proposalsMapping;

    // 🚨 Need to check if this is needed
    mapping(uint256 => mapping(address => bool)) public userVoteForProposal;

    mapping(address => Member) public daoMemberMapping;

    // To check if user address exists
    mapping(address => bool) internal addressMemberCheck;

    // To store a particular users' claims
    mapping(address => uint256[]) internal userClaims;

    mapping(address => uint256[]) public userVotedFor;

    function countVotes(address _contract, address _userAddress)
        public
        view
        returns (uint256)
    {
        return (IVoteCount(_contract).balanceOf(_userAddress));
    }

    function isUserADaoMember(address _adr) public view returns (bool) {
        if (addressMemberCheck[_adr] == true) {
            return true;
        } else if (addressMemberCheck[_adr] == false) {
            return false;
        }
    }

    function getClaimAmount(address _member) public view returns (uint256) {
        return countVotes(daoInsureTokenAddress, _member);
    }

    // function getRain() public returns (uint256) {
    //     // return chainlinkContract().rain();
    // }

    function setRain(uint256 _proposalId, uint256 _rain) public {
        proposalsMapping[_proposalId].rainData = _rain;
    }

    function createProposal(
        string memory _proposalString,
        string memory _dt,
        string memory _ipfsHash
    ) public daoMember {
        // chainlinkContract.requestWeatherData("19.0434", "72.8593", "1628047190", proposalIdNumber);
        chainlinkContract.requestWeatherData(
            daoMemberMapping[msg.sender].lat,
            daoMemberMapping[msg.sender].long,
            _dt,
            proposalIdNumber
        );

        proposalsMapping[proposalIdNumber] = Proposal({
            proposalId: proposalIdNumber,
            userAddress: msg.sender,
            claimAmount: getClaimAmount(msg.sender),
            proposalString: _proposalString,
            yesVotes: 0,
            noVotes: 0,
            voting: true,
            passed: false,
            endTime: (now + 3 minutes),
            ipfsHash: _ipfsHash,
            dateOfIncident: _dt,
            rainData: 0
        });

        userClaims[msg.sender].push(proposalIdNumber);
        proposalIdNumber += 1;
        daoMemberMapping[msg.sender].proposals =
            daoMemberMapping[msg.sender].proposals +
            1;
    }

    function returnUserClaims(address _add)
        public
        view
        daoMember
        returns (uint256[] memory)
    {
        return userClaims[_add];
    }

    function returnProposalById(uint256 _proposalId)
        public
        view
        returns (Proposal memory)
    {
        return (proposalsMapping[_proposalId]);
    }

    function returnUserVotes(address _add)
        public
        view
        daoMember
        returns (uint256[] memory)
    {
        return userVotedFor[_add];
    }

    // Also need to check if Proposal exists
    function voteOnProposal(uint256 _proposalId, bool _vote)
        public
        daoMember
        returns (uint256, uint256)
    {
        require(
            proposalsMapping[_proposalId].voting == true,
            "Voting has ended"
        );

        require(
            !userVoteForProposal[_proposalId][msg.sender],
            "User has already voted"
        );

        userVoteForProposal[_proposalId][msg.sender] = true;

        if (now >= proposalsMapping[_proposalId].endTime) {
            endProposalVoting(_proposalId);
        } else if (now <= proposalsMapping[_proposalId].endTime) {
            if (_vote == false) {
                proposalsMapping[_proposalId].noVotes += 1;
                userVotedFor[msg.sender].push(_proposalId);
                return (
                    proposalsMapping[_proposalId].yesVotes,
                    proposalsMapping[_proposalId].noVotes
                );
            } else if (_vote == true) {
                proposalsMapping[_proposalId].yesVotes += 1;
                userVotedFor[msg.sender].push(_proposalId);
                return (
                    proposalsMapping[_proposalId].yesVotes,
                    proposalsMapping[_proposalId].noVotes
                );
            }
        }
    }

    // 🚨 Restriction needs to be added here
    function endProposalVoting(uint256 _proposalId) public {
        // Add a require here only for Chainlink Keeper
        proposalsMapping[_proposalId].voting = false;
        settleOutcome(_proposalId);
    }

    function setAddresses(address _tokenAddress, address _superApp)
        public
        onlyAdmin
    {
        daoInsureTokenAddress = _tokenAddress;
        superAppContractAddress = _superApp;
    }

    // 🚨 Need to add modifier to restrict access + add a return + consider any other require
    function addDaoMember(
        address _memberAddress,
        string memory _lat,
        string memory _long
    ) public {
        daoMemberMapping[_memberAddress] = Member({
            memberAddress: _memberAddress,
            lat: _lat,
            long: _long,
            votes: 0,
            proposals: 0
        });

        daoMemberCount = daoMemberCount + 1;
        addressMemberCheck[_memberAddress] = true;
    }

    // 🚨 Need to add modifier to restrict access + add a return + consider any other require
    function removeDaoMember(address _memberAddress) public {
        delete daoMemberMapping[_memberAddress];
        daoMemberCount = daoMemberCount - 1;
    }

    function settleOutcome(uint256 _proposalId) public {
        if (
            proposalsMapping[_proposalId].yesVotes >
            proposalsMapping[_proposalId].noVotes
        ) {
            proposalsMapping[_proposalId].passed = true;
            ISendClaimAmount(superAppContractAddress).withdrawAmount(
                proposalsMapping[_proposalId].userAddress,
                proposalsMapping[_proposalId].claimAmount
            );
        } else if (
            proposalsMapping[_proposalId].yesVotes <=
            proposalsMapping[_proposalId].noVotes
        ) {
            proposalsMapping[_proposalId].passed = false;
        }
    }

    // 🚨 need to limit who can call this function
    function claimProposal(uint256 _proposalId) public {
        require(
            now >= proposalsMapping[_proposalId].endTime,
            "Voting is still active"
        );
        endProposalVoting(_proposalId);
    }
}
