-- 012_bridge_scalability.sql
-- Escalar bridge a 100+ usuarios: lotes, pendiente, reconciliación, índices

-- permitir estado 'pendiente' y 'cancelada'
ALTER TABLE public.auto_trade_executions DROP CONSTRAINT IF EXISTS auto_trade_executions_estado_check;
ALTER TABLE public.auto_trade_executions
  ADD CONSTRAINT auto_trade_executions_estado_check
  CHECK (estado IN ('pendiente','en_curso','ganada','perdida','rechazada','cancelada'));

-- índices para el volumen
CREATE INDEX IF NOT EXISTS idx_exec_ventana_user ON public.auto_trade_executions (ventana_id, user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_estado ON public.subscriptions (user_id, estado);
CREATE INDEX IF NOT EXISTS idx_exec_pendiente ON public.auto_trade_executions (creado_en) WHERE estado = 'pendiente';

-- incremento atómico de ganancia (evita read-then-write race condition)
CREATE OR REPLACE FUNCTION public.add_ganancia(p_user_id uuid, p_delta numeric)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.profiles
  SET ganancia_acumulada = COALESCE(ganancia_acumulada, 0) + p_delta
  WHERE id = p_user_id;
END; $$;
