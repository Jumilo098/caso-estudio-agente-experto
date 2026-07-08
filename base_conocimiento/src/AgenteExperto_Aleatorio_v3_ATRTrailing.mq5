//+------------------------------------------------------------------+
//|                   AgenteExperto_Aleatorio_v3_ATRTrailing.mq5     |
//|                          Instituto Quant - Agente Experto        |
//|                                                                  |
//|  VERSION 3 (v3_ATRTrailing) - salida dinamica con trailing:      |
//|   - Igual que la v2 (entrada al azar, 1 posicion, lote 0.01,     |
//|     SL inicial 1% del saldo, TP 2% del saldo)...                 |
//|   - ...pero el Stop Loss PERSIGUE al precio a una distancia de   |
//|     ATR x multiplicador, solo a favor (nunca retrocede).         |
//|                                                                  |
//|  Revision 3.10 (2026-07-07): reescrita con los patrones          |
//|  validados del proyecto (ver docs/PLANTILLA_EA.md):              |
//|   - OnTimer(5s) ademas de OnTick; el trailing tambien late ahi.  |
//|   - Archivo de estado observable, throttle, retcode, semilla.    |
//|   - Paso minimo de mejora para no bombardear al servidor con     |
//|     modificaciones de SL microscopicas.                          |
//+------------------------------------------------------------------+
#property copyright "Instituto Quant"
#property version   "3.10"
#property description "v3: entrada al azar, SL 1%/TP 2% del saldo, trailing stop con ATR"

#include <Trade\Trade.mqh>

//--- Parametros configurables
input double LoteFijo        = 0.01;        // Lote fijo (maximo 0.01 por diseno)
input double RiesgoSL_Pct    = 1.0;         // Stop Loss inicial en % del saldo
input double RiesgoTP_Pct    = 2.0;         // Take Profit en % del saldo
input int    ATRPeriodo      = 14;          // Periodo del ATR
input double ATRMultiplo     = 2.0;         // Distancia del trailing = ATR x este factor
input int    MejoraMinPuntos = 100;         // Solo mover SL si mejora al menos estos puntos
input long   NumeroMagico    = 2026070803;  // Magico: fecha AAAAMMDD + nn de version
input int    EsperaReintento = 5;           // Segundos entre reintentos
input int    SemillaAleatoria = 0;          // 0 = reloj (live); fijo = reproducible (tester)

//--- Objetos globales
CTrade   trade;
datetime ultimoIntento = 0;
string   archivoEstado;
int      handleATR = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Inicializacion                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   int semilla = (SemillaAleatoria != 0) ? SemillaAleatoria
                                         : (int)(GetTickCount() + TimeLocal());
   MathSrand(semilla);

   trade.SetExpertMagicNumber(NumeroMagico);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.SetDeviationInPoints(50);

   // El indicador ATR se crea UNA sola vez (crearlo en cada tick es un
   // error clasico que agota memoria y frena el tester)
   handleATR = iATR(_Symbol, _Period, ATRPeriodo);
   if(handleATR == INVALID_HANDLE)
   {
      Print("No se pudo crear el ATR. El robot no se inicia.");
      return(INIT_FAILED);
   }

   archivoEstado = "AEv3_estado_" + _Symbol + ".txt";
   EventSetTimer(5);

   Print("v3 ATRTrailing iniciado en ", _Symbol,
         " | ATR(", ATRPeriodo, ") x ", DoubleToString(ATRMultiplo, 1),
         " | semilla=", semilla);
   EscribirEstado("iniciado");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   if(handleATR != INVALID_HANDLE) IndicatorRelease(handleATR);
}

//+------------------------------------------------------------------+
//| Estado observable en MQL5\Files                                  |
//+------------------------------------------------------------------+
void EscribirEstado(string detalle)
{
   if(MQLInfoInteger(MQL_TESTER)) return;

   int h = FileOpen(archivoEstado, FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(h == INVALID_HANDLE) return;
   FileWriteString(h, "hora_servidor=" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\r\n");
   FileWriteString(h, "terminal_trade_allowed=" + (string)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) + "\r\n");
   FileWriteString(h, "mql_trade_allowed=" + (string)MQLInfoInteger(MQL_TRADE_ALLOWED) + "\r\n");
   FileWriteString(h, "posicion_propia=" + (string)TienePosicionAbierta() + "\r\n");
   FileWriteString(h, "detalle=" + detalle + "\r\n");
   FileClose(h);
}

//+------------------------------------------------------------------+
//| Cuenta hedging: SIEMPRE filtrar por simbolo + magico             |
//+------------------------------------------------------------------+
bool TienePosicionAbierta()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == NumeroMagico)
         return(true);
   }
   return(false);
}

