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

   protected:
      enum  CLOSE_MARKET_TYPE{
            CLOSE_BUY,
            CLOSE_SELL,
            CLOSE_ALL_MARKET
         };
      int OpenMarketOrder(TradeSettings &orderSettings, int orderType); //open a market order
      bool CloseMultipleOrders(CLOSE_MARKET_TYPE closeType); //close multiple market orders
      void TrailingStopAllLoop(bool stopInPoints, double trail, int minProfit, int step); //helper function for public TrailingStopAll functions
   
   public:
      MarketTrade(int mNumber):Trade(mNumber){}; //call the base class constructor (ECN brokers)
      MarketTrade(int mNumber, int slip):Trade(mNumber, slip){}; //call the overloaded base class constructor (instant execution brokers)
      int OpenBuyOrder(TradeSettings &orderSettings); //open a buy market order
      int OpenSellOrder(TradeSettings &orderSettings); //open a sell market order
      bool CloseMarketOrder(int ticket); //close a specific market order
      bool CloseAllBuyOrders(); //close all buy market orders that match the EA magic number
      bool CloseAllSellOrders(); //close all sell market orders that match the EA magic number
      bool CloseAllMarketOrders(); //close all martket orders (buy and sell) that match the EA magic number
      bool ModifyOrderSLTPByPoints(int ticket, int stopPoints, int profitPoints = 0); //modify the stop loss and/or take profit for an open market order by a number of points
      bool ModifyOrderSLTPByPrice(int ticket, double stopPrice, double profitPrice = 0.0); //modify the stop loss and/or take proift for an open market order to a certain  price
      void TrailingStop(int ticket, int trailPoints, int minProfit = 0, int step = 10); //calculate and add a trailing stop to an open market order using points
      void TrailingStop(int ticket, double trailPrice, int minProfit = 0, int step = 10); //calculate and add a trailing stop to an open market order using a certain price
      void TrailingStopAll(int trailPoints, int minProfit = 0, int step = 10); //add a trailing stop in points to all open market orders that match the EA magic number
      void TrailingStopAll(double trailPrice, int minProfit = 0, int step = 10); //add a trailign stop at a certain price to all open market orders that match the EA magic number
      void BreakEvenStop(int ticket, int minProfit, int lockProfit = 0); //add a break even stop to an open market order
      void BreakEvenStopAll(int minProfit, int lockProfit = 0); //add a break even stop to all open market orders that match the EA magic number
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
   bool allOrdersClosedSuccessfully = true;
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
      errorCode = GetLastError();
      errorDesc = ErrorDescription(errorCode);
      StringConcatenate(errorMsg,"Close order: Error selecting order #",ticket,". Error ",errorCode," - ",errorDesc);
      Alert(errorMsg);
      return false;
   }
   int orderType = OrderType();
   //submit order to server to be closed
   do{
      if(TradingIsAllowed()){
         //get current bid/ask price
         if(orderType == OP_BUY)
            closePrice = MarketInfo(OrderSymbol(), MODE_BID);
         else if(orderType == OP_SELL)
            closePrice = MarketInfo(OrderSymbol(), MODE_ASK);
         //close order
         orderClosed = OrderClose(ticket, OrderLots(), closePrice, slippage, CLR_NONE);
         //error handling
         if(!orderClosed){
             errorCode = GetLastError();
             errorDesc = ErrorDescription(errorCode);
             serverError = RetryOnError(errorCode);
             //fatal error
             if(serverError == false){
               StringConcatenate(errorMsg,"Close order #",ticket,": Error ",errorCode," - ",errorDesc);
               Alert(errorMsg);
               break;
             }
             //server error, retry...
             else{
               Print("Server error ",errorCode," - ",errorDesc," detected, retrying...");
               Sleep(RETRY_DELAY);
               retryCount++;
             }
         }//end error handling
         //close order successful
         else{
            StringConcatenate(successMsg,"Order #",ticket," closed.");
            Comment(successMsg);
            Print(successMsg);
            break;
         }
      }
      else{
            return orderClosed;
      }
   }while(retryCount < MAX_RETRIES);
   //failed after retries
   if(retryCount >= MAX_RETRIES){
      StringConcatenate(errorMsg,"Close order #",ticket,": Max retries exceeded. Last error was ",errorCode," - ",errorDesc);
      Alert(errorMsg);
   }
   
   return orderClosed;
}

bool MarketTrade::CloseAllBuyOrders(void){
   bool result = CloseMultipleOrders(CLOSE_BUY);
   return result;
}

bool MarketTrade::CloseAllSellOrders(void){
   bool result = CloseMultipleOrders(CLOSE_SELL);
   return result;
}

bool MarketTrade::CloseAllMarketOrders(void){
   bool result = CloseMultipleOrders(CLOSE_ALL_MARKET);
   return result;
}

