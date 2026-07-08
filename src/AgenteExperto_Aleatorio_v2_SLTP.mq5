//+------------------------------------------------------------------+
//|                          AgenteExperto_Aleatorio_v2_SLTP.mq5     |
//|                          Instituto Quant - Agente Experto        |
//|                                                                  |
//|  VERSION 2 (v2_SLTP) - gestion de riesgo fija:                   |
//|   - Abre UNA operacion de compra o venta de forma ALEATORIA.     |
//|   - Mantiene SIEMPRE una sola posicion abierta a la vez.         |
//|   - Lote FIJO de 0.01 (no se puede aumentar por diseno).         |
//|   - Stop Loss   = 1% del tamano de la cuenta (saldo).            |
//|   - Take Profit = 2% del tamano de la cuenta (saldo).            |
//|                                                                  |
//|  Revision 2.10 (2026-07-07): reescrita con los patrones          |
//|  validados del proyecto (ver docs/PLANTILLA_EA.md):              |
//|   - OnTimer(5s) ademas de OnTick (no depende de ticks).          |
//|   - Archivo de estado observable en MQL5\Files.                  |
//|   - Throttle de reintentos si el servidor rechaza la orden.      |
//|   - Verificacion de retcode y de permisos de trading.            |
//|   - Semilla aleatoria configurable (backtests reproducibles).    |
//+------------------------------------------------------------------+
#property copyright "Instituto Quant"
#property version   "2.10"
#property description "v2: entrada al azar, 1 posicion, lote 0.01, SL 1% y TP 2% del saldo"

#include <Trade\Trade.mqh>

//--- Parametros configurables
input double LoteFijo        = 0.01;        // Lote fijo (maximo 0.01 por diseno)
input double RiesgoSL_Pct    = 1.0;         // Stop Loss en % del saldo
input double RiesgoTP_Pct    = 2.0;         // Take Profit en % del saldo
input long   NumeroMagico    = 2026070802;  // Magico: fecha AAAAMMDD + nn de version
input int    EsperaReintento = 5;           // Segundos entre reintentos
input int    SemillaAleatoria = 0;          // 0 = reloj (live); fijo = reproducible (tester)

//--- Objetos globales
CTrade   trade;
datetime ultimoIntento = 0;
string   archivoEstado;

//+------------------------------------------------------------------+
//| Inicializacion                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Semilla del generador aleatorio. Con SemillaAleatoria=0 usamos el
   // reloj (cada carga es distinta). Con un valor fijo, la secuencia de
   // direcciones se repite: asi los backtests son comparables entre si.
   int semilla = (SemillaAleatoria != 0) ? SemillaAleatoria
                                         : (int)(GetTickCount() + TimeLocal());
   MathSrand(semilla);

   trade.SetExpertMagicNumber(NumeroMagico);
   trade.SetTypeFillingBySymbol(_Symbol);   // Exness usa FOK/IOC segun simbolo
   trade.SetDeviationInPoints(50);

   archivoEstado = "AEv2_estado_" + _Symbol + ".txt";
   EventSetTimer(5);                        // latido independiente de los ticks

   Print("v2 SLTP iniciado en ", _Symbol,
         " | Lote=", DoubleToString(LoteFijo, 2),
         " | SL=", DoubleToString(RiesgoSL_Pct, 1), "% saldo",
         " | TP=", DoubleToString(RiesgoTP_Pct, 1), "% saldo",
         " | semilla=", semilla);
   EscribirEstado("iniciado");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) { EventKillTimer(); }

//+------------------------------------------------------------------+
//| Estado observable en MQL5\Files (los logs se buffean minutos)    |
//+------------------------------------------------------------------+
void EscribirEstado(string detalle)
{
   if(MQLInfoInteger(MQL_TESTER)) return;   // en el tester no hace falta y frena

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
//| Nucleo: si no hay posicion propia, abre una nueva                |
//+------------------------------------------------------------------+
void Gestionar()
{
   if(TienePosicionAbierta()) return;

   // Throttle: evita rafagas de reintentos si el servidor rechaza
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
//| Convierte un monto en dinero a distancia en precio               |
//| (cuanto debe moverse el precio para ganar/perder ese dinero)     |
//+------------------------------------------------------------------+
double DistanciaPorDinero(double dinero, double lote)
{
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickValue <= 0.0 || tickSize <= 0.0 || lote <= 0.0) return(0.0);

   // dineroPorUnidad = dinero que gana/pierde el lote si el precio se mueve 1.0
   double dineroPorUnidad = (tickValue / tickSize) * lote;
   if(dineroPorUnidad <= 0.0) return(0.0);
   return(dinero / dineroPorUnidad);
}

//+------------------------------------------------------------------+
//| Abre compra o venta al azar con SL 1% y TP 2% del saldo          |
//+------------------------------------------------------------------+
void AbrirPosicionAleatoria()
{
   // Lote fijo y protegido a 0.01 (regla didactica de la serie)
   double lote = (LoteFijo > 0.01) ? 0.01 : LoteFijo;

   // 1) Dinero a arriesgar (SL) y a buscar (TP) segun el saldo actual
   double saldo    = AccountInfoDouble(ACCOUNT_BALANCE);
   double dineroSL = saldo * (RiesgoSL_Pct / 100.0);
   double dineroTP = saldo * (RiesgoTP_Pct / 100.0);

   // 2) Convertimos el dinero a distancia en precio
   double distSL = DistanciaPorDinero(dineroSL, lote);
   double distTP = DistanciaPorDinero(dineroTP, lote);
   if(distSL <= 0.0 || distTP <= 0.0)
   {
      EscribirEstado("error: no se pudo calcular distancia SL/TP");
      return;
   }

   // 3) Direccion al azar: par = COMPRA, impar = VENTA
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
      ok = trade.Buy(lote, _Symbol, 0.0, sl, tp, "v2 compra");
   }
   else
   {
      sl = NormalizeDouble(bid + distSL, _Digits);
      tp = NormalizeDouble(bid - distTP, _Digits);
      ok = trade.Sell(lote, _Symbol, 0.0, sl, tp, "v2 venta");
   }

   if(ok && trade.ResultRetcode() == TRADE_RETCODE_DONE)
      Print("Abierta ", (esCompra ? "COMPRA" : "VENTA"), " @ ",
            DoubleToString(trade.ResultPrice(), _Digits),
            " | SL=", DoubleToString(sl, _Digits), " (", DoubleToString(dineroSL, 2), " USD)",
            " | TP=", DoubleToString(tp, _Digits), " (", DoubleToString(dineroTP, 2), " USD)");
   else
      EscribirEstado("fallo retcode=" + (string)trade.ResultRetcode() +
                     " " + trade.ResultRetcodeDescription());
}
//+------------------------------------------------------------------+
