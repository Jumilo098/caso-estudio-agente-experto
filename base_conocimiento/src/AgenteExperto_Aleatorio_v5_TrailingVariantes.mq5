//+------------------------------------------------------------------+
//|              AgenteExperto_Aleatorio_v5_TrailingVariantes.mq5    |
//|                          Instituto Quant - Agente Experto        |
//|                                                                  |
//|  VERSION 5 (v5_TrailingVariantes) - laboratorio de trailings:    |
//|   - Entrada igual que la serie: direccion al azar, 1 posicion,   |
//|     lote fijo 0.01, SL inicial 1% del saldo.                     |
//|   - TP opcional (0 = sin TP, deja correr la ganancia).           |
//|   - El parametro ModoTrailing elige COMO persigue el SL:         |
//|       0 ATR        -> distancia = ATR x multiplo (como la v3)    |
//|       1 PORCENTAJE -> distancia = % fijo del precio actual       |
//|       2 MAXMIN     -> SL en el minimo/maximo de las N velas      |
//|                       previas (canal de Donchian)                |
//|       3 ESCALONADO -> a breakeven tras avanzar X% y luego sube   |
//|                       por escalones de Y% (asegura por tramos)   |
//|   - Pensada para comparar variantes en el Strategy Tester        |
//|     cambiando solo ModoTrailing.                                 |
//+------------------------------------------------------------------+
#property copyright "Instituto Quant"
#property version   "5.00"
#property description "v5: entrada al azar + 4 variantes de trailing stop seleccionables"

#include <Trade\Trade.mqh>

//--- Modos de trailing disponibles
enum MODO_TRAILING
{
   TRAILING_ATR        = 0,  // ATR x multiplo
   TRAILING_PORCENTAJE = 1,  // % fijo del precio
   TRAILING_MAXMIN     = 2,  // Minimo/maximo de N velas (Donchian)
   TRAILING_ESCALONADO = 3   // Breakeven + escalones de %
};

