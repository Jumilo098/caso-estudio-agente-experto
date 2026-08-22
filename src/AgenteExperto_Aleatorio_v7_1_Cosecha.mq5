//+------------------------------------------------------------------+
//|  ESTADO (22-ago-2026): BORRADOR. Compila pero NO tiene backtest   |
//|  ni forward, y NO incluye la capa de telemetria (Telemetria.mqh)  |
//|  de la v7. Antes de ponerla en demo: anadir #include              |
//|  <Telemetria.mqh> y los ganchos de OnTradeTransaction de la v7,   |
//|  y comprobar que ModoCosecha=0 reproduce la v7 bit a bit.         |
//|  Contexto de la tesis: ORO/docs/10_PIRAMIDE_SINTETICA_BTC.md      |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|              AgenteExperto_Aleatorio_v7_1_Cosecha.mq5            |
//|                          Instituto Quant - Agente Experto        |
//|                                                                  |
//|  VERSION 7.1 (Cosecha) - nace del BUG-15 y del hallazgo en vivo: |
//|  con la piramide LLENA, la v7 congela el SL comun (IgualarStops  |
//|  solo corre al abrir niveles y Gestionar retorna al llegar a     |
//|  MaxNiveles). El robot genera la cola pero no la cosecha: del    |
//|  ciclo vivo de agosto 2026, solo +39 de +883 flotantes quedaban  |
//|  asegurados. La v7.1 anade MODOS DE COSECHA para el laboratorio: |
//|                                                                  |
//|   ModoCosecha = 0  CONTROL: comportamiento identico a la v7.     |
//|   ModoCosecha = 1  RATCHET VIRTUAL: al llenarse la piramide,     |
//|                    sigue "abriendo niveles imaginarios" cada     |
//|                    PasoPorc de avance y sube el SL comun como    |
//|                    si el nivel existiera. No abre posiciones.    |
//|   ModoCosecha = 2  TRAILING DEL PICO: al llenarse, el SL comun   |
//|                    persigue al mejor precio alcanzado a          |
//|                    distancia TrailPostPorc (%).                  |
//|   ModoCosecha = 3  PIRAMIDE RODANTE: cada PasoPorc de avance     |
//|                    extra, CIERRA el nivel mas antiguo (cobra el  |
//|                    tramo mas rentable) y sube el SL comun; el    |
//|                    hueco libre deja que la logica normal abra    |
//|                    un nivel nuevo arriba. La piramide camina:    |
//|                    cobra por abajo, compra por arriba.           |
//|   ModoCosecha = 4  COSECHA TOTAL (22-ago-2026): en cualquier     |
//|                    punto del ciclo, si el flotante >= PrimasK    |
//|                    primas (prima = LoteBase*SLPorc% del nivel 1, |
//|                    la perdida del primer SL), cierra TODO a      |
//|                    mercado y resetea: recupera la optionalidad   |
//|                    en ambas direcciones y financia PrimasK       |
//|                    intentos nuevos. Regla pre-registrada en      |
//|                    ORO/docs/10 seccion 6; backtest en            |
//|                    ORO/code/investigacion-btc/piramide_cosecha.py|
//|   ModoCosecha = 5  COSECHA TOTAL + RATCHET (4 y 1 a la vez).     |
//|                                                                  |
//|  Inspiracion del modo 1 y 3: v5_escalonado, la UNICA variante    |
//|  del caso con neto REALIZADO positivo (BUG-15, auditoria         |
//|  2026-08-21): asegurar por tramos y dejar correr.                |
//|                                                                  |
//|  Ademas:                                                         |
//|   - Heartbeat de equity: el archivo de estado ahora incluye      |
//|     equity, balance y flotante en cada latido, para que el       |
//|     Runner/telemetria mida el drawdown REAL (no solo al abrir/   |
//|     cerrar/diario).                                              |
//|   - MejoraMinPuntos en IgualarStops (BUG-08).                    |
//|   - Manejo simetrico y explicito de SL=0 (BUG-09).               |
//|   - Magic nuevo 2026082571 = AAAAMMDD + 71 (BUG-04).             |
//|  El resto funciona como la v7: base aleatoria, SL % por entrada, |
//|  sin TP, ciclo nuevo al quedar plano, semilla reproducible.      |
//+------------------------------------------------------------------+
#property copyright "Instituto Quant"
#property version   "7.10"
#property description "v7.1: piramidacion configurable + modos de cosecha + heartbeat de equity"

