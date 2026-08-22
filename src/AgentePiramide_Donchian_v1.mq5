//+------------------------------------------------------------------+
//|                    AgentePiramide_Donchian_v1.mq5                |
//|                          Instituto Quant - Agente Experto        |
//|                                                                  |
//|  DE DONDE SALE ESTE EA (22-ago-2026)                             |
//|  ------------------------------------------------------------    |
//|  Es el hijo del Agente Experto Aleatorio v7 (caso azar,          |
//|  sesiones 6/9/10). Conserva su PIRAMIDE (niveles cada PasoPorc   |
//|  a favor, SL % por nivel, trailing comun) y le cambia dos cosas  |
//|  que el caso demostro que eran el problema:                      |
//|                                                                  |
//|   1. LA SALIDA. La v7 congelaba el SL al llenar la piramide      |
//|      (BUG-15). Sin cosecha, la v7 PIERDE en los 8 anos 2018-2025 |
//|      en el 100% de 100 semillas (-$6.477 por 0,01 lote). El      |
//|      famoso +$1.864 del sweet spot era UNA posicion cerrada por  |
//|      "end of test" del tester: balance $70,87 el 29-ene-2026 y   |
//|      un corto de 8 niveles a ~87.500 cerrado a 64.008 el 6-jul.  |
//|      Aqui, con la piramide llena, el SL comun persigue al mejor  |
//|      precio a TrailPostPorc (trailing del pico).                 |
//|                                                                  |
//|   2. LA ENTRADA. La v7 lanzaba una moneda. Con cosecha, el azar  |
//|      da Sharpe anual ~0,25, 3 de 8 anos negativos y el 91% del   |
//|      resultado en un solo ano: una loteria con VE positivo.      |
//|      Aqui la direccion la decide una RUPTURA DONCHIAN: largo si  |
//|      el cierre de la vela anterior supera el maximo de las N     |
//|      velas previas, corto si rompe el minimo, y SI NO HAY        |
//|      RUPTURA NO ENTRA. Eso es lo que mas paga: no pagar prima    |
//|      cuando no hay movimiento.                                   |
//|                                                                  |
//|  LO QUE MIDIO LA REPLICA (Python, M15 Exness, bid + spread de la |
//|  barra, recorrido O-L-H-C, gaps ejecutan el SL en la apertura,   |
//|  swap 0). Parametros CONGELADOS: Donchian 336 + trail 0,5%.      |
//|  Neto realizado por ano, lote 0,01 BTC (USD):                    |
//|    2018 +8 | 2019 +215 | 2020 +299 | 2021 +922 | 2022 +98        |
//|    2023 +929 | 2024 +674 | 2025 +831 | suma +3.978               |
//|    Sharpe anual 1,3 | DD max $448 | ret/DD 8,9 | acierto 13-21%  |
//|    2026 ene-jul -35 | forward 15-jul/19-ago-2026 -86 (lateral)   |
//|                                                                  |
//|  BATERIA DE ROBUSTEZ (criterios escritos antes de mirar):        |
//|   - Vecindario: 49 combinaciones (N 48..1344 x 7 cosechas) TODAS |
//|     positivas a 8 anos. Es una meseta, no un pico.               |
//|   - Fuera de muestra con parametros congelados: ETH 7/8 anos,    |
//|     Sharpe 1,14 | XAU 6/8, 0,66 | USTEC 4/6, 0,62.               |
//|   - Cortos positivos en 7 de 8 anos (+898 en 2021): no es solo   |
//|     beta alcista de BTC (en 2018 los cortos dieron ~0).          |
//|   - Slippage 0,05% adverso por salida: 6/8 anos, Sharpe 1,15.    |
//|     0,10%: Sharpe 0,86. Spread x2: 7/8, 1,14.                    |
//|   - Walk-forward 2018-21 -> 2022-25: 49/49 positivas fuera de    |
//|     muestra, mediana Sharpe 0,99. Correlacion Sharpe IS/OOS      |
//|     = -0,15: ELEGIR "EL MEJOR" NO SIRVE; usa el centro de la     |
//|     meseta y no reoptimices por resultado.                       |
//|   - 85 ventanas rodantes de 12 meses: 100% positivas, P10 +$111. |
//|   - Bootstrap de ciclos (2.000 anos sinteticos): P(ano<0) 12%,   |
//|     DD P95 $377, P99 $467 por 0,01 lote.                         |
//|                                                                  |
//|  COMPARACION (misma bateria, a igual DD maximo del 25%):         |
//|    XAU M15 Runner (EA de un alumno, en REAL): ~27%/ano, 5/5 anos |
//|    Este EA en BTC: ~28%/ano (mediana 27%), 8/8 anos              |
//|    Este EA en ETH: ~46%/ano (36% sin 2021), 7/8 anos             |
//|    Este EA en XAU: ~10%/ano -> en oro el Runner es mucho mejor   |
//|    Holdear BTC:   +531% en 8 anos con DD 80%: inoperable         |
//|                                                                  |
//|  DIMENSIONADO: DD P95 anual $377 por 0,01 lote de BTC -> para un |
//|  DD tope del 25%: $1.500-2.000 POR CADA 0,01 LOTE. Con $250 el   |
//|  DD P95 es del 150% (ruina). Cifra honesta para comunicar:       |
//|  15-30%/ano a 25% de DD con un ano de cada 8-10 cerca de cero.   |
//|                                                                  |
//|  LO QUE NO ESTA DEMOSTRADO (por eso va a DEMO con telemetria):   |
//|   - Es una replica Python, no el Strategy Tester: este EA debe   |
//|     reproducir primero el signo y la magnitud por ano de arriba. |
//|   - Trailing a 0,5% en BTC: sensible a la ejecucion real.        |
//|   - El diseno se eligio en 2026 mirando 2018-2025 de BTC; la     |
//|     unica evidencia realmente fuera de muestra es ETH/XAU/USTEC. |
//|   - El forward jul-ago-2026 es negativo en TODAS las variantes.  |
//|   - Swap 0 en la replica (la demo Exness registro 0).            |
//|  Plan pre-registrado: tester MT5 -> demo $2.000 por 0,01 lote,   |
//|  >= 6 meses, agente propio en el hub -> ETH en paralelo.         |
//|  Alarma: 12 meses rodantes negativos (nunca ocurrio en 85).      |
//|                                                                  |
//|  v1.1 (22-ago-2026, tras el primer tester): los niveles 2..N se  |
//|  colocan como ORDENES STOP PENDIENTES en su precio de disparo    |
//|  (extrema +/- PasoPorc). La v1.0 los abria a mercado en el       |
//|  siguiente tick con 5 s de espera y en movimientos rapidos los   |
//|  llenaba 0,2-0,3% peor que el disparo: la piramide no se llenaba |
//|  y el tester dio -$1.928 en 8 anos frente a +$3.978 de la        |
//|  replica. La replica asume llenado en el disparo: eso SOLO es    |
//|  realista con una orden stop. Leccion para el caso: el tester    |
//|  es el criterio 1 por algo.                                      |
//|  Fuentes: ORO/docs/10_PIRAMIDE_SINTETICA_BTC.md (secciones 8-13) |
//|  y ORO/code/investigacion-btc/piramide_*.py (replica y pruebas). |
//+------------------------------------------------------------------+
#property copyright "Instituto Quant"
#property version   "1.10"
#property description "Ruptura Donchian + piramide de niveles + trailing comun + trailing del pico. Sin ruptura no entra."

