//+------------------------------------------------------------------+
//|                                                        Timer.mqh |
//|                                       Infinite Mind Technologies |
//|                          http://www.infinitemindtechnologies.com |
//+------------------------------------------------------------------+
#property copyright "Infinite Mind Technologies"
#property link      "http://www.infinitemindtechnologies.com"
#property version   "1.00"
#property strict
//+------------------------------------------------------------------+
//| A class to calculate times for trading.                          |
//+------------------------------------------------------------------+
#define TIME_ADD_MINUTE 60
#define TIME_ADD_HOUR 3600
#define TIME_ADD_DAY 86400
#define TIME_ADD_WEEK 604800

class Timer{

   protected:
      datetime _startTime, _endTime;
      bool _useLocalTime;

   public:
      Timer(int startHour, int startMinute, int endHour, int endMinute, bool useLocalTime = false); //constructor for use in a single day
      Timer(datetime startTime, datetime endTime, bool useLocalTime = false); //overloaded constructor for any time span
      bool CheckTimer(datetime startTime, datetime endTime, bool useLocalTime = false); //checks if the parameter start and end time encompass the current time
      bool DailyTimer(); //adds 24 hours to the protected instance variables if they are > 24 hours behind the current time (local or server)
      datetime GetStartTime(); //returns the value of the _startTime protected instance variable
      datetime GetEndTime(); //returns the value of the _endTime protected instance variable
      bool GetUseLocalTime(); //returns the value of the _useLocalTime protected instance variable
};

//constructor for use in a single day
Timer::Timer(int startHour,int startMinute,int endHour,int endMinute,bool useLocalTime=false){
   //sanity checks
   if(startHour < 0)
      startHour = 0;
   if(startMinute < 0)
      startMinute = 0;
   if(endHour < 0)
      endHour = 0;
   if(endMinute < 0)
      endMinute = 0;
   datetime currentStart, currentEnd;
   MqlDateTime currentStartTime, currentEndTime;
   //get the local or server time, depending on parameter value
   if(!useLocalTime){
      currentStart = TimeCurrent();
      currentEnd = TimeCurrent();
   }else{
      currentStart = TimeLocal();
      currentEnd = TimeLocal();
   }
   //convert the time to MqlDateTime structure
   TimeToStruct(currentStart, currentStartTime);
   TimeToStruct(currentEnd, currentEndTime);
   //set the start and end time in the MqlDateTime structures to reflect the parameter values
   currentStartTime.hour = startHour;
   currentStartTime.min = startMinute;
   currentStartTime.sec = 0;
   currentEndTime.hour = endHour;
   currentEndTime.min = endMinute;
   currentEndTime.sec = 0;
   //set the values of the start and end time instance variables
   _startTime = StructToTime(currentStartTime);
   _endTime = StructToTime(currentEndTime);
   //handle the possibility that start and end times span midnight
   if(_endTime <= _startTime)
      _endTime += TIME_ADD_DAY;
   //set the use local time instance variable
   _useLocalTime = useLocalTime;   
}

//constructor for use for any time span
Timer::Timer(datetime startTime,datetime endTime,bool useLocalTime=false){
   //sanity check swaps start and end times if start < end
   if(startTime < endTime){
      _startTime = endTime;
      _endTime = startTime;
   }else{
      _startTime = startTime;
      _endTime = endTime;
   }
   _useLocalTime = useLocalTime;
}

bool Timer::CheckTimer(datetime startTime,datetime endTime,bool useLocalTime=false){
   //sanity check
   if(startTime >= endTime){
      Alert("CheckTimer: Invalid start or end time!");
      return false;
   }
   datetime currentTime;
   if(useLocalTime == true)
      currentTime = TimeLocal();
   else
      currentTime = TimeCurrent();
   if(currentTime >= startTime && currentTime < endTime)
      return true;
   else
      return false;
}

bool Timer::DailyTimer(void){
   datetime currentTime;
   if(_useLocalTime == true)
      currentTime = TimeLocal();
   else
      currentTime = TimeCurrent();
   //move the start end end times to the next day, if necessary
   if(currentTime > _endTime){
      _startTime += TIME_ADD_DAY;
      _endTime += TIME_ADD_DAY;
   }
   //check to see if we are in the timer window
   if(currentTime >= _startTime && currentTime < _endTime)
      return true;
   else
      return false;
}

datetime Timer::GetStartTime(void){
   return _startTime;
}

datetime Timer::GetEndTime(void){
   return _endTime;
}

bool Timer::GetUseLocalTime(void){
   return _useLocalTime;
}

