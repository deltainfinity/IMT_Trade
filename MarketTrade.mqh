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
      int OpenMarketOrder(TradeSettings &orderSettings, int orderType); //open a market order
      bool CloseMultipleOrders(CLOSE_MARKET_TYPE closeType); //close multiple market orders
   
   public:
      MarketTrade(int mNumber):Trade(mNumber){}; //call the base class constructor (ECN brokers)
      MarketTrade(int mNumber, int slip):Trade(mNumber, slip){}; //call the overloaded base class constructor (instant execution brokers)
      int OpenBuyOrder(TradeSettings &orderSettings); //open a buy market order
      int OpenSellOrder(TradeSettings &orderSettings); //open a sell market order
      bool CloseMarketOrder(int ticket); //close a specific market order
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

//Open a market order (protected base function)
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

//close multiple market orders (protected base function)
bool MarketTrade::CloseMultipleOrders(CLOSE_MARKET_TYPE closeType){
   bool allOrdersCloseSuccessfully = true;
   bool closeOrder, orderSelected, orderClosed;
   int orderType;
   
   //loop through the order pool to close matching orders FIFO
   for(int i = 0; i < OrdersTotal(); i++){
      //select the next order
      orderSelected = OrderSelect(i, SELECT_BY_POS);
      //error handling
      if(!orderSelected){
         int errorCode = GetLastError();
         string errorDesc = ErrorDescription(errorCode);
         Print("CloseMultipleOrders error selecting order. Error ",errorCode," - ",errorDesc);
         continue; 
      }
      //get the order type of the selected order
      orderType = OrderType();
      //determine if order type matches closeType parameter
      if((closeType == CLOSE_ALL_MARKET && (orderType == OP_BUY || orderType == OP_SELL)) || (closeType == CLOSE_BUY && orderType == OP_BUY) || 
         (closeType == CLOSE_SELL && orderType == OP_SELL)){
            closeOrder = true;
      }else
         closeOrder = false;
      //only close orders that have a matching magic number
      if(closeOrder == true && OrderMagicNumber() == magicNumber){
         orderClosed = CloseMarketOrder(OrderTicket());
         if(!orderClosed){
            Alert("CloseMultipleOrders: ",OrderTypeToString(orderType)," #",OrderTicket()," not closed.");
            allOrdersClosedSuccessfully = false;
         }else //order was closed successfully so all orders shift down one ordinal
            i--;
      }
   }//end close order loop
   
   return  allOrdersClosedSuccessfully;
}

//open a buy order and return the ticket number
int MarketTrade::OpenBuyOrder(TradeSettings &orderSettings){
   int ticket = OpenMarketOrder(orderSettings, OP_BUY);
   return ticket;
}

//open a sell market order and return the ticket number
int MarketTrade::OpenSellOrder(TradeSettings &orderSettings){
   int ticket = OpenMarketOrder(orderSettings, OP_SELL);
   return ticket;
}

//close a specific market order given by the ticket number
bool MarketTrade::CloseMarketOrder(int ticket){
   int retryCount = 0;
   bool orderClosed = false;
   int errorCode;
   string errorDesc, errorMsg, successMsg;
   bool serverError;
   double closePrice = 0.0;
   
   //select ticket
   bool orderSelected = OrderSelect(ticket, SELECT_BY_TICKET);
   //exit with error if OrderSelect() fails
   if(!orderSelected){
      
   }
}