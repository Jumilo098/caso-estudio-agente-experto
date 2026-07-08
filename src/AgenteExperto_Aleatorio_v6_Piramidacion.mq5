//+------------------------------------------------------------------+
//|                 AgenteExperto_Aleatorio_v6_Piramidacion.mq5      |
//|                          Instituto Quant - Agente Experto        |
//|                                                                  |
//|  VERSION 6 (v6_Piramidacion) - anadir a la ganadora:             |
//|   - Abre una posicion BASE con direccion al azar, lote 0.01,     |
//|     SL 1% del precio de entrada, sin TP.                         |
//|   - Cada vez que el precio avanza PasoPorc% A FAVOR desde la     |
//|     ultima entrada, PIRAMIDA: abre otra posicion igual en la     |
//|     misma direccion (hasta MaxNiveles posiciones en total).      |
//|   - Cada posicion lleva su propio SL al 1% de SU entrada; el     |
//|     ciclo termina cuando el mercado va cerrando los SL.          |
//|   - Cuando no queda ninguna posicion, empieza un ciclo nuevo     |
//|     con direccion aleatoria otra vez.                            |
//|                                                                  |
//|  La v7 generaliza esta idea con niveles, escalado de lote y      |
//|  trailing comun configurables.                                   |
//+------------------------------------------------------------------+
#property copyright "Instituto Quant"
#property version   "6.00"
#property description "v6: entrada al azar + piramidacion a favor (niveles fijos)"

#include <Trade\Trade.mqh>

//--- Parametros configurables
input double LoteFijo        = 0.01;        // Lote de cada nivel
input double SLPorc          = 1.0;         // SL de cada posicion (% de su entrada)
input double PasoPorc        = 0.5;         // Avance a favor para piramidar (%)
input int    MaxNiveles      = 3;           // Maximo de posiciones simultaneas del ciclo
input long   NumeroMagico    = 2026070806;  // Magico: fecha AAAAMMDD + nn de version
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
   int semilla = (SemillaAleatoria != 0) ? SemillaAleatoria
                                         : (int)(GetTickCount() + TimeLocal());
   MathSrand(semilla);

   trade.SetExpertMagicNumber(NumeroMagico);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.SetDeviationInPoints(50);

   archivoEstado = "AEv6_estado_" + _Symbol + ".txt";
   EventSetTimer(5);

   Print("v6 Piramidacion iniciado en ", _Symbol,
         " | paso=", DoubleToString(PasoPorc, 2), "%",
         " | niveles max=", MaxNiveles,
         " | semilla=", semilla);
   EscribirEstado("iniciado");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) { EventKillTimer(); }

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
   FileWriteString(h, "posiciones_propias=" + (string)ContarPosiciones() + "\r\n");
   FileWriteString(h, "detalle=" + detalle + "\r\n");
   FileClose(h);
}

//+------------------------------------------------------------------+
//| Cuenta las posiciones propias (simbolo + magico)                 |
//+------------------------------------------------------------------+
int ContarPosiciones()
{
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == NumeroMagico)
         n++;
   }
   return(n);
}

//+------------------------------------------------------------------+
//| Direccion del ciclo actual y entrada mas avanzada                |
//| Devuelve false si no hay posiciones propias                      |
//+------------------------------------------------------------------+
bool EstadoCiclo(bool &esCompra, double &entradaExtrema)
{
   bool hay = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         PositionGetInteger(POSITION_MAGIC) != NumeroMagico)
         continue;

      bool   tipoCompra = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      double entrada    = PositionGetDouble(POSITION_PRICE_OPEN);

      if(!hay)
      {
         esCompra = tipoCompra;
         entradaExtrema = entrada;
         hay = true;
      }
      else
      {
         // La entrada "extrema" es la mas avanzada a favor del ciclo:
         // la mas alta en compras, la mas baja en ventas
         if(esCompra && entrada > entradaExtrema)  entradaExtrema = entrada;
         if(!esCompra && entrada < entradaExtrema) entradaExtrema = entrada;
      }
   }
   return(hay);
}

//+------------------------------------------------------------------+
//| Nucleo: sin posiciones -> ciclo nuevo; con ellas -> piramidar    |
//+------------------------------------------------------------------+
void Gestionar()
{
   if(TimeCurrent() - ultimoIntento < EsperaReintento) return;

   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
   {
      EscribirEstado("bloqueado: sin permiso de trading");
      return;
   }

   bool   esCompra;
   double entradaExtrema;

   if(!EstadoCiclo(esCompra, entradaExtrema))
   {
      // Ciclo nuevo: direccion al azar
      ultimoIntento = TimeCurrent();
      bool compra = (MathRand() % 2 == 0);
      AbrirNivel(compra, "v6 base");
      return;
   }

   // Ya hay ciclo: piramidamos si el precio avanzo el paso a favor
   if(ContarPosiciones() >= MaxNiveles) return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0) return;

   double disparo = esCompra ? entradaExtrema * (1.0 + PasoPorc / 100.0)
                             : entradaExtrema * (1.0 - PasoPorc / 100.0);

   bool toca = esCompra ? (ask >= disparo) : (bid <= disparo);
   if(toca)
   {
      ultimoIntento = TimeCurrent();
      AbrirNivel(esCompra, "v6 piramide");
   }
}

void OnTick()  { Gestionar(); }
void OnTimer() { Gestionar(); EscribirEstado("ciclo timer"); }

//+------------------------------------------------------------------+
//| Abre un nivel (base o piramide) con SL % de su propia entrada    |
//+------------------------------------------------------------------+
void AbrirNivel(bool esCompra, string etiqueta)
{
   double lote = (LoteFijo > 0.01) ? 0.01 : LoteFijo;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0) return;

   double precio = esCompra ? ask : bid;
   double sl = esCompra ? precio * (1.0 - SLPorc / 100.0)
                        : precio * (1.0 + SLPorc / 100.0);
   sl = NormalizeDouble(sl, _Digits);

   bool ok = esCompra ? trade.Buy(lote, _Symbol, 0.0, sl, 0.0, etiqueta)
                      : trade.Sell(lote, _Symbol, 0.0, sl, 0.0, etiqueta);

   if(ok && trade.ResultRetcode() == TRADE_RETCODE_DONE)
      Print(etiqueta, ": ", (esCompra ? "COMPRA" : "VENTA"), " @ ",
            DoubleToString(trade.ResultPrice(), _Digits),
            " | SL=", DoubleToString(sl, _Digits),
            " | nivel ", ContarPosiciones(), "/", MaxNiveles);
   else
      EscribirEstado("fallo retcode=" + (string)trade.ResultRetcode() +
                     " " + trade.ResultRetcodeDescription());
}
//+------------------------------------------------------------------+
