///@beginCtx(customerSelfService)
///@valueObject
type Address {
    ///@identifier
    id: long
    streetAddress: string
    postalCode: string
    city: string
}

///@valueObject
type CustomerId {
    ///@identifier
    id: string
}
type random_type {
    self?: CustomerId
}
interface CustomerId_interface {
    RequestResponse:
        ///@sideEffectFree
        random(random_type)(CustomerId)
}

///@valueObject
type AddressDto {
    ///@neverEmpty
    streetAddress: string
    ///@neverEmpty
    postalCode: string
    ///@neverEmpty
    city: string
}
type fromAddress_type {
    address: Address
    self?: AddressDto
}
type toAddress_type {
    self?: AddressDto
}
interface AddressDto_interface {
    RequestResponse:
        ///@sideEffectFree
        fromAddress(fromAddress_type)(AddressDto),
        ///@sideEffectFree
        toAddress(toAddress_type)(Address)
}

type AddressDtos {
    d*: AddressDto
}

///@valueObject
type CustomerIdDto {
    id: string
}

///@valueObject
type CustomerDto {
    customerId: string
    customerProfile: CustomerProfileDto
}

///@valueObject
type CustomersDto {
    customers: CustomerDtos
}

type CustomerDtos {
    c*: CustomerDto
}

///@valueObject
type CustomerProfileDto {
    firstname: string
    lastname: string
    birthday: string
    currentAddress: AddressDto
    email: string
    phoneNumber: string
    moveHistory: AddressDtos
}

///@specification
type isValid_type {
    phoneNumberStr: string
}
interface PhoneNumberValidator_interface {
    RequestResponse:
        ///@validator
        isValid(isValid_type)(bool)
}

///@valueObject
type CustomerProfileUpdateRequestDto {
    ///@neverEmpty
    firstname: string
    ///@neverEmpty
    lastname: string
    birthday: string
    ///@neverEmpty
    streetAddress: string
    ///@neverEmpty
    postalCode: string
    ///@neverEmpty
    city: string
    ///@neverEmpty
    email: string
    phoneNumber: string
}

///@valueObject
type CustomerRegistrationRequestDto {
    ///@neverEmpty
    firstname: string
    ///@neverEmpty
    lastname: string
    ///@neverEmpty
    birthday: string
    ///@neverEmpty
    city: string
    ///@neverEmpty
    streetAddress: string
    ///@neverEmpty
    postalCode: string
    phoneNumber: string
}

///@entity
type UserLoginEntity {
    ///@identifier
    id: long
    authorities: string
    email: string
    password: string
    customerId: CustomerId
}

type UserSecurityDetails {
    accountNonExpired: bool
    accountNonLocked: bool
    authorities: Authorities
    credentialsNonExpired: bool
    email: string
    enabled: bool
    id: long
    password: string
}

type Authorities {
    authority*: string
}

///@domainService
type UserDetailsServiceImpl {
    userRepository: UserLoginRepository
}
type loadUserByUsername_type {
    email: string
    self?: UserDetailsServiceImpl
}
interface UserDetailsServiceImpl_interface {
    RequestResponse:
        loadUserByUsername(loadUserByUsername_type)(UserDetails)
}

type UserDetails {
    username*: string
}

///@valueObject
type AuthenticationRequestDto {
    email: string
    password: string
}

///@valueObject
type AuthenticationResponseDto {
    email: string
    token: string
}

///@valueObject
type SignupRequestDto {
    ///@neverEmpty
    email: string
    ///@neverEmpty
    password: string
}

///@valueObject
type UserResponseDto {
    email: string
    customerId: string
}

///@repository
type UserLoginRepository {
    login: UserLoginEntity
    id: long
}
type findByEmail_type {
    email: string
    self?: UserLoginRepository
}
interface UserLoginRepository_interface {
    RequestResponse:
        findByEmail(findByEmail_type)(UserLoginEntity)
}

///@valueObject
type CitiesResponseDto {
    cities: Cities
}

