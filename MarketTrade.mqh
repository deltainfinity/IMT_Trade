//+------------------------------------------------------------------+
//|                                                  MarketTrade.mqh |
//|                                       Infinite Mind Technologies |
//|                          http://www.infinitemindtechnologies.com |
//+------------------------------------------------------------------+
#property copyright "Infinite Mind Technologies"
#property link      "http://www.infinitemindtechnologies.com"
#property version   "1.00"
#property strict

#include <IMT\trade.mqh>

class MarketTrade : public Trade{

   private:
      enum  CLOSE_MARKET_TYPE{
            CLOSE_BUY,
            CLOSE_SELL,
            CLOSE_ALL_MARKET
         };
      int OpenMarketOrder(TradeSettings &orderSettings, int orderType);
      bool CloseMultipleOrders(CLOSE_MARKET_TYPE closeType);
   
   public:
      MarketTrade();
      int OpenBuyOrder(TradeSettings &orderSettings);
      int OpenSellOrder(TradeSettings &orderSettings);
      bool CloseMarketOrder(int ticket);
      bool CloseAllBuyOrders();
      bool CloseAllSellOrders();
      bool CloseAllMarketOrders();
      bool ModifyOrderSLTPByPoints(int ticket, int stopPoints, int profitPoints = 0);
      bool ModifyOrderSLTPByPrice(int ticket, double stopPrice, double profitPrice = 0.0);
      void TrailingStop(int ticket, int trailPoints, int minProfit = 0, int step = 10);
      void TrailingStop(int ticket, double trailPrice, int minProfit = 0, int step = 10);
      void TrailingStopAll(int trailPoints, int minProfit = 0, int step = 10);
      void TrailingStopAll(double trailPrice, int minProfit = 0, int step = 10);
      void BreakEvenStop(int ticket, int minProfit, int lockProfit = 0);
      void BreakEvenStopAll(int minProfit, int lockProfit = 0);
};

//Open a market order
int MarketTrade::OpenMarketOrder(TradeSettings &orderSettings,int orderType){
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
         ticket = OrderSend(orderSettings.symbol, orderType, orderSettings.volume, orderPrice, slippage, 0, 0, orderSettings.comment, magicNumber, 0, orderSettings.arrowColor);         
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