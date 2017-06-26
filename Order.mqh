//+------------------------------------------------------------------+
//|    A class to wrap the order number returned by the trade server |
//|                                       Infinite Mind Technologies |
//|                          http://www.infinitemindtechnologies.com |
//+------------------------------------------------------------------+
#property copyright "Infinite Mind Technologies"
#property link      "http://www.infinitemindtechnologies.com"
#property version   "1.00"
#property strict

class Order{
   public:
      Order(int ticket, int mNumber);
      int GetOrderID(void);
      bool IsOrderValid(void);
      bool IsPositionOpen(void);
      int GetOrderType(void);
      
   private:
      int orderID;
      int magicNumber;
};

Order::Order(int ticket, int mNumber){
   orderID = ticket;
   magicNumber = mNumber;
}

int Order::GetOrderID(void){
   return orderID;
}

bool Order::IsOrderValid(void){
   if(orderID > -1)
      return true;
   else
      return false;
}

bool Order::IsPositionOpen(void){
   if(!IsOrderValid())
      return false;
   bool orderSelected = OrderSelect(orderID, SELECT_BY_TICKET);
   if(!orderSelected){
      Print("IsPositionOpen: order #",orderID," not found!");
      return false;
   }
   int orderType = OrderType();
   if(orderType == OP_BUY || orderType == OP_SELL){
      if(OrderCloseTime() == 0)
         return true;
   }
   return false;
}

int Order::GetOrderType(void){
   if(!IsOrderValid())
      return -1;
   bool orderSelected = OrderSelect(orderID, SELECT_BY_TICKET);
   if(!orderSelected){
      Print("GetOrderID: order #",orderID," not found!");
      return -1;
   }
   
   return OrderType();
}