#include <Trade\Trade.mqh>
#include <Telemetria.mqh>   // capa de auditoria (UsarTelemetria=false la apaga; no cambia una decision)

//--- SENAL (valores congelados: centro de la meseta; no reoptimizar por resultado)
input ENUM_TIMEFRAMES PeriodoSenal   = PERIOD_M15;  // Marco de la ruptura
input int    DonchianBarras  = 336;         // N velas previas (336 M15 = 3,5 dias)
//--- PIRAMIDE (identica a la v7)
input double LoteBase        = 0.01;        // Lote de cada nivel
input double SLPorc          = 1.0;         // SL de cada nivel (% de su entrada)
input double PasoPorc        = 0.5;         // Avance a favor para abrir el siguiente nivel (%)
input int    MaxNiveles      = 8;           // Niveles maximos del ciclo
input bool   TrailingComun   = true;        // Al abrir un nivel, sube el SL de todo el ciclo
//--- COSECHA
input double TrailPostPorc   = 0.5;         // Con la piramide llena: SL comun a esta distancia del pico (%)
input int    MejoraMinPuntos = 100;         // Mejora minima del SL para modificar (evita spam al broker)
//--- VARIOS
input long   NumeroMagico    = 2026082201;  // AAAAMMDD + 01
input int    EsperaReintento = 5;           // Segundos entre intentos
input int    MaxSpreadPuntos = 0;           // 0 = sin filtro; >0 no abre si el spread supera esto

