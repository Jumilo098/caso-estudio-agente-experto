# Plantilla de EA con los patrones validados

Esqueleto basado en la v4 (funcionando en demo desde 2026-07-07). Incorpora:
timer + tick, filtro magic+símbolo, throttle de reintentos, verificación de
permisos y archivo de estado observable. Copiar y adaptar la lógica de entrada.

```mql5
//+------------------------------------------------------------------+
//| AgenteExperto_Aleatorio_vN_<Rasgo>.mq5  -  Instituto Quant       |
//+------------------------------------------------------------------+
#property copyright "Instituto Quant"
#property version   "N.00"

#include <Trade\Trade.mqh>

input double LoteFijo        = 0.01;
input double StopLossPorc    = 1.0;       // % del precio de entrada
input long   NumeroMagico    = 20260704;  // convencion: fecha AAAAMMDD
input int    EsperaReintento = 5;         // seg. entre reintentos

CTrade   trade;
datetime ultimoIntento = 0;
string   archivoEstado;

int OnInit()
{
   MathSrand((int)(GetTickCount() + TimeLocal()));
   trade.SetExpertMagicNumber(NumeroMagico);
   trade.SetTypeFillingBySymbol(_Symbol);   // Exness: FOK/IOC segun simbolo
   trade.SetDeviationInPoints(50);
   archivoEstado = "AEvN_estado_" + _Symbol + ".txt";
   EventSetTimer(5);                        // latido independiente de ticks
   EscribirEstado("iniciado");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) { EventKillTimer(); }

// Observabilidad externa: MQL5\Files\<archivoEstado> (los logs se buffean)
void EscribirEstado(string detalle)
{
   int h = FileOpen(archivoEstado, FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(h == INVALID_HANDLE) return;
   FileWriteString(h, "hora_servidor=" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\r\n");
   FileWriteString(h, "terminal_trade_allowed=" + (string)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) + "\r\n");
   FileWriteString(h, "mql_trade_allowed=" + (string)MQLInfoInteger(MQL_TRADE_ALLOWED) + "\r\n");
   FileWriteString(h, "posicion_propia=" + (string)TienePosicionAbierta() + "\r\n");
   FileWriteString(h, "detalle=" + detalle + "\r\n");
   FileClose(h);
}

// Cuenta hedging: SIEMPRE filtrar por simbolo + magic
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

void Gestionar()
{
   if(TienePosicionAbierta()) return;
   if(TimeCurrent() - ultimoIntento < EsperaReintento) return;  // throttle
   ultimoIntento = TimeCurrent();

   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
   {
      EscribirEstado("bloqueado: sin permiso de trading");
      return;
   }
   AbrirPosicion();   // <-- logica de entrada de la version
}

void OnTick()  { Gestionar(); }
void OnTimer() { Gestionar(); EscribirEstado("ciclo timer"); }

// Ejemplo v4: direccion aleatoria, SL % del precio, sin TP
void AbrirPosicion()
{
   bool esCompra = (MathRand() % 2 == 0);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0) return;

   double precio = esCompra ? ask : bid;
   double sl = esCompra ? precio * (1.0 - StopLossPorc / 100.0)
                        : precio * (1.0 + StopLossPorc / 100.0);
   sl = NormalizeDouble(sl, _Digits);

   bool ok = esCompra ? trade.Buy(LoteFijo, _Symbol, 0.0, sl, 0.0, "vN compra")
                      : trade.Sell(LoteFijo, _Symbol, 0.0, sl, 0.0, "vN venta");

   if(ok && trade.ResultRetcode() == TRADE_RETCODE_DONE)
      Print("Abierta ", (esCompra ? "COMPRA" : "VENTA"), " @ ",
            DoubleToString(trade.ResultPrice(), _Digits));
   else
      EscribirEstado("fallo retcode=" + (string)trade.ResultRetcode() +
                     " " + trade.ResultRetcodeDescription());
}
//+------------------------------------------------------------------+
```

Notas:
- Sin acentos en el codigo (encoding).
- El nombre del archivo de estado debe ser unico por version/simbolo.
- Si la version gestiona salidas (trailing, TP), documentar el criterio aqui.
