//+-------------------------------------------------------------------------------------+
//| Trade class file v1.0 MQL4                                                          |
//| A base class to place, close, modify, delete, and retrieve information about orders |
//| Copyright 2017 Infinite Mind Technologies                                           |
//+-------------------------------------------------------------------------------------+

#property strict

#include <stdlib.mqh>

#define MAX_RETRIES 3
#define RETRY_DELAY 3000
#define ADJUSTMENT_POINTS 5
#define SLEEP_TIME 10
#define MAX_CONTEXT_WAIT 30

struct TradeSettings{
   string symbol;
   double price;
   double volume;
   double stopLoss;
   double takeProfit;
   string comment;
   datetime expiration;
   color arrowColor;
   bool sltpInPoints;
   //Constructor to set default values
   TradeSettings(){price = 0.0; volume = 0.0; stopLoss = 0.0; takeProfit = 0.0; expiration = 0.0; arrowColor = clrNONE; sltpInPoints = true;}
};

class Trade{

   protected:
      int magicNumber;    //number to identify orders
      int slippage;       //max slippage for instant execution brokers
      bool TradingIsAllowed(); //checks if the trade context is free and trading is allowed
      bool RetryOnError(int errorCode); //checks to see if an operation should be retried when an error is encountered
      string OrderTypeToString(int orderType); //returns the order type as a string
      double BuyStopLoss(string symbol, int stopPoints, double openPrice = 0.0);
      double SellStopLoss(string symbol, int stopPoints, double openPrice = 0.0);
      double BuyTakeProfit(string symbol, int stopPoints, double openPrice = 0.0);
      double SellTakeProfit(string symbol, int stopPoints, double openPrice = 0.0);
      double AdjustAboveStopLevel(string symbol, double price);
      double AdjustBelowStopLevel(string symbol, double price);
      bool ModifyOrder(int ticket, TradeSettings &orderSettings);
      
   public:
      Trade(int mNumber);
      int GetMagicNumber();
      bool ModifyOrderSLTPByPoints(int ticket, int stopPoints, int profitPoints = 0);
      bool ModifyOrderSLTPByPrice(int ticket, double stopPrice, double profitPrice = 0.0);
      void TrailingStop(int ticket, int trailPoints, int minProfit = 0, int step = 10);
      void TrailingStop(int ticket, double trailPrice, int minProfit = 0, int step = 10);
      void TrailingStopAll(int trailPoints, int minProfit = 0, int step = 10);
      void TrailingStopAll(double trailPrice, int minProfit = 0, int step = 10);
      void BreakEvenStop(int ticket, int minProfit, int lockProfit = 0);
      void BreakEvenStopAll(int minProfit, int lockProfit = 0);
      bool IsPositionOpen(int ticket);
      int TypeOfOrder(int ticket);
};

//Constructor
Trade::Trade(int mNumber){
   magicNumber = mNumber;
   slippage = 0;
}

//Get the magic number that identifies the expert advisor
int Trade::GetMagicNumber(void){
   return magicNumber;
}

//Check if the trade context is free and trading is allowed
bool Trade::TradingIsAllowed(void){
   // check whether the trade context is free
   if(!IsTradeAllowed()){
      uint startWaitingTime = GetTickCount();
      // infinite loop
      while(GetTickCount() - startWaitingTime < MAX_CONTEXT_WAIT * 1000){
      // if the expert was terminated by the user, stop operation
      if(IsStopped())
         return false; 
      // if the trade context has become free, return true
      if(IsTradeAllowed())
         return true;
      // if no loop breaking condition has been met, "wait" for SLEEP_TIME 
      // and then restart checking
      Sleep(SLEEP_TIME);
      }
      return false;
   }
   else
      return true;

}

//Check to see if we should retry on a given error
bool Trade::RetryOnError(int errorCode){

   switch(errorCode){
      case ERR_BROKER_BUSY:
      case ERR_COMMON_ERROR:
      case ERR_NO_ERROR:
      case ERR_NO_CONNECTION:
      case ERR_NO_RESULT:
      case ERR_SERVER_BUSY:
      case ERR_NOT_ENOUGH_RIGHTS:
      case ERR_MALFUNCTIONAL_TRADE:
      case ERR_TRADE_CONTEXT_BUSY:
      case ERR_TRADE_TIMEOUT:
      case ERR_REQUOTE:
      case ERR_TOO_MANY_REQUESTS:
      case ERR_OFF_QUOTES:
      case ERR_PRICE_CHANGED:
      case ERR_TOO_FREQUENT_REQUESTS:
         return true;
   }
   return false;
}

//Return the order type in a human-readable string
string Trade::OrderTypeToString(int orderType){

   string orderTypeDesc;
   if(orderType == OP_BUY)
      orderTypeDesc = "buy";
   else if(orderType == OP_SELL)
      orderTypeDesc = "sell";
   else if(orderType == OP_BUYSTOP)
      orderTypeDesc = "buy stop";
   else if(orderType == OP_SELLSTOP)
      orderTypeDesc = "sell stop";
   else if(orderType == OP_BUYLIMIT)
      orderTypeDesc = "buy limit";
   else if(orderType == OP_SELLLIMIT)
      orderTypeDesc = "sell limit";
   else
      orderTypeDesc = "invalid order type";
   
   return orderTypeDesc;
}


