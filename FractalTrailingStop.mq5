#include <Trade\Trade.mqh>
CTrade trade;
#include <Trade\AccountInfo.mqh>
CAccountInfo accountInfo;
#include <Steve\Direction_Fractal_H1H4.mqh>


int upFracIndex=0, downFracIndex=0, H4UpFracIndex=0, H4DownFracIndex=0;
double upFractal, currentUpFractal, H4UpFractal, currentH4UpFractal;
double downFractal, currentDownFractal, H4DownFractal, currentH4DownFractal;
double lotSize, orderPrice;
bool positions = false, pendingTrendOrders = false, pendingCounterTrendOrders = false;
string position = "FLAT", resultDesc = trade.ResultRetcodeDescription(), currentDirection;
double resultCode = trade.ResultRetcode();

input double   risk = .001; //Amount of Account Equity to risk on trades
input double   highPointsPad = 30;
input double   lowPointsPad = 20;

void OnInit()
   {
   currentUpFractal = GetUpFractal(); // get the most recent up fractal
   upFracIndex = GetUpFractalIndex();
   currentDownFractal = GetDownFractal(); // get the most recent down fractal
   //currentDownFractal = 0;
   downFracIndex = GetDownFractalIndex();
   currentDirection = GetDirection();
   //Print(currentUpFractal, " ", currentDownFractal, " ",positions, " ",pendingTrendOrders);
   //Print("UFI: ", upFracIndex, " DFI: ", downFracIndex);
   PrintComment();
   //Print(positions," ",pendingTrendOrders," ",pendingCounterTrendOrders);
   }
//void DebugBreak();
void OnTick()
   {  // ***Do we have any open positions?***
   if (PositionsTotal() == 0) positions = false; position = "FLAT";  
   for (int i = 0; i<PositionsTotal(); i++)
      {
      if (PositionGetSymbol(i) == Symbol()) //yes, we have open position(s)
         {
         positions = true;
         // Are we long or short?         
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) // If we're long, get the ticket number and current stoploss
            {
            //Print(_Point);
            ResetLastError();
            position = "LONG";
            ulong ticket = PositionGetTicket(i);
            double currentStopLoss = PositionGetDouble(POSITION_SL);            
            //upFractal = GetUpFractal(); // get the latest up fractal
            downFractal = GetDownFractal(); // get the latest down fractal          
            if (MathRound((downFractal-Point()*lowPointsPad)/Point()) != MathRound(currentStopLoss/Point()))// || PositionGetDouble(POSITION_SL) == 0.0) // Modify stop loss if the Down Fractal has changed
               {
               //Print(downFractal- _Point * lowPointsPad," ",currentStopLoss);
               if(!trade.PositionModify(ticket, downFractal-Point()*lowPointsPad, 0.00))
                  {
                  Print("PositionModify failed. Result Code: ",resultCode," ",resultDesc);
                  //currentDownFractal = downFractal;
                  }
               else
                  {
                  Print("PositionModify successful. Result Code: ", resultCode," ",resultDesc);
                  currentDownFractal = downFractal;
                  }
               }
            PrintComment();
            }
         else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) // If we're short, get the ticket number and current stoploss
            {
            double currentStopLoss = PositionGetDouble(POSITION_SL); 
            //Print(MathRound((upFractal+_Point*highPointsPad)/Point())," ",MathRound(currentStopLoss/Point()));
            ResetLastError();
            position = "SHORT";            
            ulong ticket = PositionGetTicket(i);
            //double currentStopLoss = PositionGetDouble(POSITION_SL);                   
            //downFractal = GetDownFractal(); // get the latest down fractal
            upFractal = GetUpFractal();  // Get the latest up fractal             
            if (MathRound((upFractal+Point()*highPointsPad)/Point()) != MathRound(currentStopLoss/Point()) || PositionGetDouble(POSITION_SL) == 0.0) // Modify stop loss if it has changed
               {
               if(!trade.PositionModify(ticket, upFractal+Point()*highPointsPad, 0.00))
                  {
                  Print("PositionModify failed. Result Code: ",resultCode," ",resultDesc);
                  }
               else
                  {
                  Print("PositionModify successful. Result Code: ", resultCode," ",resultDesc);
                  currentUpFractal = upFractal;
                  }                  
               }
            PrintComment();
            }         
         }
      }        
   // ***Do we have any pending orders?***
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   CopyRates(Symbol(),PERIOD_CURRENT,0,1,rates);
   if (OrdersTotal() == 0) pendingTrendOrders = false; pendingCounterTrendOrders = false;
   for(int i = 0; i < OrdersTotal(); i++)
      {
      ulong ticket = OrderGetTicket(i);         
      if(OrderGetString(ORDER_SYMBOL) == Symbol())        
         {
         if(currentDirection == "UP" && OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP)
            {
            ResetLastError();
            pendingTrendOrders = true;               
            downFractal = GetDownFractal();
            upFractal = GetUpFractal();
            if(upFractal != currentUpFractal || downFractal != currentDownFractal || rates[0].low < downFractal)
               {
               if(!trade.OrderDelete(ticket))
                  {
                  Print("OrderDelete failed. Result Code: ",resultCode," ",resultDesc);
                  }
               else
                  {
                  Print("OrderDelete successful. Result Code: ", resultCode," ",resultDesc);
                  currentUpFractal = upFractal;
                  currentDownFractal = downFractal;
                  }
               CreateTrendOrder();
               PrintComment();
               }
            }
         else if(currentDirection == "DOWN" && OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_STOP)
            {
            ResetLastError();
            pendingTrendOrders = true;
            downFractal = GetDownFractal();
            upFractal = GetUpFractal();
            if(upFractal != currentUpFractal || downFractal != currentDownFractal || rates[0].high > upFractal)
               {
               if(!trade.OrderDelete(ticket))
                  {
                  Print("OrderDelete failed. Result Code: ",resultCode," ",resultDesc);
                  }
               else
                  {
                  Print("OrderDelete successful. Result Code: ", resultCode," ",resultDesc);
                  currentUpFractal = upFractal;
                  currentDownFractal = downFractal;
                  }
               CreateTrendOrder();
               PrintComment();
               }
            }
         }
      }
      
   if(positions == false && pendingTrendOrders == false)
      {
      ResetLastError();
      CreateTrendOrder();
      PrintComment();
      }
      
   //if(pendingCounterTrendOrders == false)
   //   {
   //   ResetLastError();
   //   //CreateCounterTrendOrder();
   //   PrintComment();
   //   }      
   } // End of OnTick function
   
