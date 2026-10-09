-- 028_candles.sql
-- Velas historicas de los indices (para backtest de nuestras propias senales).
CREATE TABLE IF NOT EXISTS public.candles (
  symbol      TEXT NOT NULL,
  granularity INT  NOT NULL,
  epoch       BIGINT NOT NULL,
  open        NUMERIC,
  high        NUMERIC,
  low         NUMERIC,
  close       NUMERIC,
  PRIMARY KEY (symbol, granularity, epoch)
);
ALTER TABLE public.candles ENABLE ROW LEVEL SECURITY;
-- solo service_role (Edge Functions) escribe/lee; sin policies