bool MarketTrade::ModifyOrderSLTPByPoints(int ticket,int stopPoints,int profitPoints=0){
   //sanity check
   if(stopPoints <= 0 && profitPoints <= 0)
      return false;
   //select the order to modify
   bool orderSelected = OrderSelect(ticket, SELECT_BY_TICKET);
   if(!orderSelected){
      Print("Modify Order SLTP By Points: order #",ticket," not selected!");
      return false;
   }
   //get order type, order symbol, and order open price for selected order
   TradeSettings orderSettings;
   int orderType = OrderType();
   orderSettings.symbol = OrderSymbol();
   orderSettings.price = OrderOpenPrice();
   //calculate and adjust stop loss and take profit for open buy order
   if(orderType == OP_BUY){
      orderSettings.stopLoss = BuyStopLoss(orderSettings.symbol, stopPoints, orderSettings.price);
      if(orderSettings.stopLoss > 0){
         orderSettings.stopLoss = AdjustBelowStopLevel(orderSettings.symbol, orderSettings.stopLoss);
      }
      orderSettings.takeProfit = BuyTakeProfit(orderSettings.symbol, profitPoints, orderSettings.price);
      if(orderSettings.takeProfit > 0){
         orderSettings.takeProfit = AdjustAboveStopLevel(orderSettings.symbol, orderSettings.takeProfit);
      }
   }else if(orderType == OP_SELL){
      orderSettings.stopLoss = SellStopLoss(orderSettings.symbol, stopPoints, orderSettings.price);
      if(orderSettings.stopLoss > 0){
         orderSettings.stopLoss = AdjustAboveStopLevel(orderSettings.symbol, orderSettings.stopLoss);
      }
      orderSettings.takeProfit = SellTakeProfit(orderSettings.symbol, stopPoints, orderSettings.price);
      if(orderSettings.takeProfit > 0){
         orderSettings.takeProfit = AdjustBelowStopLevel(orderSettings.symbol, orderSettings.takeProfit);
      }
   }
   //set the orderSettings price to 0 to comply with MetaTrader required parameter values
   orderSettings.price = 0;
   bool orderModified = ModifyOrder(ticket, orderSettings);
   return orderModified;
}

bool MarketTrade::ModifyOrderSLTPByPrice(int ticket,double stopPrice,double profitPrice=0.000000){
   //sanity check
   if(stopPrice <= 0 && profitPrice <= 0)
      return false;
   //select the order to modify
   bool orderSelected = OrderSelect(ticket, SELECT_BY_TICKET);
   if(!orderSelected){
      Print("Modify Order SLTP By Price: order #",ticket," not selected!");
      return false;
   }
   //get order type, order symbol, and order open price for selected order
   TradeSettings orderSettings;
   int orderType = OrderType();
   orderSettings.symbol = OrderSymbol();
   orderSettings.price = OrderOpenPrice();
   //calculate and adjust stop loss and take profit for open buy order
   if(orderType == OP_BUY){
      if(orderSettings.stopLoss > 0)
         orderSettings.stopLoss = AdjustBelowStopLevel(orderSettings.symbol, orderSettings.stopLoss);
      if(orderSettings.takeProfit > 0)
         orderSettings.takeProfit = AdjustAboveStopLevel(orderSettings.symbol, orderSettings.takeProfit);
   }else if(orderType == OP_SELL){
      if(orderSettings.stopLoss > 0)
         orderSettings.stopLoss = AdjustAboveStopLevel(orderSettings.symbol, orderSettings.stopLoss);
      if(orderSettings.takeProfit > 0)
         orderSettings.takeProfit = AdjustBelowStopLevel(orderSettings.symbol, orderSettings.takeProfit);
   }
   //set the orderSettings price to 0 to comply with MetaTrader required parameter values
   orderSettings.price = 0;
   bool orderModified = ModifyOrder(ticket, orderSettings);
   return orderModified;
}

