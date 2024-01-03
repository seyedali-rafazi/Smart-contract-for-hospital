pragma experimental ABIEncoderV2;
pragma solidity ^0.8.0;

contract TeleSurgery {
    Entity patient;
    address authorizingCommitee;
    mapping(address => Entity) entities;
    mapping(address => bool) surgeons;
    mapping(address => bool) careTakers;
    SurgeryState state;
    SurgeryResult result;
    SurgeryDomains surgeryDomain;
    string surgeryDescription;
    string[] activityIpfsHash;
    uint256 beginTimeStamp;
    uint256 endTimeStamp;

    enum Role {
        NA,
        Surgeon,
        Patient,
        CareTaker
    }
    enum SurgeryDomains {
        heart,
        kidney,
        liver,
        stomach,
        brain
    }
    enum ServiceProvided {
        nurse,
        machineOperator,
        wardBoy
    }
    enum SurgeryState {
        created,
        active,
        finished
    }
    enum SurgeryResult {
        successful,
        failed
    }
    enum ReccommendType {
        strongly,
        normal,
        not
    }

    // Structures

    struct Entity {
        address addr;
        string name;
        string location;
        Role role;
        // Valid only if role is Surgeon

        SurgeryDomains speciality;
        ReccommendType surgeonReccommended;
        bool isCertified;
        uint32 surgeriesSuccessful;
        uint32 surgeriesUnsuccessful;
        uint32 performanceRate;
        uint32 totalReviewCount;
        // Valid only if role is Patient

        string oldTransactionIpfsHash;
        string dob;
        // Valid only if role is CareTaker

        string designation;
        ServiceProvided service;
    }

    // MODIFIERS

    modifier onlySurgeon() {
        require(entities[msg.sender].addr != address(0x0));
        require(entities[msg.sender].role == Role.Surgeon);
        _;
    }

    modifier onlyPatient() {
        require(entities[msg.sender].addr != address(0x0));
        require(entities[msg.sender].role == Role.Patient);
        _;
    }

    modifier onlyCareTaker() {
        require(entities[msg.sender].addr != address(0x0));
        require(entities[msg.sender].role == Role.CareTaker);
        _;
    }

    modifier inState(SurgeryState _state) {
        require(state == _state);
        _;
    }

    constructor() public {
        authorizingCommitee = msg.sender;
    }

    // Functions

    // Common to all

    function addPatient(
        string memory _name,
        string memory _location,
        string memory _dob,
        string memory _oldTransactionIpfsHash
    ) public {
        require(entities[msg.sender].role != Role.Patient, "Already enrolled");

        entities[msg.sender].addr = msg.sender;

        entities[msg.sender].role = Role.Patient;

        entities[msg.sender].name = _name;

        entities[msg.sender].location = _location;

        entities[msg.sender].oldTransactionIpfsHash = _oldTransactionIpfsHash;

        entities[msg.sender].dob = _dob;
    }

    function addSurgeon(
        string memory _name,
        string memory _location,
        SurgeryDomains _speciality
    ) public {
        require(entities[msg.sender].role != Role.Surgeon, "Already enrolled");

        entities[msg.sender].addr = msg.sender;

        entities[msg.sender].role = Role.Surgeon;

        entities[msg.sender].name = _name;

        entities[msg.sender].location = _location;

        entities[msg.sender].isCertified = false;

        entities[msg.sender].speciality = _speciality;

        entities[msg.sender].surgeriesSuccessful = 0;

        entities[msg.sender].surgeriesUnsuccessful = 0;

        entities[msg.sender].performanceRate = 9;

        entities[msg.sender].totalReviewCount = 10;
    }

    function addCareTaker(
        string memory _name,
        string memory _location,
        string memory _designation,
        ServiceProvided _service
    ) public {
        require(
            entities[msg.sender].role != Role.CareTaker,
            "Already enrolled"
        );

        entities[msg.sender].addr = msg.sender;

        entities[msg.sender].role = Role.CareTaker;

        entities[msg.sender].name = _name;

        entities[msg.sender].location = _location;

        entities[msg.sender].designation = _designation;

        entities[msg.sender].service = _service;
    }

    function updateReccommend(address _address) internal {
        if (entities[_address].performanceRate > 9) {
            entities[_address].surgeonReccommended = ReccommendType.strongly;
        } else if (entities[_address].performanceRate > 8) {
            entities[_address].surgeonReccommended = ReccommendType.normal;
        } else {
            entities[_address].surgeonReccommended = ReccommendType.not;
        }
    }

    // BY PATIENTS

    function addSurgery(
        SurgeryDomains _surgeryDomain,
        string memory _surgeryDescription
    ) public onlyPatient {
        patient = entities[msg.sender];

        surgeryDomain = _surgeryDomain;

        surgeryDescription = _surgeryDescription;

        state = SurgeryState.created;

        beginTimeStamp = block.timestamp;
    }

    function addSurgerySurgeon(
        address _surgeon
    ) public onlyPatient inState(SurgeryState.created) {
        surgeons[_surgeon] = true;

        state = SurgeryState.active;
    }

    function addSurgeryCareTaker(
        address _careTaker
    ) public onlyPatient inState(SurgeryState.created) {
        careTakers[_careTaker] = true;

        state = SurgeryState.active;
    }

    function addSurgeonFeedback(
        address _address,
        uint32 totalPositiveFeedback
    ) public onlyPatient inState(SurgeryState.finished) {
        require(
            entities[_address].role == Role.Surgeon,
            "Can not add review if not surgeon !"
        );

        if (totalPositiveFeedback > 2) {
            entities[_address].performanceRate =
                (entities[_address].performanceRate *
                    entities[_address].totalReviewCount +
                    1) /
                (entities[_address].totalReviewCount + 1);
        } else {
            entities[_address].performanceRate =
                entities[_address].performanceRate /
                (entities[_address].totalReviewCount + 1);
        }

        entities[_address].totalReviewCount++;
        updateReccommend(_address);
    }

    // BY SURGEONS

    function viewPatientData(
        address _address
    ) public view onlySurgeon returns (string memory) {
        require(
            entities[_address].role == Role.Patient,
            "Can not view data if not patient !"
        );

        require(
            entities[msg.sender].speciality == surgeryDomain,
            "Can not access data of patients of other Surgery Domain"
        );

        return entities[_address].oldTransactionIpfsHash;
    }

    function addActivity(
        string memory _activityIpfsHash,
        address _address
    ) public onlySurgeon inState(SurgeryState.active) {
        require(
            entities[_address].role == Role.Patient,
            "Can not add activity if not patient !"
        );

        require(
            surgeons[msg.sender] == true,
            "Can not add activity of patients if not selected by the patient"
        );

        activityIpfsHash.push(_activityIpfsHash);
    }

    function finishSurgery(
        address _address,
        SurgeryResult _result
    ) public onlySurgeon inState(SurgeryState.active) {
        require(
            entities[_address].role == Role.Patient,
            "Can not finish if not a patient!"
        );

        // Set if successful or not
        result = _result;

        // Set ending timestamp
        endTimeStamp = block.timestamp;

        // Update state to finished
        state = SurgeryState.finished;

        // Update surgeon's statistics based on the result
        if (_result == SurgeryResult.successful) {
            entities[msg.sender].surgeriesSuccessful += 1;
        } else {
            entities[msg.sender].surgeriesUnsuccessful += 1;
        }
    }

    function addToHistory()
        public
        view
        inState(SurgeryState.finished)
        returns (
            SurgeryResult,
            SurgeryDomains,
            string memory,
            string[] memory,
            uint256,
            uint256
        )
    {
        return (
            result,
            surgeryDomain,
            surgeryDescription,
            activityIpfsHash,
            beginTimeStamp,
            endTimeStamp
        );
    }
}
