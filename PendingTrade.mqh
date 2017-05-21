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

   private:
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