//create a trailing stop using points
void MarketTrade::TrailingStop(int ticket,int trailPoints,int minProfit=0,int step=10){
   //sanity check
   if(trailPoints <= 0)
      return;
   //select the order to modify
    bool orderSelected = OrderSelect(ticket, SELECT_BY_TICKET);
   if(!orderSelected){
      Print("TrailingStop using points: order #",ticket," not selected!");
      return;
   }
   bool setTrailingStop = false;
   //get order and symbol information
   int orderType = OrderType();
   TradeSettings orderSettings;
   orderSettings.symbol = OrderSymbol();
   orderSettings.stopLoss = OrderStopLoss();
   orderSettings.takeProfit = OrderTakeProfit();
   orderSettings.price = OrderOpenPrice();
   orderSettings.sltpInPoints = false;
   double point = MarketInfo(orderSettings.symbol, MODE_POINT);
   int digits = (int)MarketInfo(orderSettings.symbol, MODE_DIGITS);
   //convert input into prices
   double trailPointsAmount = trailPoints * point;
   double minProfitAmount = minProfit * point;
   double stepAmount = step * point;
   //calculate trailing stop
   double trailStopPrice = 0.0, currentProfit;
   if(orderType == OP_BUY){
      double bid = MarketInfo(orderSettings.symbol, MODE_BID);
      trailStopPrice = bid - trailPointsAmount;
      trailStopPrice = NormalizeDouble(trailStopPrice, digits);
      currentProfit = bid - orderSettings.price;
      if(trailStopPrice > orderSettings.stopLoss + stepAmount && currentProfit >= minProfitAmount)
         setTrailingStop = true;
   }else if(orderType == OP_SELL){
      double ask = MarketInfo(orderSettings.symbol, MODE_ASK);
      trailStopPrice = ask + trailPointsAmount;
      trailStopPrice = NormalizeDouble(trailStopPrice, digits);
      currentProfit = orderSettings.price - ask;
      if((trailStopPrice < orderSettings.stopLoss - stepAmount || orderSettings.stopLoss == 0) && currentProfit >= minProfit)
         setTrailingStop = true;
   }
   //set trailing stop
   if(setTrailingStop == true){
      orderSettings.stopLoss = trailStopPrice;
      orderSettings.price = 0;
      bool orderModified = ModifyOrder(ticket, orderSettings);
      if(!orderModified){
         Print("Trailing stop for order #",ticket," not set! Trail Stop: ",orderSettings.stopLoss,", Current Stop: ",OrderStopLoss(),", Current Profit: ",currentProfit);
      }else{
         Comment("Trailing stop for order #",ticket," modified to ",trailStopPrice);
         Print("Trailing stop for order #",ticket," modified to ",trailStopPrice);
      }
   }
}

//create a trailing stop using a price
void MarketTrade::TrailingStop(int ticket,double trailPrice,int minProfit=0,int step=10){
   //sanity check
   if(trailPrice <= 0)
      return;
   //select the order to modify
    bool orderSelected = OrderSelect(ticket, SELECT_BY_TICKET);
   if(!orderSelected){
      Print("TrailingStop using price: order #",ticket," not selected!");
      return;
   }
   bool setTrailingStop = false;
   //get order and symbol information
   int orderType = OrderType();
   TradeSettings orderSettings;
   orderSettings.symbol = OrderSymbol();
   orderSettings.stopLoss = OrderStopLoss();
   orderSettings.takeProfit = OrderTakeProfit();
   orderSettings.price = OrderOpenPrice();
   orderSettings.sltpInPoints = false;
   double point = MarketInfo(orderSettings.symbol, MODE_POINT);
   int digits = (int)MarketInfo(orderSettings.symbol, MODE_DIGITS);
   //convert input into prices
   double minProfitAmount = minProfit * point;
   double stepAmount = step * point;
   //calculate trailing stop
   double currentProfit;
   if(orderType == OP_BUY){
      trailPrice = AdjustBelowStopLevel(orderSettings.symbol, trailPrice);
      double bid = MarketInfo(orderSettings.symbol, MODE_BID);
      currentProfit = bid - orderSettings.price;
      if(trailPrice > orderSettings.stopLoss + stepAmount && currentProfit >= minProfitAmount)
         setTrailingStop = true;
   }else if(orderType == OP_SELL){
      trailPrice = AdjustAboveStopLevel(orderSettings.symbol, trailPrice);
      double ask = MarketInfo(orderSettings.symbol, MODE_ASK);
      currentProfit = orderSettings.price - ask;
      if((trailPrice < orderSettings.stopLoss - stepAmount || orderSettings.stopLoss == 0) && currentProfit >= minProfit)
         setTrailingStop = true;
   }
   //set trailing stop
   if(setTrailingStop == true){
      orderSettings.stopLoss = trailPrice;
      orderSettings.price = 0;
      bool orderModified = ModifyOrder(ticket, orderSettings);
      if(!orderModified){
         Print("Trailing stop for order #",ticket," not set! Trail Stop: ",orderSettings.stopLoss,", Current Stop: ",OrderStopLoss(),", Current Profit: ",currentProfit);
      }else{
         Comment("Trailing stop for order #",ticket," modified to ",trailPrice);
         Print("Trailing stop for order #",ticket," modified to ",trailPrice);
      }
   }
}

