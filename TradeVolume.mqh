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
   double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * percent;
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   int spread = (int)SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   //calculate the volume to order in lots
   volume = riskAmount / ((stopPoints + spread) * tickValue);
   volume = VerifyVolume(symbol, volume);
   
   return volume;
}

//verifies that the lot size is valid and normalizes the lot size according to the broker's lot step size
double TradeVolume::VerifyVolume(string symbol,double volume){
   
   double minSize = MarketInfo(symbol, MODE_MINLOT);
   double maxSize = MarketInfo(symbol, MODE_MAXLOT);
   double lotStep = MarketInfo(symbol, MODE_LOTSTEP);
   
   //if volume is less than broker's min size lot, adjust volume to min size
   if(volume < minSize)
      volume = minSize;
   //if volume is greater than broker's max lot size, adjust to max lot size
   else if(volume > maxSize)
      volume = maxSize;
   //normalize volume to broker's lot step size
   else
      volume = MathRound(volume / lotStep) * lotStep;
   
   return volume;
}

//calculates the order lot size using the stop loss in points
double TradeVolume::CalculateTradeVolume(string symbol,double percent,int stopPoints){

   return CalculateVolume(symbol, percent, (double)stopPoints, 0.0);
}

//calculates the order lot size using the order price and the stop loss price
double TradeVolume::CalculateTradeVolume(string symbol,double percent,double orderPrice,double stopPrice){

   return CalculateVolume(symbol, percent, stopPrice, orderPrice);
}