//--- Globales
CTrade   trade;
datetime ultimoIntento  = 0;
datetime ultimaVelaSenal = 0;
datetime ultimoCierre   = 0;
double   picoCosecha    = 0.0;
string   archivoEstado;
ulong    g_trailedTickets[];

//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(NumeroMagico);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.SetDeviationInPoints(50);
   archivoEstado = "APD1_estado_" + _Symbol + ".txt";
   EventSetTimer(5);
   Print("AgentePiramide_Donchian v1 en ", _Symbol, " | donchian=", DonchianBarras, " ", EnumToString(PeriodoSenal),
         " | niveles=", MaxNiveles, " paso=", DoubleToString(PasoPorc, 2), "% sl=", DoubleToString(SLPorc, 2),
         "% | trailPico=", DoubleToString(TrailPostPorc, 2), "%");
   TelemetriaInit("donchian-1.0", NumeroMagico);
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason) { TelemetriaDeinit(reason); }

//+------------------------------------------------------------------+
//| Senal Donchian sobre velas CERRADAS: +1 largo, -1 corto, 0 nada  |
//| close[1] contra max/min de las N velas anteriores a ella (2..N+1)|
//+------------------------------------------------------------------+
int SenalDonchian()
{
   if(Bars(_Symbol, PeriodoSenal) < DonchianBarras + 3) return 0;
   double cierre = iClose(_Symbol, PeriodoSenal, 1);
   int iH = iHighest(_Symbol, PeriodoSenal, MODE_HIGH, DonchianBarras, 2);
   int iL = iLowest (_Symbol, PeriodoSenal, MODE_LOW,  DonchianBarras, 2);
   if(iH < 0 || iL < 0) return 0;
   double maxPrev = iHigh(_Symbol, PeriodoSenal, iH);
   double minPrev = iLow (_Symbol, PeriodoSenal, iL);
   if(cierre > maxPrev) return  1;
   if(cierre < minPrev) return -1;
   return 0;
}

//+------------------------------------------------------------------+
//| Utilidades de posiciones (simbolo + magico)                      |
//+------------------------------------------------------------------+
bool EsMia()
{
   return PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == NumeroMagico;
}
int ContarPosiciones()
{
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(PositionGetTicket(i) != 0 && EsMia()) n++;
   return n;
}
bool EstadoCiclo(bool &esCompra, double &entradaExtrema)
{
   bool hay = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) == 0 || !EsMia()) continue;
      bool   c = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      double e = PositionGetDouble(POSITION_PRICE_OPEN);
      if(!hay) { esCompra = c; entradaExtrema = e; hay = true; }
      else
      {
         if(esCompra && e > entradaExtrema)  entradaExtrema = e;
         if(!esCompra && e < entradaExtrema) entradaExtrema = e;
      }
   }
   return hay;
}
double NormalizarLote(double lote)
{
   double mn = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), mx = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double st = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(st > 0) lote = MathFloor(lote / st) * st;
   return NormalizeDouble(MathMin(MathMax(lote, mn), mx), 2);
}

