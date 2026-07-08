//+------------------------------------------------------------------+
//|           AgenteExperto_Aleatorio_v7_PiramidacionNiveles.mq5     |
//|                          Instituto Quant - Agente Experto        |
//|                                                                  |
//|  VERSION 7 (v7_PiramidacionNiveles) - laboratorio de piramides:  |
//|  Generaliza la v6 para PROBAR configuraciones de piramidacion    |
//|  en el Strategy Tester (a mano o con optimizacion):              |
//|   - MaxNiveles   : cuantas posiciones puede apilar el ciclo.     |
//|   - PasoPorc     : % de avance a favor entre nivel y nivel.      |
//|   - FactorLote   : escalado del lote por nivel (1.0 = plano,     |
//|                    <1 piramide clasica decreciente, >1 martingala|
//|                    a favor - didacticamente peligrosa).          |
//|   - TrailingComun: al abrir un nivel nuevo, sube el SL de TODAS  |
//|                    las posiciones del ciclo al SL del nivel      |
//|                    nuevo (asegura la piramide entera).           |
//|  El resto funciona como la v6: base aleatoria, SL % por entrada, |
//|  sin TP, ciclo nuevo al quedar plano.                            |
//+------------------------------------------------------------------+
#property copyright "Instituto Quant"
#property version   "7.00"
#property description "v7: piramidacion configurable (niveles, paso, escalado de lote, trailing comun)"

#include <Trade\Trade.mqh>

//--- Parametros configurables
input double LoteBase        = 0.01;        // Lote del primer nivel
input double FactorLote      = 1.0;         // Multiplicador del lote por nivel
input double SLPorc          = 1.0;         // SL de cada posicion (% de su entrada)
input double PasoPorc        = 0.5;         // Avance a favor para piramidar (%)
input int    MaxNiveles      = 5;           // Maximo de posiciones simultaneas del ciclo
input bool   TrailingComun   = true;        // Subir SL de todo el ciclo con cada nivel nuevo
input long   NumeroMagico    = 2026070807;  // Magico: fecha AAAAMMDD + nn de version
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

   archivoEstado = "AEv7_estado_" + _Symbol + ".txt";
   EventSetTimer(5);

   Print("v7 PiramidacionNiveles iniciado en ", _Symbol,
         " | niveles=", MaxNiveles,
         " | paso=", DoubleToString(PasoPorc, 2), "%",
         " | factorLote=", DoubleToString(FactorLote, 2),
         " | trailingComun=", (TrailingComun ? "si" : "no"),
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
//| Normaliza el lote a los limites y paso del simbolo               |
//+------------------------------------------------------------------+
double NormalizarLote(double lote)
{
   double minLote = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLote = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double paso    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(paso > 0.0) lote = MathFloor(lote / paso) * paso;
   if(lote < minLote) lote = minLote;
   if(lote > maxLote) lote = maxLote;
   return(NormalizeDouble(lote, 2));
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
      ultimoIntento = TimeCurrent();
      bool compra = (MathRand() % 2 == 0);
      AbrirNivel(compra, 1, "v7 base");
      return;
   }

   int nivelesAbiertos = ContarPosiciones();
   if(nivelesAbiertos >= MaxNiveles) return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0) return;

   double disparo = esCompra ? entradaExtrema * (1.0 + PasoPorc / 100.0)
                             : entradaExtrema * (1.0 - PasoPorc / 100.0);

   bool toca = esCompra ? (ask >= disparo) : (bid <= disparo);
   if(toca)
   {
      ultimoIntento = TimeCurrent();
      AbrirNivel(esCompra, nivelesAbiertos + 1, "v7 nivel " + (string)(nivelesAbiertos + 1));
   }
}

void OnTick()  { Gestionar(); }
void OnTimer() { Gestionar(); EscribirEstado("ciclo timer"); }

//+------------------------------------------------------------------+
//| Abre el nivel n con lote escalado y SL % de su entrada           |
//+------------------------------------------------------------------+
void AbrirNivel(bool esCompra, int nivel, string etiqueta)
{
   // Lote del nivel: LoteBase x FactorLote^(nivel-1), normalizado
   double lote = LoteBase * MathPow(FactorLote, nivel - 1);
   lote = NormalizarLote(lote);
   if(lote <= 0.0) return;

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
   {
      Print(etiqueta, ": ", (esCompra ? "COMPRA" : "VENTA"),
            " lote=", DoubleToString(lote, 2), " @ ",
            DoubleToString(trade.ResultPrice(), _Digits),
            " | SL=", DoubleToString(sl, _Digits));

      // Trailing comun: todo el ciclo asegura al SL del nivel nuevo
      if(TrailingComun && nivel > 1)
         IgualarStops(esCompra, sl);
   }
   else
      EscribirEstado("fallo retcode=" + (string)trade.ResultRetcode() +
                     " " + trade.ResultRetcodeDescription());
}

//+------------------------------------------------------------------+
//| Sube (o baja, en ventas) el SL de todas las posiciones del ciclo |
//| al nivel dado, solo si eso las MEJORA (nunca las empeora)        |
//+------------------------------------------------------------------+
void IgualarStops(bool esCompra, double slNuevo)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         PositionGetInteger(POSITION_MAGIC) != NumeroMagico)
         continue;

      double slActual = PositionGetDouble(POSITION_SL);
      double tpActual = PositionGetDouble(POSITION_TP);

      bool mejora = esCompra ? (slNuevo > slActual)
                             : (slActual == 0.0 || slNuevo < slActual);
      if(mejora)
         trade.PositionModify(ticket, slNuevo, tpActual);
   }
}
//+------------------------------------------------------------------+