type Cities {
    f*: string
}

///@valueObject
///@domainEvent
type CustomerDecisionEvent {
    date: string
    insuranceQuoteRequestId: long
    quoteAccepted: bool
}

///@entity
type CustomerInfoEntity {
    ///@identifier
    id: long
    customerId: CustomerId
    firstname: string
    lastname: string
    contactAddress: Address
    billingAddress: Address
}

///@entity
type InsuranceOptionsEntity {
    ///@identifier
    id: long
    startDate: string
    insuranceType: InsuranceType
    deductible: MoneyAmount
}

///@entity
type InsuranceQuoteEntity {
    ///@identifier
    id: long
    expirationDate: string
    insurancePremium: MoneyAmount
    policyLimit: MoneyAmount
}

///@valueObject
///@domainEvent
type InsuranceQuoteExpiredEvent {
    date: string
    insuranceQuoteRequestId: long
}

///@aggregate
///@entity
type InsuranceQuoteRequestAggregateRoot {
    ///@identifier
    id: long
    date: string
    ///@part
    statusHistory: RequestStatusChanges
    ///@part
    customerInfo: CustomerInfoEntity
    ///@part
    insuranceOptions: InsuranceOptionsEntity
    insuranceQuote: InsuranceQuoteEntity
    policyId: string
}
type getStatus_type {
    self?: InsuranceQuoteRequestAggregateRoot
}
type changeStatusTo_type {
    newStatus: RequestStatus
    date: string
    self?: InsuranceQuoteRequestAggregateRoot
}
type acceptRequest_type {
    insuranceQuote: InsuranceQuoteEntity
    date: string
    self?: InsuranceQuoteRequestAggregateRoot
}
type rejectRequest_type {
    date: string
    self?: InsuranceQuoteRequestAggregateRoot
}
type acceptQuote_type {
    date: string
    self?: InsuranceQuoteRequestAggregateRoot
}
type rejectQuote_type {
    date: string
    self?: InsuranceQuoteRequestAggregateRoot
}
type markQuoteAsExpired_type {
    date: string
    self?: InsuranceQuoteRequestAggregateRoot
}
type finalizeQuote_type {
    policyId: string
    date: string
    self?: InsuranceQuoteRequestAggregateRoot
}
interface InsuranceQuoteRequestAggregateRoot_interface {
    RequestResponse:
        getStatus(getStatus_type)(RequestStatus),
        changeStatusTo(changeStatusTo_type)(void),
        acceptRequest(acceptRequest_type)(void),
        rejectRequest(rejectRequest_type)(void),
        acceptQuote(acceptQuote_type)(void),
        rejectQuote(rejectQuote_type)(void),
        markQuoteAsExpired(markQuoteAsExpired_type)(void),
        finalizeQuote(finalizeQuote_type)(void)
}

///@valueObject
///@domainEvent
type InsuranceQuoteRequestEvent {
    date: string
    insuranceQuoteRequestDto: InsuranceQuoteRequestDto
}

///@valueObject
///@domainEvent
type InsuranceQuoteResponseEvent {
    date: string
    insuranceQuoteRequestId: long
    requestAccepted: bool
    expirationDate: string
    insurancePremium: MoneyAmountDto
    policyLimit: MoneyAmountDto
}

///@valueObject
type InsuranceType {
    name: string
}

///@valueObject
type MoneyAmount {
    amount: double
    currency: string
}

///@valueObject
///@domainEvent
type PolicyCreatedEvent {
    date: string
    insuranceQuoteRequestId: long
    policyId: string
}

///@valueObject
type RequestStatus {
    literal: string(enum(["REQUEST_SUBMITTED", "REQUEST_REJECTED", "QUOTE_RECEIVED", "QUOTE_ACCEPTED", "QUOTE_REJECTED", "QUOTE_EXPIRED", "POLICY_CREATED"]))
}

///@valueObject
type RequestStatusChange {
    id: long
    date: string
    status: RequestStatus
}

