//+-------------------------------------------------------------------------------------+
//| Trade class file v1.0 MQL4                                                          |
//| A class to place, close, modify, delete, and retrieve information about orders      |
//| Copyright 2017 Infinite Mind Technologies                                           |
//+-------------------------------------------------------------------------------------+

#define MAX_RETRIES 3
#define RETRY_DELAY 3000
#define ADJUSTMENT_POINTS 5
#define SLEEP_TIME 10

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
      
};

