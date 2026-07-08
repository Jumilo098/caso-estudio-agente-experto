//+------------------------------------------------------------------+
//|                       AgenteExperto_Aleatorio_v4_UnaPosicion.mq5 |
//|                                    Instituto Quant - Version 4   |
//|                                                                  |
//| Mantiene UNA sola posicion siempre abierta en el simbolo:        |
//|  - Direccion aleatoria (compra o venta)                          |
//|  - Lote fijo 0.01                                                |
//|  - Stop Loss fijo al 1% del precio de entrada                    |
//|  - Sin Take Profit                                               |
//| Cuando el SL cierra la posicion, abre una nueva de inmediato.    |
//+------------------------------------------------------------------+
#property copyright "Instituto Quant"
#property version   "4.00"
#property strict

#include <Trade\Trade.mqh>

//--- Parametros de entrada
input double LoteFijo       = 0.01;      // Tamano de lote
input double StopLossPorc   = 1.0;       // Stop Loss (% del precio de entrada)
input long   NumeroMagico   = 20260704;  // Numero magico
input int    EsperaReintento = 5;        // Segundos entre reintentos si falla la orden

//--- Objetos globales
CTrade   trade;
datetime ultimoIntento = 0;
string   archivoEstado;

//+------------------------------------------------------------------+
//| Inicializacion                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Semilla aleatoria distinta en cada carga del EA
   MathSrand((int)(GetTickCount() + TimeLocal()));

   trade.SetExpertMagicNumber(NumeroMagico);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.SetDeviationInPoints(50);

   archivoEstado = "AEv4_estado_" + _Symbol + ".txt";

   // Temporizador: la logica no depende de que lleguen ticks al grafico
   EventSetTimer(5);

   Print("v4 iniciado en ", _Symbol,
         " | Lote=", DoubleToString(LoteFijo, 2),
         " | SL=", DoubleToString(StopLossPorc, 2), "% del precio | Sin TP");
   EscribirEstado("iniciado");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
}

//+------------------------------------------------------------------+
//| Escribe estado observable en MQL5\Files (diagnostico externo)    |
//+------------------------------------------------------------------+
void EscribirEstado(string detalle)
{
   int h = FileOpen(archivoEstado, FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(h == INVALID_HANDLE)
      return;
   FileWriteString(h, "hora_servidor=" + TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS) + "\r\n");
   FileWriteString(h, "terminal_trade_allowed=" + (string)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) + "\r\n");
   FileWriteString(h, "mql_trade_allowed=" + (string)MQLInfoInteger(MQL_TRADE_ALLOWED) + "\r\n");
   FileWriteString(h, "posicion_propia=" + (string)TienePosicionAbierta() + "\r\n");
   FileWriteString(h, "detalle=" + detalle + "\r\n");
   FileClose(h);
}

//+------------------------------------------------------------------+
//| Nucleo: si no hay posicion propia abierta, abre una nueva        |
//+------------------------------------------------------------------+
void Gestionar()
{
   if(TienePosicionAbierta())
      return;

   // Evita disparar reintentos en rafaga si el servidor rechaza la orden
   if(TimeCurrent() - ultimoIntento < EsperaReintento)
      return;

   ultimoIntento = TimeCurrent();

   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
   {
      Print("Trading NO permitido (boton AlgoTrading o permiso del EA). Esperando...");
      EscribirEstado("bloqueado: sin permiso de trading");
      return;
   }

   AbrirPosicionAleatoria();
}

void OnTick()  { Gestionar(); }
void OnTimer() { Gestionar(); EscribirEstado("ciclo timer"); }

//+------------------------------------------------------------------+
//| Busca una posicion de ESTE robot (simbolo + magico)              |
//+------------------------------------------------------------------+
bool TienePosicionAbierta()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == NumeroMagico)
         return(true);
   }
   return(false);
}

//+------------------------------------------------------------------+
//| Abre compra o venta al azar con SL al 1% y sin TP                |
//+------------------------------------------------------------------+
void AbrirPosicionAleatoria()
{
   bool esCompra = (MathRand() % 2 == 0);

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return;

   double precio = esCompra ? ask : bid;
   double sl     = esCompra ? precio * (1.0 - StopLossPorc / 100.0)
                            : precio * (1.0 + StopLossPorc / 100.0);
   sl = NormalizeDouble(sl, _Digits);

   bool ok;
   if(esCompra)
      ok = trade.Buy(LoteFijo, _Symbol, 0.0, sl, 0.0, "v4 aleatorio compra");
   else
      ok = trade.Sell(LoteFijo, _Symbol, 0.0, sl, 0.0, "v4 aleatorio venta");

   if(ok && trade.ResultRetcode() == TRADE_RETCODE_DONE)
      Print("Posicion abierta: ", (esCompra ? "COMPRA" : "VENTA"),
            " ", DoubleToString(LoteFijo, 2), " lotes @ ",
            DoubleToString(trade.ResultPrice(), _Digits),
            " | SL=", DoubleToString(sl, _Digits));
   else
      Print("Fallo al abrir (", (esCompra ? "compra" : "venta"), "): retcode=",
            trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription(),
            ". Reintento en ", EsperaReintento, "s");
}
//+------------------------------------------------------------------+