//+------------------------------------------------------------------+
//| Nucleo: con posicion -> trailing; sin posicion -> abrir          |
//+------------------------------------------------------------------+
void Gestionar()
{
   if(TienePosicionAbierta())
   {
      GestionarTrailingATR();
      return;
   }

   if(TimeCurrent() - ultimoIntento < EsperaReintento) return;
   ultimoIntento = TimeCurrent();

   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
   {
      EscribirEstado("bloqueado: sin permiso de trading");
      return;
   }
   AbrirPosicionAleatoria();
}

void OnTick()  { Gestionar(); }
void OnTimer() { Gestionar(); EscribirEstado("ciclo timer"); }

//+------------------------------------------------------------------+
//| Lee el ATR de la ultima vela cerrada                             |
//+------------------------------------------------------------------+
double ObtenerATR()
{
   double buffer[];
   if(CopyBuffer(handleATR, 0, 1, 1, buffer) <= 0) return(0.0);
   return(buffer[0]);
}

//+------------------------------------------------------------------+
//| Trailing: el SL persigue al precio a distancia ATR x multiplo    |
//+------------------------------------------------------------------+
void GestionarTrailingATR()
{
   double atr = ObtenerATR();
   if(atr <= 0.0) return;                    // sin dato de ATR todavia

   double distancia = atr * ATRMultiplo;
   double mejoraMin = MejoraMinPuntos * _Point;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         PositionGetInteger(POSITION_MAGIC) != NumeroMagico)
         continue;

      long   tipo     = PositionGetInteger(POSITION_TYPE);
      double slActual = PositionGetDouble(POSITION_SL);
      double tpActual = PositionGetDouble(POSITION_TP);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      if(tipo == POSITION_TYPE_BUY)
      {
         double nuevoSL = NormalizeDouble(bid - distancia, _Digits);
         // Solo a favor (arriba), con mejora minima, y sin cruzar el precio
         if(nuevoSL > slActual + mejoraMin && nuevoSL < bid)
            trade.PositionModify(ticket, nuevoSL, tpActual);
      }
      else if(tipo == POSITION_TYPE_SELL)
      {
         double nuevoSL = NormalizeDouble(ask + distancia, _Digits);
         // Solo a favor (abajo). Si no habia SL (0.0), cualquier SL valido mejora
         if((slActual == 0.0 || nuevoSL < slActual - mejoraMin) && nuevoSL > ask)
            trade.PositionModify(ticket, nuevoSL, tpActual);
      }
   }
}

//+------------------------------------------------------------------+
//| Convierte un monto en dinero a distancia en precio               |
//+------------------------------------------------------------------+
double DistanciaPorDinero(double dinero, double lote)
{
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickValue <= 0.0 || tickSize <= 0.0 || lote <= 0.0) return(0.0);
   double dineroPorUnidad = (tickValue / tickSize) * lote;
   if(dineroPorUnidad <= 0.0) return(0.0);
   return(dinero / dineroPorUnidad);
}

//+------------------------------------------------------------------+
//| Abre compra o venta al azar con SL 1% y TP 2% del saldo          |
//+------------------------------------------------------------------+
void AbrirPosicionAleatoria()
{
   double lote = (LoteFijo > 0.01) ? 0.01 : LoteFijo;

   double saldo    = AccountInfoDouble(ACCOUNT_BALANCE);
   double dineroSL = saldo * (RiesgoSL_Pct / 100.0);
   double dineroTP = saldo * (RiesgoTP_Pct / 100.0);

   double distSL = DistanciaPorDinero(dineroSL, lote);
   double distTP = DistanciaPorDinero(dineroTP, lote);
   if(distSL <= 0.0 || distTP <= 0.0)
   {
      EscribirEstado("error: no se pudo calcular distancia SL/TP");
      return;
   }

   bool esCompra = (MathRand() % 2 == 0);

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0) return;

   double sl, tp;
   bool ok;
   if(esCompra)
   {
      sl = NormalizeDouble(ask - distSL, _Digits);
      tp = NormalizeDouble(ask + distTP, _Digits);
      ok = trade.Buy(lote, _Symbol, 0.0, sl, tp, "v3 compra");
   }
   else
   {
      sl = NormalizeDouble(bid + distSL, _Digits);
      tp = NormalizeDouble(bid - distTP, _Digits);
      ok = trade.Sell(lote, _Symbol, 0.0, sl, tp, "v3 venta");
   }

   if(ok && trade.ResultRetcode() == TRADE_RETCODE_DONE)
      Print("Abierta ", (esCompra ? "COMPRA" : "VENTA"), " @ ",
            DoubleToString(trade.ResultPrice(), _Digits),
            " | SL=", DoubleToString(sl, _Digits),
            " | TP=", DoubleToString(tp, _Digits));
   else
      EscribirEstado("fallo retcode=" + (string)trade.ResultRetcode() +
                     " " + trade.ResultRetcodeDescription());
}
//+------------------------------------------------------------------+