//***FUNCTIONS***
//GetUpFractal
//GetUpFractalIndex
//GetDownFractal
//GetDownFractalIndex
//GetH4UpFractal
//GetH4DownFractal
//PrintComment
//CreateTrendOrder
//GetLotSize
   
double GetUpFractal() // This is the Up Fractal for the current timeframe
   { // Create data table to store fractal values
   double upFractalData[];
   int fractalHandle;
   ArraySetAsSeries(upFractalData,true); // Create dynamic array to hold up fractal values       
   fractalHandle = iFractals(_Symbol, _Period);
   int numberOfUpFractalData = CopyBuffer(fractalHandle, 0, 0, 100, upFractalData);     
   for(int i=3; i<=99; i++) // Get the first Up Fractal
      {
      if(upFractalData[i] != EMPTY_VALUE)
         {
         upFractal = upFractalData[i];
         break;
         }
      }       
   return(upFractal);
   }

int GetUpFractalIndex() // This is the Up Fractal for the current timeframe
   { // Create data table to store fractal values
   int index = 0;
   double upFractalData[];
   int fractalHandle;
   ArraySetAsSeries(upFractalData,true); // Create dynamic array to hold up fractal values       
   fractalHandle = iFractals(_Symbol, _Period);
   int numberOfUpFractalData = CopyBuffer(fractalHandle, 0, 0, 100, upFractalData);     
   for(int i=3; i<=99; i++) // Get the first Up Fractal
      {
      if(upFractalData[i] != EMPTY_VALUE)
         {
         index = i;
         break;
         }
      }       
   return(index);
   }
   