type RequestStatusChanges {
    c*: RequestStatusChange
}

///@infrastructureService
type CustomerCoreRemoteProxy {
    customerCoreBaseURL: string
    successfulAttemptsCounter: int
    unsuccessfulAttemptsCounter: int
    fallBackMethodExecutionsCounter: int
}
type getCustomer_type {
    customerId: CustomerId
    self?: CustomerCoreRemoteProxy
}
type getDummyCustomer_type {
    customerId: CustomerId
    self?: CustomerCoreRemoteProxy
}
type changeAddress_type {
    customerId: CustomerId
    requestDto: AddressDto
    self?: CustomerCoreRemoteProxy
}
type createCustomer_type {
    requestDto: CustomerProfileUpdateRequestDto
    self?: CustomerCoreRemoteProxy
}
type getCitiesForPostalCode_type {
    postalCode: string
    self?: CustomerCoreRemoteProxy
}
type resetCounters_type {
    self?: CustomerCoreRemoteProxy
}
interface CustomerCoreRemoteProxy_interface {
    RequestResponse:
        getCustomer(getCustomer_type)(CustomerDto),
        getDummyCustomer(getDummyCustomer_type)(CustomerDto),
        changeAddress(changeAddress_type)(AddressDto),
        createCustomer(createCustomer_type)(CustomerDto),
        getCitiesForPostalCode(getCitiesForPostalCode_type)(CitiesResponseDto),
        resetCounters(resetCounters_type)(void)
}

///@repository
type InsuranceQuoteRequestRepository {
    quoteRequest: InsuranceQuoteRequestAggregateRoot
    id: long
}
type findByCustomerInfo_CustomerIdOrderByDateDesc_type {
    customerId: CustomerId
    self?: InsuranceQuoteRequestRepository
}
type findAllByOrderByDateDesc_type {
    self?: InsuranceQuoteRequestRepository
}
interface InsuranceQuoteRequestRepository_interface {
    RequestResponse:
        findByCustomerInfo_CustomerIdOrderByDateDesc(findByCustomerInfo_CustomerIdOrderByDateDesc_type)(InsuranceQuoteRequestAggregateRoots),
        findAllByOrderByDateDesc(findAllByOrderByDateDesc_type)(InsuranceQuoteRequestAggregateRoots)
}

type InsuranceQuoteRequestAggregateRoots {
    r*: InsuranceQuoteRequestAggregateRoot
}

///@infrastructureService
type PolicyManagementMessageProducer {
    insuranceQuoteRequestEventQueue: string
    customerDecisionEventQueue: string
}
type sendInsuranceQuoteRequest_type {
    date: string
    insuranceQuoteRequestDto: InsuranceQuoteRequestDto
    self?: PolicyManagementMessageProducer
}
type sendCustomerDecision_type {
    date: string
    insuranceQuoteRequestId: long
    quoteAccepted: bool
    self?: PolicyManagementMessageProducer
}
type emitInsuranceQuoteRequestEvent_type {
    insuranceQuoteRequestEvent: InsuranceQuoteRequestEvent
    self?: PolicyManagementMessageProducer
}
type emitCustomerDecisionEvent_type {
    customerDecisionEvent: CustomerDecisionEvent
    self?: PolicyManagementMessageProducer
}
interface PolicyManagementMessageProducer_interface {
    RequestResponse:
        sendInsuranceQuoteRequest(sendInsuranceQuoteRequest_type)(void),
        sendCustomerDecision(sendCustomerDecision_type)(void),
        emitInsuranceQuoteRequestEvent(emitInsuranceQuoteRequestEvent_type)(void),
        emitCustomerDecisionEvent(emitCustomerDecisionEvent_type)(void)
}