//+------------------------------------------------------------------+
//| Nucleo                                                           |
//+------------------------------------------------------------------+
void Gestionar()
{
   if(TimeCurrent() - ultimoIntento < EsperaReintento) return;
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
   { EscribirEstado("bloqueado: sin permiso de trading"); return; }

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID), ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0 || ask <= 0) return;

   bool esCompra; double entradaExtrema;
   if(!EstadoCiclo(esCompra, entradaExtrema))
   {
      // PLANO: solo una decision por vela de senal, y solo si hay ruptura
      datetime vela = iTime(_Symbol, PeriodoSenal, 0);
      if(vela == ultimaVelaSenal) return;
      if(vela <= ultimoCierre) return;              // espera a la vela siguiente al cierre (como la replica)
      ultimaVelaSenal = vela;
      int s = SenalDonchian();
      if(s == 0) { EscribirEstado("plano: sin ruptura"); return; }
      if(MaxSpreadPuntos > 0 && SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > MaxSpreadPuntos)
      { EscribirEstado("plano: spread alto"); return; }
      picoCosecha = 0.0;
      ultimoIntento = TimeCurrent();
      AbrirNivel(s > 0, 1, "donchian base");
      return;
   }

   int n = ContarPosiciones();
   if(n >= MaxNiveles) { CancelarPendientes(); Cosechar(esCompra, bid, ask); return; }

   // v1.1: el siguiente nivel es una orden STOP pendiente en su precio de disparo
   double disparo = NormalizeDouble(esCompra ? entradaExtrema * (1.0 + PasoPorc / 100.0)
                                             : entradaExtrema * (1.0 - PasoPorc / 100.0), _Digits);
   if(!HayPendienteEn(disparo))
   {
      CancelarPendientes();
      ColocarStop(esCompra, disparo, "donchian nivel " + (string)(n + 1));
   }
}

//+------------------------------------------------------------------+
//| Ordenes pendientes del ciclo                                     |
//+------------------------------------------------------------------+
bool HayPendienteEn(double precio)
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong t = OrderGetTicket(i);
      if(t == 0 || OrderGetString(ORDER_SYMBOL) != _Symbol || OrderGetInteger(ORDER_MAGIC) != NumeroMagico) continue;
      if(MathAbs(OrderGetDouble(ORDER_PRICE_OPEN) - precio) < _Point) return true;
   }
   return false;
}
void CancelarPendientes()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong t = OrderGetTicket(i);
      if(t == 0 || OrderGetString(ORDER_SYMBOL) != _Symbol || OrderGetInteger(ORDER_MAGIC) != NumeroMagico) continue;
      trade.OrderDelete(t);
   }
}
void ColocarStop(bool esCompra, double precio, string etiqueta)
{
   double lote = NormalizarLote(LoteBase);
   double sl = NormalizeDouble(esCompra ? precio * (1.0 - SLPorc / 100.0) : precio * (1.0 + SLPorc / 100.0), _Digits);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK), bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   // si el precio ya paso el disparo (gap), entra a mercado
   if((esCompra && ask >= precio) || (!esCompra && bid <= precio))
   { AbrirNivel(esCompra, ContarPosiciones() + 1, etiqueta); return; }
   bool ok = esCompra ? trade.BuyStop(lote, precio, _Symbol, sl, 0.0, ORDER_TIME_GTC, 0, etiqueta)
                      : trade.SellStop(lote, precio, _Symbol, sl, 0.0, ORDER_TIME_GTC, 0, etiqueta);
   if(!ok || trade.ResultRetcode() != TRADE_RETCODE_PLACED)
      EscribirEstado("fallo stop retcode=" + (string)trade.ResultRetcode() + " " + trade.ResultRetcodeDescription());
}

