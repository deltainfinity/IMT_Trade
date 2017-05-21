//+------------------------------------------------------------------+
//|    A class to wrap the order number returned by the trade server |
//|                                       Infinite Mind Technologies |
//|                          http://www.infinitemindtechnologies.com |
//+------------------------------------------------------------------+
#property copyright "Infinite Mind Technologies"
#property link      "http://www.infinitemindtechnologies.com"
#property strict

class Order{
   
   public:
      Order(int oID, int mNumber);
      int GetOrderID(void);
      bool IsOrderValid(void);
      
   private:
      int orderID;
      int magicNumber;
};

Order::Order(int oID, int mNumber){

   orderID = oID;
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