//--- Parametros configurables
input MODO_TRAILING ModoTrailing = TRAILING_ATR;  // Variante de trailing a usar
input double LoteFijo        = 0.01;        // Lote fijo (maximo 0.01 por diseno)
input double RiesgoSL_Pct    = 1.0;         // Stop Loss inicial en % del saldo
input double RiesgoTP_Pct    = 0.0;         // Take Profit en % del saldo (0 = sin TP)
//--- Parametros del modo ATR
input int    ATRPeriodo      = 14;          // ATR: periodo
input double ATRMultiplo     = 2.0;         // ATR: multiplo de distancia
//--- Parametros del modo PORCENTAJE
input double TrailPorc       = 1.0;         // PORCENTAJE: distancia en % del precio
//--- Parametros del modo MAXMIN
input int    MaxMinVelas     = 20;          // MAXMIN: velas del canal
//--- Parametros del modo ESCALONADO
input double BreakevenPorc   = 0.5;         // ESCALONADO: % de avance para breakeven
input double EscalonPorc     = 0.5;         // ESCALONADO: % de cada escalon posterior
//--- Comunes
input int    MejoraMinPuntos = 100;         // Solo mover SL si mejora al menos estos puntos
input long   NumeroMagico    = 2026070805;  // Magico: fecha AAAAMMDD + nn de version
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

   // El ATR solo hace falta en el modo 0, pero crearlo siempre simplifica
   // el codigo y su costo es despreciable
   handleATR = iATR(_Symbol, _Period, ATRPeriodo);
   if(handleATR == INVALID_HANDLE)
   {
      Print("No se pudo crear el ATR. El robot no se inicia.");
      return(INIT_FAILED);
   }

   archivoEstado = "AEv5_estado_" + _Symbol + ".txt";
   EventSetTimer(5);

   Print("v5 TrailingVariantes iniciado en ", _Symbol,
         " | modo=", EnumToString(ModoTrailing),
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
   FileWriteString(h, "modo_trailing=" + EnumToString(ModoTrailing) + "\r\n");
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
      GestionarTrailing();
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
//| Calcula el SL deseado por la variante activa                     |
//| Devuelve 0.0 si no hay dato suficiente para calcular             |
//+------------------------------------------------------------------+
double CalcularSLDeseado(bool esCompra, double entrada, double bid, double ask)
{
   double precio = esCompra ? bid : ask;   // precio de cierre potencial

   switch(ModoTrailing)
   {
      case TRAILING_ATR:
      {
         double atr = ObtenerATR();
         if(atr <= 0.0) return(0.0);
         double dist = atr * ATRMultiplo;
         return(esCompra ? precio - dist : precio + dist);
      }

      case TRAILING_PORCENTAJE:
      {
         double dist = precio * (TrailPorc / 100.0);
         return(esCompra ? precio - dist : precio + dist);
      }

      case TRAILING_MAXMIN:
      {
         // SL en el extremo de las N velas previas (canal de Donchian).
         // Empezamos en la vela 1 (la ultima cerrada) para no usar la vela
         // en formacion.
         int idxExtremo;
         if(esCompra)
         {
            idxExtremo = iLowest(_Symbol, _Period, MODE_LOW, MaxMinVelas, 1);
            if(idxExtremo < 0) return(0.0);
            return(iLow(_Symbol, _Period, idxExtremo));
         }
         else
         {
            idxExtremo = iHighest(_Symbol, _Period, MODE_HIGH, MaxMinVelas, 1);
            if(idxExtremo < 0) return(0.0);
            return(iHigh(_Symbol, _Period, idxExtremo));
         }
      }

      case TRAILING_ESCALONADO:
      {
         // Avance a favor en % desde la entrada
         double avancePorc = esCompra ? (precio - entrada) / entrada * 100.0
                                      : (entrada - precio) / entrada * 100.0;
         if(avancePorc < BreakevenPorc) return(0.0);   // aun no toca mover nada

         // n = cuantos escalones completos avanzo despues del breakeven
         int n = (int)MathFloor((avancePorc - BreakevenPorc) / EscalonPorc);

         // El SL asegura: breakeven en el escalon 0, y sube (n) escalones
         double aseguradoPorc = n * EscalonPorc;   // % asegurado sobre la entrada
         return(esCompra ? entrada * (1.0 + aseguradoPorc / 100.0)
                         : entrada * (1.0 - aseguradoPorc / 100.0));
      }
   }
   return(0.0);
}

//+------------------------------------------------------------------+
//| Aplica el trailing de la variante activa a la posicion propia    |
//+------------------------------------------------------------------+
void GestionarTrailing()
{
   double mejoraMin = MejoraMinPuntos * _Point;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         PositionGetInteger(POSITION_MAGIC) != NumeroMagico)
         continue;

      bool   esCompra = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      double entrada  = PositionGetDouble(POSITION_PRICE_OPEN);
      double slActual = PositionGetDouble(POSITION_SL);
      double tpActual = PositionGetDouble(POSITION_TP);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(bid <= 0.0 || ask <= 0.0) continue;

      double slDeseado = CalcularSLDeseado(esCompra, entrada, bid, ask);
      if(slDeseado <= 0.0) continue;
      slDeseado = NormalizeDouble(slDeseado, _Digits);

      if(esCompra)
      {
         // Solo a favor (arriba), con mejora minima, sin cruzar el precio
         if(slDeseado > slActual + mejoraMin && slDeseado < bid)
            trade.PositionModify(ticket, slDeseado, tpActual);
      }
      else
      {
         if((slActual == 0.0 || slDeseado < slActual - mejoraMin) && slDeseado > ask)
            trade.PositionModify(ticket, slDeseado, tpActual);
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
//| Abre compra o venta al azar con SL 1% del saldo (TP opcional)    |
//+------------------------------------------------------------------+
void AbrirPosicionAleatoria()
{
   double lote = (LoteFijo > 0.01) ? 0.01 : LoteFijo;

   double saldo    = AccountInfoDouble(ACCOUNT_BALANCE);
   double dineroSL = saldo * (RiesgoSL_Pct / 100.0);
   double distSL   = DistanciaPorDinero(dineroSL, lote);
   if(distSL <= 0.0)
   {
      EscribirEstado("error: no se pudo calcular distancia SL");
      return;
   }

   // TP opcional: con RiesgoTP_Pct=0 no se pone TP (la salida la maneja
   // el trailing, que es justamente lo que esta version estudia)
   double distTP = 0.0;
   if(RiesgoTP_Pct > 0.0)
      distTP = DistanciaPorDinero(saldo * (RiesgoTP_Pct / 100.0), lote);

   bool esCompra = (MathRand() % 2 == 0);

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0) return;

   double sl, tp = 0.0;
   bool ok;
   if(esCompra)
   {
      sl = NormalizeDouble(ask - distSL, _Digits);
      if(distTP > 0.0) tp = NormalizeDouble(ask + distTP, _Digits);
      ok = trade.Buy(lote, _Symbol, 0.0, sl, tp, "v5 compra");
   }
   else
   {
      sl = NormalizeDouble(bid + distSL, _Digits);
      if(distTP > 0.0) tp = NormalizeDouble(bid - distTP, _Digits);
      ok = trade.Sell(lote, _Symbol, 0.0, sl, tp, "v5 venta");
   }

   if(ok && trade.ResultRetcode() == TRADE_RETCODE_DONE)
      Print("Abierta ", (esCompra ? "COMPRA" : "VENTA"), " @ ",
            DoubleToString(trade.ResultPrice(), _Digits),
            " | SL=", DoubleToString(sl, _Digits),
            " | modo=", EnumToString(ModoTrailing));
   else
      EscribirEstado("fallo retcode=" + (string)trade.ResultRetcode() +
                     " " + trade.ResultRetcodeDescription());
}
//+------------------------------------------------------------------+