//Helper function for TrailingStopAll overloaded functions
void MarketTrade::TrailingStopAllLoop(bool stopInPoints, double trail, int minProfit, int step){
   bool orderSelected;
   int orderType;
   //loop through order pool and add trailing stop to orders FIFO
   for(int i = 0; i < OrdersTotal(); i++){
      orderSelected = OrderSelect(i, SELECT_BY_POS);
      if(!orderSelected){
         int errorCode = GetLastError();
         string errorDesc = ErrorDescription(errorCode);
         Print("TrailingStopAll error selecting order. Error ",errorCode," - ",errorDesc);
         continue;
      }
      //get the order type of the selected order
      orderType = OrderType();
      //skip if magic number doesn't match or order is pending, otherwise set a trailing stop on the order
      if(magicNumber == OrderMagicNumber() && (orderType == OP_BUY || orderType == OP_SELL)){
         if(stopInPoints == true)
            TrailingStop(OrderTicket(), (int)trail, minProfit, step);
         else
            TrailingStop(OrderTicket(), trail, minProfit, step);
      }
   }
}

//Set a trailing stop in points for all open orders matching the EA magic nmumber
void MarketTrade::TrailingStopAll(int trailPoints,int minProfit=0,int step=10){
   TrailingStopAllLoop(true, (double)trailPoints, minProfit, step);
}

//Set a trailing stop price for all open orders matching the EA magic number 
void MarketTrade::TrailingStopAll(double trailPrice,int minProfit=0,int step=10){
   TrailingStopAllLoop(false, trailPrice, minProfit, step);
}

void MarketTrade::BreakEvenStop(int ticket,int minProfit,int lockProfit=0){
   //sanity check
   if(minProfit <= 0)
      return;
   bool orderSelected = OrderSelect(ticket, SELECT_BY_TICKET);
   if(!orderSelected){
      Print("BreakEvenStop: order #",ticket," not selected!");
      return;
   }
   bool setBreakEvenStop = false;
   //get order and symbol information
   int orderType = OrderType();
   TradeSettings ts;
   ts.symbol = OrderSymbol();
   ts.stopLoss = OrderStopLoss();
   ts.takeProfit = OrderTakeProfit();
   ts.price = OrderOpenPrice();
   ts.sltpInPoints = false;
   double point = MarketInfo(ts.symbol, MODE_POINT);
   int digits = (int)MarketInfo(ts.symbol, MODE_DIGITS);
   //convert input to prices
   double minProfitAmount = minProfit * point;
   double lockProfitAmount = lockProfit * point;
   //calculate break even stop price
   double breakEvenStopPrice = 0.0, currentProfit;
   if(orderType == OP_BUY){
      double bid = MarketInfo(ts.symbol, MODE_BID);
      breakEvenStopPrice = ts.price + lockProfitAmount;
      breakEvenStopPrice = NormalizeDouble(breakEvenStopPrice, digits);
      currentProfit = bid - ts.price;
      if(breakEvenStopPrice > ts.stopLoss && currentProfit >= minProfitAmount)
         setBreakEvenStop = true;
   }else if(orderType == OP_SELL){
      double ask = MarketInfo(ts.symbol, MODE_ASK);
      breakEvenStopPrice = ts.price - lockProfitAmount;
      breakEvenStopPrice = NormalizeDouble(breakEvenStopPrice, digits);
      currentProfit = ts.price - ask;
      if((breakEvenStopPrice < ts.stopLoss || ts.stopLoss == 0) && currentProfit >= minProfitAmount)
         setBreakEvenStop = true;
   }
   //set break even stop
   if(setBreakEvenStop == true){
      ts.stopLoss = breakEvenStopPrice;
      ts.price = 0;
      bool orderModified = ModifyOrder(ticket, ts);
      if(!orderModified){
         Print("Break even stop for order #",ticket," not set! Break Even Stop: ",ts.stopLoss,", Current Stop: ",OrderStopLoss(),", Current Profit: ",currentProfit);
      }else{
         Comment("Break even stop for order #",ticket," set at ",ts.stopLoss);
         Print("Break even stop for order #",ticket," set at ",ts.stopLoss);
      }
   }
}

void MarketTrade::BreakEvenStopAll(int minProfit,int lockProfit=0){ 
   bool orderSelected;
   int orderType;
   //loop through the order pool FIFO
   for(int i = 0; i < OrdersTotal(); i++){
      orderSelected = OrderSelect(i, SELECT_BY_POS);
      if(!orderSelected){
         int errorCode = GetLastError();
         string errorDesc = ErrorDescription(errorCode);
         Print("BreakEvenStopAll: error selecting order. Error ",errorCode," - ",errorDesc);
         continue;
      }
      //get the order type of the selected order
      orderType = OrderType();
      //set the break even stop if the magic numbers match and the order is not pending
      if(magicNumber == OrderMagicNumber() && (orderType == OP_BUY || orderType == OP_SELL)){
         BreakEvenStop(OrderTicket(), minProfit, lockProfit);
      }
   }
}