//+------------------------------------------------------------------+
//| Cosecha: trailing del pico con la piramide llena                 |
//+------------------------------------------------------------------+
void Cosechar(bool esCompra, double bid, double ask)
{
   double ref = esCompra ? bid : ask;
   if(picoCosecha <= 0.0) picoCosecha = ref;
   picoCosecha = esCompra ? MathMax(picoCosecha, ref) : MathMin(picoCosecha, ref);
   double sl = esCompra ? picoCosecha * (1.0 - TrailPostPorc / 100.0) : picoCosecha * (1.0 + TrailPostPorc / 100.0);
   IgualarStops(esCompra, NormalizeDouble(sl, _Digits));
}

//+------------------------------------------------------------------+
void AbrirNivel(bool esCompra, int nivel, string etiqueta)
{
   double lote = NormalizarLote(LoteBase);
   if(lote <= 0) return;
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK), bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double precio = esCompra ? ask : bid;
   double sl = NormalizeDouble(esCompra ? precio * (1.0 - SLPorc / 100.0) : precio * (1.0 + SLPorc / 100.0), _Digits);

   bool ok = esCompra ? trade.Buy(lote, _Symbol, 0.0, sl, 0.0, etiqueta) : trade.Sell(lote, _Symbol, 0.0, sl, 0.0, etiqueta);
   if(ok && trade.ResultRetcode() == TRADE_RETCODE_DONE)
   {
      Print(etiqueta, ": ", (esCompra ? "COMPRA" : "VENTA"), " ", DoubleToString(lote, 2), " @ ",
            DoubleToString(trade.ResultPrice(), _Digits), " SL=", DoubleToString(sl, _Digits));
      TelemetriaOpen(esCompra ? "BUY" : "SELL", lote, SLPorc, sl, 0.0, (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD));
      if(TrailingComun && nivel > 1) IgualarStops(esCompra, sl);
   }
   else
      EscribirEstado("fallo retcode=" + (string)trade.ResultRetcode() + " " + trade.ResultRetcodeDescription());
}

//+------------------------------------------------------------------+
//| Sube (baja en cortos) el SL de todo el ciclo si mejora           |
//+------------------------------------------------------------------+
void IgualarStops(bool esCompra, double slNuevo)
{
   double mejoraMin = MejoraMinPuntos * _Point;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !EsMia()) continue;
      double slActual = PositionGetDouble(POSITION_SL), tp = PositionGetDouble(POSITION_TP);
      bool mejora = (slActual == 0.0) ? true
                  : (esCompra ? (slNuevo >= slActual + mejoraMin) : (slNuevo <= slActual - mejoraMin));
      if(mejora && trade.PositionModify(ticket, slNuevo, tp)) MarcarTrailed(ticket);
   }
}