#include <Trade\Trade.mqh>

//--- Parametros configurables
input double LoteBase          = 0.01;        // Lote del primer nivel
input double FactorLote        = 1.0;         // Multiplicador del lote por nivel
input double SLPorc            = 1.0;         // SL de cada posicion (% de su entrada)
input double PasoPorc          = 0.5;         // Avance a favor para piramidar (%)
input int    MaxNiveles        = 8;           // Maximo de posiciones simultaneas del ciclo
input bool   TrailingComun     = true;        // Subir SL de todo el ciclo con cada nivel nuevo
input int    ModoCosecha       = 1;           // 0=control(v7) 1=ratchet 2=trailing pico 3=rodante 4=cosecha total 5=total+ratchet
input double TrailPostPorc     = 1.0;         // Distancia del trailing post-llenado (modo 2, % del pico)
input double PrimasK           = 100.0;       // Modos 4/5: cosechar cuando flotante >= PrimasK x prima del nivel 1
input int    MejoraMinPuntos   = 100;         // Mejora minima del SL en puntos (BUG-08)
input int    HeartbeatSegundos = 5;           // Frecuencia del latido de estado
input long   NumeroMagico      = 2026082571;  // Magico: fecha AAAAMMDD + 71 (v7.1, BUG-04)
input int    EsperaReintento   = 5;           // Segundos entre reintentos
input int    SemillaAleatoria  = 0;           // 0 = reloj (live); fijo = reproducible (tester)

//--- Objetos globales
CTrade   trade;
datetime ultimoIntento = 0;
string   archivoEstado;
double   picoCosecha   = 0.0;   // mejor precio alcanzado con piramide llena (modo 2)

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

   archivoEstado = "AEv71_estado_" + _Symbol + ".txt";
   EventSetTimer(HeartbeatSegundos < 1 ? 1 : HeartbeatSegundos);

   Print("v7.1 Cosecha iniciado en ", _Symbol,
         " | niveles=", MaxNiveles,
         " | paso=", DoubleToString(PasoPorc, 2), "%",
         " | factorLote=", DoubleToString(FactorLote, 2),
         " | trailingComun=", (TrailingComun ? "si" : "no"),
         " | modoCosecha=", ModoCosecha,
         " | semilla=", semilla);
   EscribirEstado("iniciado");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) { EventKillTimer(); }

