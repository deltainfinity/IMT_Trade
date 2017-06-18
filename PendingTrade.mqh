//+------------------------------------------------------------------+
//|                                                 PendingTrade.mqh |
//|                                       Infinite Mind Technologies |
//|                          http://www.infinitemindtechnologies.com |
//+------------------------------------------------------------------+
#property copyright "Infinite Mind Technologies"
#property link      "http://www.infinitemindtechnologies.com"
#property version   "1.00"
#property strict

#include <IMT\trade.mqh>

class PendingTrade : public Trade{

   protected:
       enum CLOSE_PENDING_TYPE{
         CLOSE_BUY_LIMIT,
         CLOSE_SELL_LIMIT,
         CLOSE_BUY_STOP,
         CLOSE_SELL_STOP,
         CLOSE_ALL_PENDING
      };
      int OpenPendingOrder(TradeSettings &orderSettings, int orderType);
      bool DeleteMultipleOrders(CLOSE_PENDING_TYPE deleteType);
      
   public:
      int OpenBuyStopOrder(TradeSettings &orderSettings);
      int OpenSellStopOrder(TradeSettings &orderSettings);
      int OpenBuyLimitOrder(TradeSettings &orderSettings);
      int OpenSellLimitOrder(TradeSettings &orderSettings);
      bool DeletePendingOrder(int ticket);
      bool DeleteAllBuyLimitOrders();
      bool DeleteAllSellLimitOrders();
      bool DeleteAllBuyStopOrders();
      bool DeleteAllSellStopOrders();
      bool DeleteAllPendingOrders();
      
};

//protected function to open any type of pending order
int PendingTrade::OpenPendingOrder(TradeSettings &orderSettings,int orderType){
   int retryCount = 0;
   int ticket, errorCode;
   string orderTypeDesc, errorDesc, errorMsg, successMsg;
   bool serverError;
   
   orderTypeDesc = OrderTypeToString(orderType);
   //submit order to server
   do{
      if(TradingIsAllowed()){
         //place pending order
         ticket = OrderSend(orderSettings.symbol, orderType, orderSettings.volume, orderSettings.price, slippage, orderSettings.stopLoss,
            orderSettings.takeProfit, orderSettings.comment, magicNumber, orderSettings.expiration, orderSettings.arrowColor);         
      }else
         ticket = -1;
         
      //error handling
      if(ticket == -1){
         errorCode = GetLastError();
         errorDesc = ErrorDescription(errorCode);
         serverError = RetryOnError(errorCode);
         //fatal error
         if(serverError == false){
            StringConcatenate(errorMsg, "Open ",orderTypeDesc," order: Error ",errorCode," - ",errorDesc,". Symbol: ",orderSettings.symbol,", Price:",orderSettings.price,
               ", Volume:",orderSettings.volume,", SL:",orderSettings.stopLoss,", TP:",orderSettings.takeProfit,", Expiration:",orderSettings.expiration);
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
         StringConcatenate(successMsg, orderTypeDesc," order #",ticket," opened on ",orderSettings.symbol," at ",orderSettings.price," for ",orderSettings.volume," lots.");
         Comment(successMsg);
         Print(successMsg);
         break;
      }
   }while(retryCount < MAX_RETRIES);
   //failed after retries
   if(retryCount >= MAX_RETRIES){
      StringConcatenate(errorMsg, "Open ",orderTypeDesc," order: Max retries exceeded. Symbol: ",orderSettings.symbol,", Price: ",orderSettings.price,", Volume: ",orderSettings.volume,". Error ",
                        errorCode," - ",errorDesc);
      Alert(errorMsg);
   }
   
   return ticket;
}

//protected function to delete multiple pending orders
bool PendingTrade::DeleteMultipleOrders(CLOSE_PENDING_TYPE deleteType){
   bool allOrdersDeleted = true;
   bool deleteOrder, orderSelected, orderDeleted;
   int orderType;
   
   //loop through the order pool to delete matching orders FIFO
   for(int i = 0; i < OrdersTotal(); i++){
      orderSelected = OrderSelect(i, SELECT_BY_POS);
      if(!orderSelected){
         int errorCode = GetLastError();
         string errorDesc = ErrorDescription(errorCode);
         Print("DeleteMultipleOrders: Error selecting order. Error ",errorCode," - ",errorDesc);
         continue;
      }
      //get the order type of the selected order
      orderType = OrderType();
      //determine if order type matches deleteType parameter
      if((deleteType == CLOSE_ALL_PENDING &&(orderType != OP_BUY && orderType != OP_SELL)) || (deleteType == CLOSE_BUY_LIMIT && orderType == OP_BUYLIMIT) || 
         (deleteType == CLOSE_SELL_LIMIT && orderType == OP_SELLLIMIT) || (deleteType == CLOSE_BUY_STOP && orderType == OP_BUYSTOP) || (deleteType == CLOSE_SELL_STOP && orderType == OP_SELLSTOP)){
            deleteOrder = true;
      }else
         deleteOrder = false;
      //only close orders that have a magic number matching the EA magic number
      if(deleteOrder == true && OrderMagicNumber() == magicNumber){
         orderDeleted = DeletePendingOrder(OrderTicket());
         if(!orderDeleted){
            Print("DeleteMultipleOrders: ",OrderTypeToString(orderType)," #",OrderTicket()," not deleted.");
            allOrdersDeleted = false;
         }else{
            //order was deleted so shift all orders down one ordinal
            i--;
         }
      }
   }
   return allOrdersDeleted;
}

//open a buy stop order using the TradeSettings values
int PendingTrade::OpenBuyStopOrder(TradeSettings &orderSettings){
   //check that buy stop price is the min distance above ask price and adjust if necessary
   orderSettings.price = AdjustAboveStopLevel(orderSettings.symbol, orderSettings.price);
   //if there is a stop loss in points then calculate the stop price
   if(orderSettings.sltpInPoints == true && orderSettings.stopLoss > 0){
      orderSettings.stopLoss = BuyStopLoss(orderSettings.symbol, (int)orderSettings.stopLoss, orderSettings.price);
      orderSettings.sltpInPoints = false;
   }
   //if there is a take profit in points then calculate the take profit price
   if(orderSettings.sltpInPoints == true && orderSettings.takeProfit > 0){
      orderSettings.takeProfit = BuyTakeProfit(orderSettings.symbol, (int)orderSettings.takeProfit, orderSettings.price);
      orderSettings.sltpInPoints = false;
   }
   //submit the trade
   int ticket = OpenPendingOrder(orderSettings, OP_BUYSTOP);
   return ticket;
}

