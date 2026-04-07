# Edge Functions Setup

This folder documents the Edge Functions scaffold for the RecetasApp project.

## Created functions

- plan-inteligente
- recomendacion-puntual
- reemplazo-equivalente

## Function source path

Supabase deployable functions are in:

- supabase/functions/plan-inteligente/index.ts
- supabase/functions/recomendacion-puntual/index.ts
- supabase/functions/reemplazo-equivalente/index.ts

## Required environment variables

Set these in Supabase project secrets before deploy:

- SUPABASE_URL
- SUPABASE_SERVICE_ROLE_KEY
- SUPABASE_ANON_KEY

## Suggested deploy commands

Run from repository root once Supabase CLI is installed and logged in:

supabase functions deploy plan-inteligente --project-ref yuasobxhctmukvozmrta
supabase functions deploy recomendacion-puntual --project-ref yuasobxhctmukvozmrta
supabase functions deploy reemplazo-equivalente --project-ref yuasobxhctmukvozmrta

## Notes

- Current PostgREST in this project returned PGRST002 during analysis, so functions that call REST/RPC may fail until database service is healthy.
- The functions below are scaffolded and safe to adapt to your final business rules.