//+------------------------------------------------------------------+
//| Estado observable en MQL5\Files (heartbeat con equity)           |
//| El Runner/telemetria puede leer este latido para medir el        |
//| drawdown real de la cuenta, no solo el de trades cerrados.       |
//+------------------------------------------------------------------+
void EscribirEstado(string detalle)
{
   if(MQLInfoInteger(MQL_TESTER)) return;

   int h = FileOpen(archivoEstado, FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(h == INVALID_HANDLE) return;

   double eq  = AccountInfoDouble(ACCOUNT_EQUITY);
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);

   FileWriteString(h, "hora_servidor=" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\r\n");
   FileWriteString(h, "terminal_trade_allowed=" + (string)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) + "\r\n");
   FileWriteString(h, "mql_trade_allowed=" + (string)MQLInfoInteger(MQL_TRADE_ALLOWED) + "\r\n");
   FileWriteString(h, "equity=" + DoubleToString(eq, 2) + "\r\n");
   FileWriteString(h, "balance=" + DoubleToString(bal, 2) + "\r\n");
   FileWriteString(h, "flotante=" + DoubleToString(eq - bal, 2) + "\r\n");
   FileWriteString(h, "posiciones_propias=" + (string)ContarPosiciones() + "\r\n");

   bool   esCompra;
   double entradaExtrema;
   if(EstadoCiclo(esCompra, entradaExtrema))
   {
      FileWriteString(h, "ciclo=" + (esCompra ? "compra" : "venta") + "\r\n");
      FileWriteString(h, "entrada_extrema=" + DoubleToString(entradaExtrema, _Digits) + "\r\n");
      FileWriteString(h, "sl_comun=" + DoubleToString(SLComun(esCompra), _Digits) + "\r\n");
   }
   else
      FileWriteString(h, "ciclo=plano\r\n");

   FileWriteString(h, "modo_cosecha=" + (string)ModoCosecha + "\r\n");
   FileWriteString(h, "pico_cosecha=" + DoubleToString(picoCosecha, _Digits) + "\r\n");
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
//| SL comun vigente del ciclo (el mas avanzado entre las posiciones)|
//+------------------------------------------------------------------+
double SLComun(bool esCompra)
{
   double sl = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         PositionGetInteger(POSITION_MAGIC) != NumeroMagico)
         continue;

      double s = PositionGetDouble(POSITION_SL);
      if(s <= 0.0) continue;
      if(sl == 0.0) sl = s;
      else sl = esCompra ? MathMax(sl, s) : MathMin(sl, s);
   }
   return(sl);
}

//+------------------------------------------------------------------+
//| Nucleo: sin posiciones -> ciclo nuevo; llenando -> piramidar;    |
//| piramide llena -> cosechar segun el modo                         |
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
      picoCosecha   = 0.0;                     // ciclo nuevo: reset del pico
      ultimoIntento = TimeCurrent();
      bool compra = (MathRand() % 2 == 0);
      AbrirNivel(compra, 1, "v7.1 base");
      return;
   }

   // Modos 4/5: cosecha total por multiplo de prima, en cualquier punto del ciclo
   if(ModoCosecha == 4 || ModoCosecha == 5)
   {
      double flot  = FlotanteCiclo();
      double prima = PrimaCiclo();
      if(prima > 0.0 && flot >= PrimasK * prima)
      {
         ultimoIntento = TimeCurrent();
         int cerradas = CerrarCiclo();
         Print("cosecha m", ModoCosecha, ": flotante ", DoubleToString(flot, 2),
               " >= ", DoubleToString(PrimasK, 0), " x prima ", DoubleToString(prima, 2),
               " | cerradas=", cerradas);
         return;
      }
   }

   int nivelesAbiertos = ContarPosiciones();
   if(nivelesAbiertos >= MaxNiveles)
   {
      Cosechar(esCompra, entradaExtrema);      // aqui la v7 se congelaba (BUG-15)
      return;
   }

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0) return;

   double disparo = esCompra ? entradaExtrema * (1.0 + PasoPorc / 100.0)
                             : entradaExtrema * (1.0 - PasoPorc / 100.0);

   bool toca = esCompra ? (ask >= disparo) : (bid <= disparo);
   if(toca)
   {
      ultimoIntento = TimeCurrent();
      AbrirNivel(esCompra, nivelesAbiertos + 1, "v7.1 nivel " + (string)(nivelesAbiertos + 1));
   }
}

void OnTick()  { Gestionar(); }
void OnTimer() { Gestionar(); EscribirEstado("latido"); }