//+------------------------------------------------------------------+
//| Estado observable en MQL5\Files                                  |
//+------------------------------------------------------------------+
void EscribirEstado(string detalle)
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   int h = FileOpen(archivoEstado, FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(h == INVALID_HANDLE) return;
   double eq = AccountInfoDouble(ACCOUNT_EQUITY), bal = AccountInfoDouble(ACCOUNT_BALANCE);
   FileWriteString(h, "hora_servidor=" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\r\n");
   FileWriteString(h, "equity=" + DoubleToString(eq, 2) + "\r\nbalance=" + DoubleToString(bal, 2) + "\r\n");
   FileWriteString(h, "flotante=" + DoubleToString(eq - bal, 2) + "\r\n");
   FileWriteString(h, "posiciones_propias=" + (string)ContarPosiciones() + "\r\n");
   FileWriteString(h, "senal_actual=" + (string)SenalDonchian() + "\r\n");
   FileWriteString(h, "pico_cosecha=" + DoubleToString(picoCosecha, _Digits) + "\r\n");
   FileWriteString(h, "detalle=" + detalle + "\r\n");
   FileClose(h);
}

void OnTick()  { TelemetriaVaciarCola(); Gestionar(); }
void OnTimer() { Gestionar(); EscribirEstado("latido"); TelemetriaTimer(); }

//+------------------------------------------------------------------+
//| Telemetria de cierres (igual que la v7): SL original vs TRAIL    |
//+------------------------------------------------------------------+
void MarcarTrailed(ulong ticket)
{
   for(int i = ArraySize(g_trailedTickets) - 1; i >= 0; i--) if(g_trailedTickets[i] == ticket) return;
   int n = ArraySize(g_trailedTickets); ArrayResize(g_trailedTickets, n + 1); g_trailedTickets[n] = ticket;
}
bool EsTrailed(ulong posId)
{
   for(int i = ArraySize(g_trailedTickets) - 1; i >= 0; i--) if(g_trailedTickets[i] == posId) return true;
   return false;
}
void OlvidarTrailed(ulong posId)
{
   int n = ArraySize(g_trailedTickets);
   for(int i = 0; i < n; i++)
      if(g_trailedTickets[i] == posId)
      { for(int j = i + 1; j < n; j++) g_trailedTickets[j - 1] = g_trailedTickets[j]; ArrayResize(g_trailedTickets, n - 1); return; }
}
string MotivoSalida(long dealReason, ulong posId)
{
   if(dealReason == DEAL_REASON_TP) return "TP";
   if(dealReason == DEAL_REASON_SL) return EsTrailed(posId) ? "TRAIL" : "SL";
   if(dealReason == DEAL_REASON_SO) return "OTHER";
   if(dealReason == DEAL_REASON_CLIENT || dealReason == DEAL_REASON_MOBILE ||
      dealReason == DEAL_REASON_WEB    || dealReason == DEAL_REASON_EXPERT) return "MANUAL";
   return "OTHER";
}
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   ulong deal = trans.deal;
   if(deal == 0 || !HistoryDealSelect(deal)) return;
   if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol || HistoryDealGetInteger(deal, DEAL_MAGIC) != NumeroMagico) return;
   if(HistoryDealGetInteger(deal, DEAL_ENTRY) == DEAL_ENTRY_IN)
   {
      // nivel llenado por orden stop: trailing comun al SL de este nivel
      if(TrailingComun && ContarPosiciones() > 1)
      {
         bool c = (HistoryDealGetInteger(deal, DEAL_TYPE) == DEAL_TYPE_BUY);
         double px = HistoryDealGetDouble(deal, DEAL_PRICE);
         double sl = NormalizeDouble(c ? px * (1.0 - SLPorc / 100.0) : px * (1.0 + SLPorc / 100.0), _Digits);
         IgualarStops(c, sl);
      }
      return;
   }
   if(HistoryDealGetInteger(deal, DEAL_ENTRY) != DEAL_ENTRY_OUT) return;
   CancelarPendientes();

   double   profit = HistoryDealGetDouble(deal, DEAL_PROFIT), swap = HistoryDealGetDouble(deal, DEAL_SWAP);
   double   com    = HistoryDealGetDouble(deal, DEAL_COMMISSION);
   long     reason = HistoryDealGetInteger(deal, DEAL_REASON);
   ulong    posId  = (ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID);
   datetime tClose = (datetime)HistoryDealGetInteger(deal, DEAL_TIME), tOpen = tClose;
   if(HistorySelectByPosition((long)posId))
      for(int i = 0; i < HistoryDealsTotal(); i++)
      {
         ulong d = HistoryDealGetTicket(i);
         if(HistoryDealGetInteger(d, DEAL_ENTRY) == DEAL_ENTRY_IN) { tOpen = (datetime)HistoryDealGetInteger(d, DEAL_TIME); break; }
      }
   ultimoCierre = iTime(_Symbol, PeriodoSenal, 0);   // la siguiente entrada espera a la vela siguiente
   TelemetriaClose(profit, swap, com, MotivoSalida(reason, posId), (long)(tClose - tOpen));
   OlvidarTrailed(posId);
}
//+------------------------------------------------------------------+