///@valueObject
type CustomerInfoDto {
    ///@neverEmpty
    customerId: string
    ///@neverEmpty
    firstname: string
    ///@neverEmpty
    lastname: string
    ///@neverEmpty
    contactAddress: AddressDto
    ///@neverEmpty
    billingAddress: AddressDto
}
type fromCustomerInfoEntity_type {
    customerInfo: CustomerInfoEntity
    self?: CustomerInfoDto
}
type toCustomerInfoEntity_type {
    self?: CustomerInfoDto
}
interface CustomerInfoDto_interface {
    RequestResponse:
        ///@sideEffectFree
        fromCustomerInfoEntity(fromCustomerInfoEntity_type)(CustomerInfoDto),
        ///@sideEffectFree
        toCustomerInfoEntity(toCustomerInfoEntity_type)(CustomerInfoEntity)
}

///@valueObject
type InsuranceOptionsDto {
    ///@neverEmpty
    startDate: string
    ///@neverEmpty
    insuranceType: string
    ///@neverEmpty
    deductible: MoneyAmountDto
}
type fromInsuranceOptionsEntity_type {
    insuranceOptions: InsuranceOptionsEntity
    self?: InsuranceOptionsDto
}
type toInsuranceOptionsEntity_type {
    self?: InsuranceOptionsDto
}
interface InsuranceOptionsDto_interface {
    RequestResponse:
        ///@sideEffectFree
        fromInsuranceOptionsEntity(fromInsuranceOptionsEntity_type)(InsuranceOptionsDto),
        ///@sideEffectFree
        toInsuranceOptionsEntity(toInsuranceOptionsEntity_type)(InsuranceOptionsEntity)
}

///@valueObject
type InsuranceQuoteDto {
    ///@neverEmpty
    expirationDate: string
    ///@neverEmpty
    insurancePremium: MoneyAmountDto
    ///@neverEmpty
    policyLimit: MoneyAmountDto
}
type fromInsuranceQuoteEntity_type {
    insuranceQuote: InsuranceQuoteEntity
    self?: InsuranceQuoteDto
}
interface InsuranceQuoteDto_interface {
    RequestResponse:
        ///@sideEffectFree
        fromInsuranceQuoteEntity(fromInsuranceQuoteEntity_type)(InsuranceQuoteDto)
}

///@valueObject
type InsuranceQuoteRequestDto {
    id: long
    date: string
    statusHistory: RequestStatusChangeDtos
    ///@neverEmpty
    customerInfo: CustomerInfoDto
    ///@neverEmpty
    insuranceOptions: InsuranceOptionsDto
    insuranceQuote: InsuranceQuoteDto
    policyId: string
}
type fromInsuranceQuoteRequestAggregateRoot_type {
    insuranceQuoteRequest: InsuranceQuoteRequestAggregateRoot
    self?: InsuranceQuoteRequestDto
}
interface InsuranceQuoteRequestDto_interface {
    RequestResponse:
        ///@sideEffectFree
        fromInsuranceQuoteRequestAggregateRoot(fromInsuranceQuoteRequestAggregateRoot_type)(InsuranceQuoteRequestDto)
}

type InsuranceQuoteRequestDtos {
    r*: InsuranceQuoteRequestDto
}

///@valueObject
type InsuranceQuoteResponseDto {
    ///@neverEmpty
    status: string
    expirationDate: string
    insurancePremium: MoneyAmountDto
    policyLimit: MoneyAmountDto
}

///@valueObject
type MoneyAmountDto {
    ///@neverEmpty
    amount: double
    ///@neverEmpty
    currency: string
}
type fromMoneyAmount_type {
    moneyAmount: MoneyAmount
    self?: MoneyAmountDto
}
type toMoneyAmount_type {
    self?: MoneyAmountDto
}
interface MoneyAmountDto_interface {
    RequestResponse:
        ///@sideEffectFree
        fromMoneyAmount(fromMoneyAmount_type)(MoneyAmountDto),
        ///@sideEffectFree
        toMoneyAmount(toMoneyAmount_type)(MoneyAmount)
}