double GetDownFractal() // This is the Down Fractal for the current timeframe
   { // Create data table to store fractal values
   double downFractalData[];
   int fractalHandle;
   ArraySetAsSeries(downFractalData, true); // Create dynamic array to hold down fractal values
   fractalHandle = iFractals(_Symbol, _Period);
   int numberOfDownFractalData = CopyBuffer(fractalHandle, 1, 0, 100,downFractalData);
   for(int i=3; i<=99; i++) // Get the first Down Fractal
      {
      if(downFractalData[i] != EMPTY_VALUE)
         {
         downFractal = downFractalData[i];
         break;
         }
      }       
   return(downFractal);
   }

int GetDownFractalIndex() // This is the Down Fractal for the current timeframe
   { // Create data table to store fractal values
   int index = 3;
   double downFractalData[];
   int fractalHandle;
   ArraySetAsSeries(downFractalData, true); // Create dynamic array to hold down fractal values
   fractalHandle = iFractals(_Symbol, _Period);
   int numberOfDownFractalData = CopyBuffer(fractalHandle, 1, 0, 100,downFractalData);
   for(int i=3; i<=99; i++) // Get the first Down Fractal
      {
      if(downFractalData[i] != EMPTY_VALUE)
         {
         index = i;
         break;
         }
      }       
   return(index);
   }
   
double GetH4UpFractal() // This is the Up Fractal for the H4 timeframe
   { // Create data table to store fractal values
   double upFractalData[];
   int fractalHandle;
   ArraySetAsSeries(upFractalData,true); // Create dynamic array to hold up fractal values       
   fractalHandle = iFractals(_Symbol, PERIOD_H4);
   int numberOfUpFractalData = CopyBuffer(fractalHandle, 0, 0, 100, upFractalData);     
   for(int i=3; i<=99; i++) // Get the first Up Fractal
      {
      if(upFractalData[i] != EMPTY_VALUE)
         {
         upFractal = upFractalData[i];
         break;
         }
      }       
   return(upFractal);
   }
   
int GetH4UpFractalIndex() // This is the Up Fractal for the current timeframe
   { // Create data table to store fractal values
   int index = 0;
   double upFractalData[];
   int fractalHandle;
   ArraySetAsSeries(upFractalData,true); // Create dynamic array to hold up fractal values       
   fractalHandle = iFractals(_Symbol, _Period);
   int numberOfUpFractalData = CopyBuffer(fractalHandle, 0, 0, 100, upFractalData);     
   for(int i=3; i<=99; i++) // Get the first Up Fractal
      {
      if(upFractalData[i] != EMPTY_VALUE)
         {
         index = i;
         break;
         }
      }       
   return(index);
   }

double GetH4DownFractal() // This is the Down Fractal for the H4 timeframe
   { // Create data table to store fractal values
   double downFractalData[];
   int fractalHandle;
   ArraySetAsSeries(downFractalData, true); // Create dynamic array to hold down fractal values
   fractalHandle = iFractals(_Symbol, PERIOD_H4);
   int numberOfDownFractalData = CopyBuffer(fractalHandle, 1, 0, 100,downFractalData);
   for(int i=3; i<=99; i++) // Get the first Down Fractal
      {
      if(downFractalData[i] != EMPTY_VALUE)
         {
         downFractal = downFractalData[i];
         break;
         }
      }       
   return(downFractal);
   }

void PrintComment()
   {
   Comment ("H4 Trend: ", GetDirection(),
            "\nPosition: ", position,             
            "\nLot Size: ", GetLotSize(upFractal, downFractal),
            "\nBuy Price: ",upFractal+_Point*highPointsPad,
            "\nSell Price: ", downFractal-_Point*lowPointsPad,
            "\nTick Value: ", NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE),4));   
   }
   