//+------------------------------------------------------------------+
//| Cosecha post-llenado: la piramide ya no crece, pero el SL si     |
//+------------------------------------------------------------------+
void Cosechar(bool esCompra, double entradaExtrema)
{
   if(ModoCosecha <= 0) return;                // modo 0: control identico a la v7

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0) return;

   double factorSL = esCompra ? (1.0 - SLPorc / 100.0)
                              : (1.0 + SLPorc / 100.0);

   if(ModoCosecha == 1 || ModoCosecha == 5)
   {
      // RATCHET VIRTUAL: derivar del SL comun la "entrada" del ultimo nivel
      // (real o virtual) y seguir subiendo el SL cada PasoPorc de avance,
      // como si la piramide siguiera abriendo niveles. Sin estado en disco:
      // sobrevive reinicios porque todo se deriva del SL vigente.
      double slComun = SLComun(esCompra);
      if(slComun <= 0.0) return;

      double nivelVirtual = slComun / factorSL;
      double disparo = esCompra ? nivelVirtual * (1.0 + PasoPorc / 100.0)
                                : nivelVirtual * (1.0 - PasoPorc / 100.0);
      bool toca = esCompra ? (ask >= disparo) : (bid <= disparo);
      if(toca)
      {
         double slNuevo = NormalizeDouble(disparo * factorSL, _Digits);
         IgualarStops(esCompra, slNuevo);
         Print("cosecha m1: nivel virtual @ ", DoubleToString(disparo, _Digits),
               " | SL comun -> ", DoubleToString(slNuevo, _Digits));
      }
   }
   else if(ModoCosecha == 2)
   {
      // TRAILING DEL PICO: el SL comun persigue al mejor precio alcanzado
      // desde que la piramide se lleno, a distancia TrailPostPorc.
      double ref = esCompra ? bid : ask;
      if(picoCosecha <= 0.0) picoCosecha = ref;
      picoCosecha = esCompra ? MathMax(picoCosecha, ref)
                             : MathMin(picoCosecha, ref);

      double slNuevo = esCompra ? picoCosecha * (1.0 - TrailPostPorc / 100.0)
                                : picoCosecha * (1.0 + TrailPostPorc / 100.0);
      IgualarStops(esCompra, NormalizeDouble(slNuevo, _Digits));
   }
   else if(ModoCosecha == 3)
   {
      // PIRAMIDE RODANTE: mismo disparo que la piramidacion normal; al
      // tocarlo, COBRA el nivel mas antiguo (el de mejor precio) y sube el
      // SL comun. El hueco libre hace que Gestionar() abra un nivel nuevo
      // arriba en el siguiente ciclo: la piramide camina con la tendencia.
      double disparo = esCompra ? entradaExtrema * (1.0 + PasoPorc / 100.0)
                                : entradaExtrema * (1.0 - PasoPorc / 100.0);
      bool toca = esCompra ? (ask >= disparo) : (bid <= disparo);
      if(!toca) return;

      ultimoIntento = TimeCurrent();
      if(CerrarNivelMasAntiguo(esCompra))
         IgualarStops(esCompra, NormalizeDouble(disparo * factorSL, _Digits));
   }
}

//+------------------------------------------------------------------+
//| Flotante del ciclo (profit + swap de todas las posiciones)       |
//+------------------------------------------------------------------+
double FlotanteCiclo()
{
   double f = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         PositionGetInteger(POSITION_MAGIC) != NumeroMagico)
         continue;
      f += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return(f);
}

//+------------------------------------------------------------------+
//| Prima del ciclo = perdida del SL del nivel 1 (la posicion mas    |
//| antigua): LoteBase * SLPorc% * entrada, en moneda de la cuenta   |
//+------------------------------------------------------------------+
double PrimaCiclo()
{
   datetime tMin = 0; double entrada = 0.0; double lote = 0.0; bool esCompra = true;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         PositionGetInteger(POSITION_MAGIC) != NumeroMagico)
         continue;
      datetime t = (datetime)PositionGetInteger(POSITION_TIME);
      if(tMin == 0 || t < tMin)
      {
         tMin = t;
         entrada  = PositionGetDouble(POSITION_PRICE_OPEN);
         lote     = PositionGetDouble(POSITION_VOLUME);
         esCompra = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      }
   }
   if(tMin == 0) return(0.0);
   double sl = esCompra ? entrada * (1.0 - SLPorc / 100.0) : entrada * (1.0 + SLPorc / 100.0);
   double perdida = 0.0;
   if(!OrderCalcProfit(esCompra ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, _Symbol, lote, entrada, sl, perdida))
      return(0.0);
   return(MathAbs(perdida));
}