///@valueObject
type RequestStatusChangeDto {
    date: string
    ///@neverEmpty
    status: string
}
type fromRequestStatusChange_type {
    requestStatusChange: RequestStatusChange
    self?: RequestStatusChangeDto
}
interface RequestStatusChangeDto_interface {
    RequestResponse:
        ///@sideEffectFree
        fromRequestStatusChange(fromRequestStatusChange_type)(RequestStatusChangeDto)
}

type RequestStatusChangeDtos {
    c*: RequestStatusChangeDto
}
///@endCtx

///@interface(org.example.CustomerSelfServiceBackend.authenticationController)
///@operationTypes(org.example.CustomerSelfServiceBackend.authenticationController.authenticationRequest)
type authenticationRequest_in {
    authenticationRequest : AuthenticationRequestDto
}
type authenticationRequest_out {
    authenticationResponse : AuthenticationResponseDto
}
///@operationTypes(org.example.CustomerSelfServiceBackend.authenticationController.signupUser)
type signupUser_in {
    registration : SignupRequestDto
}
type signupUser_out {
    userResponse : UserResponseDto
}
interface org_example_CustomerSelfServiceBackend_authenticationController {
    RequestResponse:
        authenticationRequest(authenticationRequest_in)(authenticationRequest_out),
        signupUser(signupUser_in)(signupUser_out)
}

///@interface(org.example.CustomerSelfServiceBackend.cityStaticDataHolder)
///@operationTypes(org.example.CustomerSelfServiceBackend.cityStaticDataHolder.getCitiesForPostalCode)
type getCitiesForPostalCode_in {
    postcalCode : string
}
type getCitiesForPostalCode_out {
    result : CitiesResponseDto
}
interface org_example_CustomerSelfServiceBackend_cityStaticDataHolder {
    RequestResponse:
        getCitiesForPostalCode(getCitiesForPostalCode_in)(getCitiesForPostalCode_out)
}

///@interface(org.example.CustomerSelfServiceBackend.customerInformationHolder)
///@operationTypes(org.example.CustomerSelfServiceBackend.customerInformationHolder.changeAddress)
type changeAddress_in {
    customerId : CustomerId
    requestDto : AddressDto
}
type changeAddress_out {
    result : AddressDto
}
///@operationTypes(org.example.CustomerSelfServiceBackend.customerInformationHolder.getCustomer)
type getCustomer_in {
    authentication : string
    customerId : CustomerId
}
type getCustomer_out {
    result : CustomerDto
}
///@operationTypes(org.example.CustomerSelfServiceBackend.customerInformationHolder.registerCustomer)
type registerCustomer_in {
    authentication : string
    requestDto : CustomerRegistrationRequestDto
}
type registerCustomer_out {
    result : CustomerDto
}
interface org_example_CustomerSelfServiceBackend_customerInformationHolder {
    RequestResponse:
        changeAddress(changeAddress_in)(changeAddress_out),
        getCustomer(getCustomer_in)(getCustomer_out),
        registerCustomer(registerCustomer_in)(registerCustomer_out)
}

///@interface(org.example.CustomerSelfServiceBackend.userInformationHolder)
///@operationTypes(org.example.CustomerSelfServiceBackend.userInformationHolder.getCurrentUser)
type getCurrentUser_in {
    authentitaction : string
}
type getCurrentUser_out {
    response : UserResponseDto
}
interface org_example_CustomerSelfServiceBackend_userInformationHolder {
    RequestResponse:
        getCurrentUser(getCurrentUser_in)(getCurrentUser_out)
}

///@interface(org.example.CustomerSelfServiceBackend.insuranceQuoteExpiredMessageConsumer)
///@operationTypes(org.example.CustomerSelfServiceBackend.insuranceQuoteExpiredMessageConsumer.receiveInsuranceQuoteExpiredEvent)
type receiveInsuranceQuoteExpiredEvent_in_message {
    token : Token
    message : InsuranceQuoteExpiredEvent
}
interface org_example_CustomerSelfServiceBackend_insuranceQuoteExpiredMessageConsumer {
    OneWay:
        receiveInsuranceQuoteExpiredEvent_in_message(receiveInsuranceQuoteExpiredEvent_in_message)
    RequestResponse:
        receiveInsuranceQuoteExpiredEvent_in(void)(Token)
}

