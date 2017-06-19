//+------------------------------------------------------------------+
//|                                                  TradeVolume.mqh |
//|                                       Infinite Mind Technologies |
//|                          http://www.infinitemindtechnologies.com |
//+------------------------------------------------------------------+
#property copyright "Infinite Mind Technologies"
#property link      "http://www.infinitemindtechnologies.com"
#property version   "1.00"
#property strict
//+------------------------------------------------------------------+
//| A class to calculate and verify trade volume for placing orders  |
//+------------------------------------------------------------------+
#define MAX_PERCENT 0.1

class TradeVolume{

      protected:
         double CalculateVolume(string symbol, double percent, double stop, double orderPrice = 0.0);
         
      public:
         double VerifyVolume(string symbol, double volume);
         double CalculateTradeVolume(string symbol, double percent, int stopPoints);
         double CalculateTradeVolume(string symbol, double percent, double orderPrice, double stopPrice);
};

//calculates the lot size based on account balance percentage to risk
double TradeVolume::CalculateVolume(string symbol,double percent,double stop,double orderPrice=0.000000){
   double volume;
   int stopPoints;
   
   //calculate the number of stop points
   if(orderPrice > 0){
      double stopDiff = MathAbs(stop - orderPrice);
      double symbolPoint = SymbolInfoDouble(symbol, SYMBOL_POINT);
      stopPoints = (int)MathRound(stopDiff / symbolPoint);
   }else
      stopPoints = (int)stop;
   //sanity check
   if(percent > MAX_PERCENT)
      percent = MAX_PERCENT;
   //get the amount to risk and the tick size
   double amount = AccountInfoDouble(ACCOUNT_BALANCE) * percent;
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   //calculate the volume to order in lots
   volume = (amount / stopPoints) / tickSize;
   volume = VerifyVolume(symbol, volume);
   
   return volume;
}


