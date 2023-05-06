///@beginCtx(Common)
///@valueObject
type Money {
    amount: double
}
type add_type {
    delta: Money
    self?: Money
}
type isGreaterThanOrEqual_type {
    other: Money
    self?: Money
}
type multiply_type {
    x: int
    self?: Money
}
interface Money_interface {
    RequestResponse:
        ///@sideEffectFree
        add(add_type)(Money),
        ///@sideEffectFree
        isGreaterThanOrEqual(isGreaterThanOrEqual_type)(bool),
        ///@sideEffectFree
        multiply(multiply_type)(Money)
}

///@valueObject
type PersonName {
    firstName: string
    lastName: string
}

///@valueObject
type Address {
    street1: string
    street2: string
    city: string
    state: string
    zip: string
}
///@endCtx

///@beginCtx(Order)
///@aggregate
///@entity
type Order {
    ///@identifier
    id: long
    version: long
    state: OrderState
    consumerId: long
    restaurantId: long
    ///@part
    orderLineItems: OrderLineItems
    ///@part
    deliveryInformation: DeliveryInformation
    ///@part
    paymentInformation: PaymentInformation
    ///@part
    orderMinimum: Money
}
type getOrderTotal_type {
    self?: Order
}
interface Order_interface {
    RequestResponse:
        getOrderTotal(getOrderTotal_type)(Money)
}

type OrderState {
    literal: string(enum(["APPROVED", "APPROVAL_PENDING", "REJECTED", "REVISION_PENDING"]))
}

///@valueObject
type OrderLineItem {
    quantity: int
    menuItemId: string
    name: string
    price: Money
}
type deltaForChangedQuantity_type {
    newQuantity: int
    self?: OrderLineItem
}
type getTotal_type {
    self?: OrderLineItem
}
interface OrderLineItem_interface {
    RequestResponse:
        ///@sideEffectFree
        deltaForChangedQuantity(deltaForChangedQuantity_type)(Money),
        ///@sideEffectFree
        getTotal(getTotal_type)(Money)
}

///@valueObject
type OrderLineItems {
    lineItems: OrderLineItemsType
}
type findOrderLineItem_type {
    lineItemId: string
    self?: OrderLineItems
}
type orderTotal_type {
    self?: OrderLineItems
}
interface OrderLineItems_interface {
    RequestResponse:
        ///@sideEffectFree
        findOrderLineItem(findOrderLineItem_type)(OrderLineItem),
        ///@sideEffectFree
        orderTotal(orderTotal_type)(Money)
}

type OrderLineItemsType {
    i*: OrderLineItem
}

///@valueObject
type DeliveryInformation {
    deliveryTime: string
    deliveryAddress: Address
}

///@valueObject
type Address {
    street1: string
    street2: string
    city: string
    state: string
    zip: string
}

///@valueObject
type PaymentInformation {
    paymentToken: string
}

///@service
type createOrder_type {
    consumerId: long
    restaurantId: long
    lineItems: MenuItemIdAndQuantityList
}
type updateOrder_type {
    orderId: long
    order: Order
}
type cancel_type {
    orderId: long
}
type approveOrder_type {
    orderId: long
}
type rejectOrder_type {
    orderId: long
}
interface OrderService_interface {
    RequestResponse:
        createOrder(createOrder_type)(Order),
        updateOrder(updateOrder_type)(Order),
        cancel(cancel_type)(Order),
        approveOrder(approveOrder_type)(void),
        rejectOrder(rejectOrder_type)(void)
}

type MenuItemIdAndQuantity {
    menuItemId: string
    quantity: int
}

type MenuItemIdAndQuantityList {
    itemQuantity*: MenuItemIdAndQuantity
}
///@endCtx

///@beginCtx(API)
///@valueObject
type CreateOrderRequest {
    consumerId: long
    restaurantId: long
    lineItems: LineItems
}

type LineItem {
    menuItemId: string
    quantity: int
}

type LineItems {
    i*: LineItem
}

///@valueObject
type CreateOrderResponse {
    orderId: long
}

///@valueObject
type GetOrderResponse {
    orderId: long
    state: string
    orderTotal: double
}
///@endCtx

///@interface(org.example.OrderService.Orders)
///@operationTypes(org.example.OrderService.Orders.createOrder)
type createOrder_in {
    request : CreateOrderRequest
}
type createOrder_out {
    response : CreateOrderResponse
}
///@operationTypes(org.example.OrderService.Orders.getOrder)
type getOrder_in {
    orderId : long
}
type getOrder_out {
    response : GetOrderResponse
}
///@operationTypes(org.example.OrderService.Orders.monitorOrder)
type monitorOrder_in {
    orderId : long
}
type monitorOrder_out_response {
    response : GetOrderResponse
}
interface org_example_OrderService_Orders {
    RequestResponse:
        createOrder(createOrder_in)(createOrder_out),
        getOrder(getOrder_in)(getOrder_out),
        monitorOrder_in(monitorOrder_in)(Token),
        monitorOrder_out_response(Token)(monitorOrder_out_response)
}