///@interface(org.example.CustomerSelfServiceBackend.insuranceQuoteRequestInformationHolder)
///@operationTypes(org.example.CustomerSelfServiceBackend.insuranceQuoteRequestInformationHolder.getInsuranceQuoteRequest)
type getInsuranceQuoteRequest_in {
    authentication : string
    insuranceQuoteRequestId : long
}
type getInsuranceQuoteRequest_out {
    quoteRequestDto : InsuranceQuoteRequestDto
}
///@operationTypes(org.example.CustomerSelfServiceBackend.insuranceQuoteRequestInformationHolder.createInsuranceQuoteRequest)
type createInsuranceQuoteRequest_in {
    authentication : string
    requestDto : InsuranceQuoteRequestDto
}
type createInsuranceQuoteRequest_out {
    quoteRequestDto : InsuranceQuoteRequestDto
}
type createInsuranceQuoteRequest_out_insuranceQuoteRequestEvent {
    insuranceQuoteRequestEvent : InsuranceQuoteRequestEvent
}
///@operationTypes(org.example.CustomerSelfServiceBackend.insuranceQuoteRequestInformationHolder.respondToInsuranceQuote)
type respondToInsuranceQuote_in {
    id : long
    insuranceQuoteResponseDto : InsuranceQuoteResponseDto
}
type respondToInsuranceQuote_out {
    quoteRequestDto : InsuranceQuoteRequestDto
}
type respondToInsuranceQuote_out_customerDecisionEvent {
    customerDecisionEvent : CustomerDecisionEvent
}
interface org_example_CustomerSelfServiceBackend_insuranceQuoteRequestInformationHolder {
    RequestResponse:
        getInsuranceQuoteRequest(getInsuranceQuoteRequest_in)(getInsuranceQuoteRequest_out),
        createInsuranceQuoteRequest_in(createInsuranceQuoteRequest_in)(Token),
        createInsuranceQuoteRequest_out_insuranceQuoteRequestEvent(Token)(createInsuranceQuoteRequest_out_insuranceQuoteRequestEvent),
        createInsuranceQuoteRequest_out(Token)(createInsuranceQuoteRequest_out),
        respondToInsuranceQuote_in(respondToInsuranceQuote_in)(Token),
        respondToInsuranceQuote_out_customerDecisionEvent(Token)(respondToInsuranceQuote_out_customerDecisionEvent),
        respondToInsuranceQuote_out(Token)(respondToInsuranceQuote_out)
}

///@interface(org.example.CustomerSelfServiceBackend.insuranceQuoteResponseMessageConsumer)
///@operationTypes(org.example.CustomerSelfServiceBackend.insuranceQuoteResponseMessageConsumer.receiveInsuranceQuoteResponse)
type receiveInsuranceQuoteResponse_in_message {
    token : Token
    message : InsuranceQuoteResponseEvent
}
interface org_example_CustomerSelfServiceBackend_insuranceQuoteResponseMessageConsumer {
    OneWay:
        receiveInsuranceQuoteResponse_in_message(receiveInsuranceQuoteResponse_in_message)
    RequestResponse:
        receiveInsuranceQuoteResponse_in(void)(Token)
}

///@interface(org.example.CustomerSelfServiceBackend.policyCreatedMessageConsumer)
///@operationTypes(org.example.CustomerSelfServiceBackend.policyCreatedMessageConsumer.receivePolicyCreatedEvent)
type receivePolicyCreatedEvent_in_message {
    token : Token
    message : InsuranceQuoteResponseEvent
}
interface org_example_CustomerSelfServiceBackend_policyCreatedMessageConsumer {
    OneWay:
        receivePolicyCreatedEvent_in_message(receivePolicyCreatedEvent_in_message)
    RequestResponse:
        receivePolicyCreatedEvent_in(void)(Token)
}
