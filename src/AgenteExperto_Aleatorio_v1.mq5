//+------------------------------------------------------------------+
//|                            AgenteExperto_Aleatorio_v1.mq5         |
//|                            Instituto Quant - Primer Agente Experto|
//|                                                                  |
//|  VERSION 1 (v1) - version base, SIN gestion de riesgo:           |
//|   - Abre UNA operación de compra o de venta de forma ALEATORIA.  |
//|   - Mantiene SIEMPRE una sola posición abierta a la vez.         |
//|   - El lote es FIJO de 0.01 (no se puede aumentar por diseño).   |
//|   - NO usa Stop Loss ni Take Profit (eso llega en la v2).        |
//|                                                                  |
//|  Historial de versiones:                                         |
//|   v1.00 -> entrada aleatoria, 1 posicion, lote 0.01, sin SL/TP.  |
//|   v2.00 -> ver AgenteExperto_Aleatorio_v2_SLTP.mq5 (SL 1%/TP 2%).|
//|                                                                  |
//|  Pensado como ejemplo educativo para alumnos del Instituto Quant.|
//+------------------------------------------------------------------+
#property copyright "Instituto Quant"
#property link      ""
#property version   "1.00"
#property description "v1: abre compra o venta al azar, una sola posicion, lote fijo 0.01 (sin SL/TP)"

//--- Incluimos la librería de trading que trae MetaTrader 5.
//--- Nos da el objeto "trade" para enviar órdenes de forma sencilla.
#include <Trade\Trade.mqh>
CTrade trade;

//+------------------------------------------------------------------+
//| Parámetros configurables desde la ventana del robot             |
//+------------------------------------------------------------------+
input double InpLote        = 0.01;   // Lote fijo (no usar más de 0.01)
input ulong  InpMagicNumber = 20240616;// Número mágico (identifica al robot)
input ulong  InpSlippage    = 10;     // Desviación máxima permitida (puntos)

//+------------------------------------------------------------------+
//| Inicialización del robot                                        |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Bloqueo de seguridad: nunca permitimos más de 0.01 de lote.
   double loteUsado = InpLote;
   if(loteUsado > 0.01)
   {
      Print("Aviso: el lote configurado supera 0.01. Se fuerza a 0.01 por seguridad.");
      loteUsado = 0.01;
   }

   //--- Configuramos el objeto de trading.
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFillingBySymbol(_Symbol);

   //--- Inicializamos el generador de números aleatorios.
   MathSrand((int)GetTickCount());

   Print("Agente Experto Aleatorio v1 iniciado. Lote fijo: ", DoubleToString(loteUsado, 2));
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Finalización del robot                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("Agente Experto Aleatorio v1 detenido.");
}

//+------------------------------------------------------------------+
//| Lógica principal: se ejecuta en cada cambio de precio (tick)    |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- 1) Comprobamos si YA tenemos una posición abierta de este robot.
   //---    Si la hay, no hacemos nada: solo permitimos UNA a la vez.
   if(HayPosicionAbierta())
      return;

   //--- 2) No hay ninguna posición abierta -> abrimos una al azar.
   AbrirPosicionAleatoria();
}

//+------------------------------------------------------------------+
//| Devuelve true si este robot ya tiene una posición en el símbolo |
//+------------------------------------------------------------------+
bool HayPosicionAbierta()
{
   //--- Recorremos todas las posiciones abiertas en la cuenta.
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      //--- Nos quedamos solo con las posiciones de ESTE símbolo y ESTE robot.
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         return(true); // Ya hay una posición nuestra abierta.
      }
   }
   return(false); // No hay ninguna posición nuestra abierta.
}

//+------------------------------------------------------------------+
//| Abre una posición de COMPRA o VENTA elegida al azar             |
//+------------------------------------------------------------------+
void AbrirPosicionAleatoria()
{
   //--- Lote fijo y protegido a 0.01.
   double lote = (InpLote > 0.01) ? 0.01 : InpLote;

   //--- Elegimos al azar: número par = COMPRA, número impar = VENTA.
   //--- MathRand() devuelve un entero entre 0 y 32767.
   bool comprar = (MathRand() % 2 == 0);

   bool resultado = false;
   if(comprar)
   {
      //--- Orden de COMPRA a precio de mercado (sin SL ni TP en esta v1).
      resultado = trade.Buy(lote, _Symbol, 0.0, 0.0, 0.0, "Agente Aleatorio v1 - COMPRA");
   }
   else
   {
      //--- Orden de VENTA a precio de mercado.
      resultado = trade.Sell(lote, _Symbol, 0.0, 0.0, 0.0, "Agente Aleatorio v1 - VENTA");
   }

   //--- Informamos en el log si salió bien o mal.
   if(resultado)
      Print("Posición abierta: ", (comprar ? "COMPRA" : "VENTA"), " | Lote: ", DoubleToString(lote, 2));
   else
      Print("Error al abrir la posición. Código: ", trade.ResultRetcode(),
            " (", trade.ResultRetcodeDescription(), ")");
}
//+------------------------------------------------------------------+