//+------------------------------------------------------------------+
//| Cierra todas las posiciones del ciclo a mercado (modos 4/5)      |
//+------------------------------------------------------------------+
int CerrarCiclo()
{
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         PositionGetInteger(POSITION_MAGIC) != NumeroMagico)
         continue;
      if(trade.PositionClose(ticket) && trade.ResultRetcode() == TRADE_RETCODE_DONE) n++;
      else EscribirEstado("fallo cierre total retcode=" + (string)trade.ResultRetcode());
   }
   picoCosecha = 0.0;
   return(n);
}

//+------------------------------------------------------------------+
//| Cierra la posicion mas antigua del ciclo (la de mejor precio)    |
//+------------------------------------------------------------------+
bool CerrarNivelMasAntiguo(bool esCompra)
{
   ulong  ticketObjetivo = 0;
   double entradaObjetivo = 0.0;
   double profitObjetivo = 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         PositionGetInteger(POSITION_MAGIC) != NumeroMagico)
         continue;

      double entrada = PositionGetDouble(POSITION_PRICE_OPEN);
      bool esMejor = (ticketObjetivo == 0) ||
                     (esCompra ? (entrada < entradaObjetivo)
                               : (entrada > entradaObjetivo));
      if(esMejor)
      {
         ticketObjetivo  = ticket;
         entradaObjetivo = entrada;
         profitObjetivo  = PositionGetDouble(POSITION_PROFIT);
      }
   }

   if(ticketObjetivo == 0) return(false);

   bool ok = trade.PositionClose(ticketObjetivo);
   if(ok && trade.ResultRetcode() == TRADE_RETCODE_DONE)   // BUG-05
   {
      Print("cosecha m3: cobrado nivel @ ", DoubleToString(entradaObjetivo, _Digits),
            " | profit aprox ", DoubleToString(profitObjetivo, 2));
      return(true);
   }

   EscribirEstado("fallo cierre cosecha retcode=" + (string)trade.ResultRetcode() +
                  " " + trade.ResultRetcodeDescription());
   return(false);
}

//+------------------------------------------------------------------+
//| Abre el nivel n con lote escalado y SL % de su entrada           |
//+------------------------------------------------------------------+
void AbrirNivel(bool esCompra, int nivel, string etiqueta)
{
   // Lote del nivel: LoteBase x FactorLote^(nivel-1), normalizado (BUG-13:
   // con LoteBase en el minimo y FactorLote<1, la normalizacion lo aplana)
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

   if(ok && trade.ResultRetcode() == TRADE_RETCODE_DONE)   // BUG-05
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
//| al nivel dado, solo si eso las MEJORA en al menos                |
//| MejoraMinPuntos (BUG-08). SL=0 se trata explicito (BUG-09).      |
//+------------------------------------------------------------------+
void IgualarStops(bool esCompra, double slNuevo)
{
   double mejoraMin = MejoraMinPuntos * _Point;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         PositionGetInteger(POSITION_MAGIC) != NumeroMagico)
         continue;

      double slActual = PositionGetDouble(POSITION_SL);
      double tpActual = PositionGetDouble(POSITION_TP);

      bool mejora;
      if(slActual == 0.0)                                   // BUG-09
         mejora = true;
      else
         mejora = esCompra ? (slNuevo >= slActual + mejoraMin)
                           : (slNuevo <= slActual - mejoraMin);

      if(mejora)
         trade.PositionModify(ticket, slNuevo, tpActual);
   }
}
//+------------------------------------------------------------------+