void CreateTrendOrder()
   {
   double Ask = SymbolInfoDouble(Symbol(),SYMBOL_ASK), Bid = SymbolInfoDouble(Symbol(),SYMBOL_BID), price;
   string direction = GetDirection();
   double high[], low[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   upFractal = GetUpFractal();
   upFracIndex = GetUpFractalIndex();
   downFractal = GetDownFractal();
   downFracIndex = GetDownFractalIndex();
   CopyHigh(Symbol(),PERIOD_CURRENT,0,upFracIndex,high);
   CopyLow(Symbol(),PERIOD_CURRENT,0,downFracIndex,low);
   lotSize = GetLotSize(upFractal, downFractal);
   if(direction == "UP" && Ask < upFractal && Ask > downFractal 
      && low[ArrayMinimum(low,0,downFracIndex)] > downFractal && high[ArrayMaximum(high,0,upFracIndex)] < upFractal)
      {
      price = upFractal+_Point*highPointsPad;
      if(!trade.BuyStop(lotSize,price,Symbol(),0,0,0,0,NULL))
         {
         //--- failure message         
         Print("BuyStop method failed. Return code: ",GetLastError()," ",resultDesc);
         }
      else
         {         
         Print("BuyStop method executed successfully. Return code: ",resultCode," ",resultDesc);
         pendingTrendOrders = true;
         }
      }
   else if(direction == "DOWN" && Bid < upFractal && Bid > downFractal 
      && low[ArrayMinimum(low,0,downFracIndex)] > downFractal && high[ArrayMaximum(high,0,upFracIndex)] < upFractal)
      {
      price = downFractal-_Point*lowPointsPad;
      if(!trade.SellStop(lotSize,price,Symbol(),0,0,0,0,NULL))
         {
         //--- failure message
         Print("SellStop method failed. Return code: ",resultCode,
         " Result Description: ",resultDesc);
         }
      else
         {
         Print("SellStop method executed successfully. Return code: ",resultCode," ",resultDesc);
         pendingTrendOrders = true;
         }
      }
   }

void CreateCounterTrendOrder()
   {
   double Ask = SymbolInfoDouble(Symbol(),SYMBOL_ASK), Bid = SymbolInfoDouble(Symbol(),SYMBOL_BID), price;
   string direction = GetDirection();
   double high[], low[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   upFractal = GetUpFractal();
   upFracIndex = GetUpFractalIndex();
   H4UpFractal = GetH4UpFractal();
   //H4UpFracIndex = Get
   downFractal = GetDownFractal();
   H4DownFractal = GetH4DownFractal();
   CopyHigh(Symbol(),PERIOD_CURRENT,0,upFracIndex,high);
   CopyLow(Symbol(),PERIOD_CURRENT,0,downFracIndex,low);   
   if(direction == "UP" && Bid < upFractal && Bid > H4DownFractal)
      {
      lotSize = GetLotSize(upFractal, H4DownFractal);
      price = H4DownFractal-_Point*lowPointsPad;
      if(!trade.SellStop(lotSize,price,Symbol(),0,0,0,0,NULL))
         {
         //--- failure message         
         Print("SellStop method failed. Return code: ",GetLastError()," ",resultDesc);
         //Print(direction, " ", Symbol()," ",lotSize," ",price);
         }
      else
         {         
         Print("SellStop method executed successfully. Return code: ",resultCode," ",resultDesc);
         pendingCounterTrendOrders = true;
         }
      }
   else if(direction == "DOWN" && Ask < H4UpFractal && Ask > downFractal)
      {
      lotSize = GetLotSize(H4UpFractal, downFractal);
      price = H4UpFractal+_Point*highPointsPad;
      if(!trade.BuyStop(lotSize,price,Symbol(),0,0,0,0,NULL))
         {
         //--- failure message
         Print("BuyStop method failed. Return code: ",resultCode,
         " Result Description: ",resultDesc);
         }
      else
         {
         Print("BuyStop method executed successfully. Return code: ",resultCode," ",resultDesc);
         pendingCounterTrendOrders = true;
         }
      }
   }
      
double GetLotSize(double buyPrice, double sellPrice)
   {
   Sleep(1000);
   //Print(buyPrice," ",sellPrice);
   lotSize = NormalizeDouble((accountInfo.Equity()*risk)/((buyPrice+_Point*highPointsPad)-(sellPrice-_Point*lowPointsPad))/MathPow(10,_Digits),2);
   return lotSize;
   }