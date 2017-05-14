//+-------------------------------------------------------------------------------------+
//| Trade class file v1.0 MQL4                                                          |
//| A class to place, close, modify, delete, and retrieve information about orders      |
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
      enum  CLOSE_MARKET_TYPE{
         CLOSE_BUY,
         CLOSE_SELL,
         CLOSE_ALL_MARKET
      };
      enum CLOSE_PENDING_TYPE{
         CLOSE_BUY_LIMIT,
         CLOSE_SELL_LIMIT,
         CLOSE_BUY_STOP,
         CLOSE_SELL_STOP,
         CLOSE_ALL_PENDING
      };
      
   private:
      int magicNumber;    //number to identify orders
      int slippage;       //max slippage for instant execution brokers
      
      bool TradingIsAllowed();
      int OpenMarketOrder(TradeSettings &orderSettings, int orderType);
      int OpenPendingOrder(TradeSettings &orderSettings, int orderType);
      bool RetryOnError(int errorCode);
      string OrderTypeToString(int orderType);
      double BuyStopLoss(string symbol, int stopPoints, double openPrice = 0.0);
      double SellStopLoss(string symbol, int stopPoints, double openPrice = 0.0);
      double BuyTakeProfit(string symbol, int stopPoints, double openPrice = 0.0);
      double SellTakeProfit(string symbol, int stopPoints, double openPrice = 0.0);
      double AdjustAboveStopLevel(string symbol, double price);
      double AdjustBelowStopLevel(string symbol, double price);
      bool ModifyOrder(int ticket, TradeSettings &orderSettings);
      bool CloseMultipleOrders(CLOSE_MARKET_TYPE closeType);
      bool DeleteMultipleOrders(CLOSE_PENDING_TYPE deleteType);
      
   public:
      Trade(int mNumber);
      int GetMagicNumber();
      int OpenBuyOrder(TradeSettings &orderSettings);
      int OpenSellOrder(TradeSettings &orderSettings);
      int OpenBuyStopOrder(TradeSettings &orderSettings);
      int OpenSellStopOrder(TradeSettings &orderSettings);
      int OpenBuyLimitOrder(TradeSettings &orderSettings);
      int OpenSellLimitOrder(TradeSettings &orderSettings);
      bool ModifyOrderSLTPByPoints(int ticket, int stopPoints, int profitPoints = 0);
      bool ModifyOrderSLTPByPrice(int ticket, double stopPrice, double profitPrice = 0.0);
      bool CloseMarketOrder(int ticket);
      bool DeletePendingOrder(int ticket);
      bool CloseAllBuyOrders();
      bool CloseAllSellOrders();
      bool CloseAllMarketOrders();
      bool DeleteAllBuyLimitOrders();
      bool DeleteAllSellLimitOrders();
      bool DeleteAllBuyStopOrders();
      bool DeleteAllSellStopOrders();
      bool DeleteAllPendingOrders();
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

//Open a market order
int Trade::OpenMarketOrder(TradeSettings &orderSettings,int orderType){
   int retryCount = 0;
   int ticket, errorCode;
   double orderPrice = 0.0;
   string orderTypeDesc, errorDesc, errorMsg, successMsg;
   bool serverError;
   
   orderTypeDesc = OrderTypeToString(orderType);
   //submit order to server
   do{
      if(TradingIsAllowed()){
         //get current bid/ask price
         if(orderType == OP_BUY)
            orderPrice = SymbolInfoDouble(orderSettings.symbol, SYMBOL_ASK);
         else if(orderType == OP_SELL)
            orderPrice = SymbolInfoDouble(orderSettings.symbol, SYMBOL_BID);
         //place market order
         ticket = OrderSend(orderSettings.symbol, orderType, orderSettings.volume, orderPrice, 0, 0, 0, orderSettings.comment, magicNumber, 0, orderSettings.arrowColor);         
      }
      else
         ticket = -1;
         
      //error handling
      if(ticket == -1){
         errorCode = GetLastError();
         errorDesc = ErrorDescription(errorCode);
         serverError = RetryOnError(errorCode);
         //fatal error
         if(serverError == false){
            StringConcatenate(errorMsg, "Open ",orderTypeDesc," market order: Error ",errorCode," - ",errorDesc);
            Alert(errorMsg);
            break;
         }
         //server error, retry
         else{
            Print("Server error ",errorCode," - ",errorDesc," detected, retrying...");
            Sleep(RETRY_DELAY);
            retryCount++;
         }
      }//end error handling
      //order successful
      else{
         StringConcatenate(successMsg, "Market ",orderTypeDesc," order #",ticket," opened on ",orderSettings.symbol," at ",orderPrice," for ",orderSettings.volume," lots.");
         Print(successMsg);
         break;
      }
   }while(retryCount < MAX_RETRIES);
   //failed after retries
   if(retryCount >= MAX_RETRIES){
      StringConcatenate(errorMsg, "Open ",orderTypeDesc," market order: Max retries exceeded. Symbol: ",orderSettings.symbol,", Price: ",orderPrice,", Volume: ",orderSettings.volume,". Error ",
                        errorCode," - ",errorDesc);
      Alert(errorMsg);
   }
   
   //check and calculate SLTP if there is an open order and a SLTP
   if(ticket > -1 && (orderSettings.stopLoss > 0 || orderSettings.takeProfit > 0)){
      if(orderSettings.sltpInPoints == true){
         bool orderModified = ModifyOrderSLTPByPoints(ticket, (int)orderSettings.stopLoss, (int)orderSettings.takeProfit);
         if(!orderModified){
            Alert("Stop loss and/or take profit not added to order #",ticket);
         }
      }else{
         bool orderModified = ModifyOrderSLTPByPrice(ticket, orderSettings.stopLoss, orderSettings.takeProfit);
         if(!orderModified){
            Alert("Stop loss and/or take profit not added to order #",ticket);
         }
      }
   }
   
   return ticket;
}//end OpenMarketOrder
