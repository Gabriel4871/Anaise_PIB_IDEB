-- ============================================================================
-- DISCIPLINA: INTRODUÇÃO A BANCOS DE DADOS (IBD) - UFMG
-- TRABALHO PRÁTICO - PARTE 2: ANÁLISE EXPLORATÓRIA E EXECUÇÃO DE QUERIES
-- SGBD: PostgreSQL (Supabase)
-- ============================================================================

-- ============================================================================
-- SEÇÃO 5.1: CARACTERIZAÇÃO INICIAL DOS DADOS
-- ============================================================================

-- C1 a C4: Volumetria geral e abrangência das tabelas limpas
SELECT 'município' AS tabela, COUNT(*) AS total_registros, NULL AS anos_distintos FROM "município"
UNION ALL
SELECT 'POPULACAO_ANO', COUNT(*), COUNT(DISTINCT ano) FROM "POPULACAO_ANO"
UNION ALL
SELECT 'PIB_MUNICIPAL', COUNT(*), COUNT(DISTINCT ano) FROM "PIB_MUNICIPAL"
UNION ALL
SELECT 'IDEB', COUNT(*), COUNT(DISTINCT nu_ano) FROM "IDEB";

-- C5: Visualização rápida de escala territorial
SELECT regiao, sigla_uf, COUNT(*) AS qtd_municipios 
FROM "município" 
GROUP BY regiao, sigla_uf 
ORDER BY regiao, qtd_municipios DESC;


-- ============================================================================
-- SEÇÃO 5.4: ANÁLISE DESCRITIVA DOS DADOS
-- ============================================================================

-- AD1 – Estatísticas do IDEB: Mínimo, média, mediana, máximo e desvio padrão por ano e rede
SELECT
    nu_ano,
    rede,
    ROUND(MIN("valor_IDEB")::numeric, 2)    AS minimo,
    ROUND(AVG("valor_IDEB")::numeric, 2)    AS media,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY "valor_IDEB")::numeric, 2) AS mediana,
    ROUND(MAX("valor_IDEB")::numeric, 2)    AS maximo,
    ROUND(STDDEV("valor_IDEB")::numeric, 2) AS desvio_padrao
FROM "IDEB"
WHERE "valor_IDEB" IS NOT NULL
GROUP BY nu_ano, rede
ORDER BY nu_ano, rede;


-- AD2 – Estatísticas do PIB per capita quebrado por região e ano (Otimizado com JOIN)
SELECT
    p.ano,
    m.regiao,
    ROUND(MIN(p.pib_per_capita)::numeric, 2)    AS minimo,
    ROUND(AVG(p.pib_per_capita)::numeric, 2)    AS media,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY p.pib_per_capita)::numeric, 2) AS mediana,
    ROUND(MAX(p.pib_per_capita)::numeric, 2)    AS maximo,
    ROUND(STDDEV(p.pib_per_capita)::numeric, 2) AS desvio_padrao
FROM "PIB_MUNICIPAL" p
INNER JOIN "município" m ON m.codigo_municipio = p.codigo_municipio
GROUP BY p.ano, m.regiao
ORDER BY p.ano, m.regiao;


-- AD3 – Evolução do IDEB por região comparado com a meta projetada (Otimizado com JOIN)
SELECT
    i.nu_ano AS ano,
    m.regiao,
    ROUND(AVG(i."valor_IDEB")::numeric, 2) AS ideb_medio,
    ROUND(AVG(i.valor_meta)::numeric, 2) AS meta_media
FROM "IDEB" i
INNER JOIN "município" m ON m.codigo_municipio = i.codigo_municipio
WHERE i."valor_IDEB" IS NOT NULL
GROUP BY i.nu_ano, m.regiao
ORDER BY i.nu_ano, m.regiao;


-- AD4 – Quartis de PIB: limites e média de cada faixa
WITH quartis AS (
    SELECT
        p.ano,
        p.pib_per_capita,
        NTILE(4) OVER (PARTITION BY p.ano ORDER BY p.pib_per_capita) AS quartil
    FROM "PIB_MUNICIPAL" p
)
SELECT
    ano,
    quartil,
    CASE quartil
        WHEN 1 THEN 'Q1 – Mais pobres'
        WHEN 2 THEN 'Q2 – Abaixo da mediana'
        WHEN 3 THEN 'Q3 – Acima da mediana'
        WHEN 4 THEN 'Q4 – Mais ricos'
    END AS faixa,
    COUNT(*) AS qtd_municipios,
    ROUND(MIN(pib_per_capita)::numeric, 2) AS limite_inferior,
    ROUND(MAX(pib_per_capita)::numeric, 2) AS limite_superior,
    ROUND(AVG(pib_per_capita)::numeric, 2) AS media
FROM quartis
GROUP BY ano, quartil
ORDER BY ano, quartil;


-- AD5 – Distribuição de porte por região (Otimizado utilizando a View do Script 2)
SELECT
    m.regiao,
    vp.porte_municipio AS porte,
    COUNT(*) AS qtd_municipios,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY m.regiao), 1) AS pct_na_regiao
FROM view_municipios_porte vp
INNER JOIN "município" m ON m.codigo_municipio = vp.id_municipio
GROUP BY m.regiao, vp.porte_municipio
ORDER BY m.regiao, 
    CASE vp.porte_municipio WHEN 'Pequeno' THEN 1 WHEN 'Médio' THEN 2 ELSE 3 END;


-- ============================================================================
-- SEÇÃO 5.5: ANÁLISE ORIENTADA PELOS OBJETIVOS - DETALHAMENTO DA QUESTÃO 1
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 5.5.1 Consulta 3 — IDEB médio por quartil de PIB, ano e rede (Q1A)
-- ----------------------------------------------------------------------------
WITH pib_faixas AS (
    SELECT 
        codigo_municipio,
        ano,
        pib_per_capita,
        NTILE(4) OVER (PARTITION BY ano ORDER BY pib_per_capita) AS quartil_pib
    FROM "PIB_MUNICIPAL"
)
SELECT 
    pf.quartil_pib,
    i.nu_ano AS ano,
    i.rede,
    ROUND(AVG(i."valor_IDEB")::numeric, 2) AS ideb_medio,
    ROUND(AVG(pf.pib_per_capita)::numeric, 2) AS pib_per_capita_medio
FROM pib_faixas pf
INNER JOIN "IDEB" i ON pf.codigo_municipio = i.codigo_municipio AND pf.ano = i.nu_ano
GROUP BY pf.quartil_pib, i.nu_ano, i.rede
ORDER BY i.nu_ano, pf.quartil_pib, i.rede;


-- ----------------------------------------------------------------------------
-- 5.5.2 Consulta 4 — Correlação geral PIB per capita × IDEB (Q1A - Relação Geral)
-- ----------------------------------------------------------------------------
SELECT 
    i.nu_ano AS ano,
    i.rede,
    ROUND(CORR(i."valor_IDEB", p.pib_per_capita)::numeric, 4) AS correlacao_geral,
    COUNT(*) AS total_municipios
FROM "IDEB" i
INNER JOIN "PIB_MUNICIPAL" p ON i.codigo_municipio = p.codigo_municipio AND i.nu_ano = p.ano
GROUP BY i.nu_ano, i.rede
ORDER BY i.nu_ano, i.rede;


-- ----------------------------------------------------------------------------
-- 5.5.3 Consulta 5 — Exceções: Municípios ricos (Q4) com IDEB abaixo da média (Q1B)
-- ----------------------------------------------------------------------------
WITH pib_faixas AS (
    SELECT 
        codigo_municipio, ano, pib_per_capita,
        NTILE(4) OVER (PARTITION BY ano ORDER BY pib_per_capita) AS quartil_pib
    FROM "PIB_MUNICIPAL"
),
media_nacional AS (
    SELECT nu_ano, rede, AVG("valor_IDEB") AS media_ideb
    FROM "IDEB"
    GROUP BY nu_ano, rede
)
SELECT 
    p.ano,
    m.nome_municipio,
    m.sigla_uf,
    i.rede,
    ROUND(p.pib_per_capita::numeric, 2) AS pib_per_capita,
    ROUND(i."valor_IDEB"::numeric, 2) AS valor_ideb,
    ROUND(mn.media_ideb::numeric, 2) AS media_referencia
FROM pib_faixas p
INNER JOIN "IDEB" i ON p.codigo_municipio = i.codigo_municipio AND p.ano = i.nu_ano
INNER JOIN "município" m ON m.codigo_municipio = p.codigo_municipio
INNER JOIN media_nacional mn ON mn.nu_ano = i.nu_ano AND mn.rede = i.rede
WHERE p.quartil_pib = 4 
  AND i."valor_IDEB" < mn.media_ideb
ORDER BY p.ano, (mn.media_ideb - i."valor_IDEB") DESC;


-- ----------------------------------------------------------------------------
-- 5.5.4 Consulta 6 — Exceções Inversas: Municípios pobres (Q1) acima da média
-- ----------------------------------------------------------------------------
WITH pib_faixas AS (
    SELECT 
        codigo_municipio, ano, pib_per_capita,
        NTILE(4) OVER (PARTITION BY ano ORDER BY pib_per_capita) AS quartil_pib
    FROM "PIB_MUNICIPAL"
),
media_nacional AS (
    SELECT nu_ano, rede, AVG("valor_IDEB") AS media_ideb
    FROM "IDEB"
    GROUP BY nu_ano, rede
)
SELECT 
    p.ano,
    m.nome_municipio,
    m.sigla_uf,
    i.rede,
    ROUND(p.pib_per_capita::numeric, 2) AS pib_per_capita,
    ROUND(i."valor_IDEB"::numeric, 2) AS valor_ideb,
    ROUND(mn.media_ideb::numeric, 2) AS media_referencia
FROM pib_faixas p
INNER JOIN "IDEB" i ON p.codigo_municipio = i.codigo_municipio AND p.ano = i.nu_ano
INNER JOIN "município" m ON m.codigo_municipio = p.codigo_municipio
INNER JOIN media_nacional mn ON mn.nu_ano = i.nu_ano AND mn.rede = i.rede
WHERE p.quartil_pib = 1 
  AND i."valor_IDEB" > mn.media_ideb
ORDER BY p.ano, (i."valor_IDEB" - mn.media_ideb) DESC;


-- ----------------------------------------------------------------------------
-- 5.5.5 Consulta 7 — Top 10 municípios em PIB per capita vs. ranking de IDEB
-- ----------------------------------------------------------------------------
WITH pib_ranking AS (
    SELECT 
        ano, codigo_municipio, pib_per_capita,
        ROW_NUMBER() OVER (PARTITION BY ano ORDER BY pib_per_capita DESC) AS rank_pib
    FROM "PIB_MUNICIPAL"
),
ideb_ranking AS (
    SELECT 
        nu_ano, codigo_municipio, rede, "valor_IDEB",
        ROW_NUMBER() OVER (PARTITION BY nu_ano, rede ORDER BY "valor_IDEB" DESC) AS rank_ideb
    FROM "IDEB"
)
SELECT 
    pr.ano,
    pr.rank_pib,
    m.nome_municipio,
    m.sigla_uf,
    ROUND(pr.pib_per_capita::numeric, 2) AS pib_per_capita,
    ir.rede,
    ROUND(ir."valor_IDEB"::numeric, 2) AS valor_ideb,
    ir.rank_ideb
FROM pib_ranking pr
INNER JOIN "município" m ON m.codigo_municipio = pr.codigo_municipio
LEFT JOIN ideb_ranking ir ON pr.codigo_municipio = ir.codigo_municipio AND pr.ano = ir.nu_ano
WHERE pr.rank_pib <= 10
ORDER BY pr.ano, pr.rank_pib;


-- ----------------------------------------------------------------------------
-- 5.5.6 Consulta 8 — PIB per capita médio e IDEB médio por região e ano
-- ----------------------------------------------------------------------------
SELECT 
    p.ano,
    m.regiao,
    ROUND(AVG(p.pib_per_capita)::numeric, 2) AS pib_per_capita_medio,
    ROUND(AVG(i."valor_IDEB")::numeric, 2) AS ideb_medio
FROM "PIB_MUNICIPAL" p
INNER JOIN "município" m ON m.codigo_municipio = p.codigo_municipio
LEFT JOIN "IDEB" i ON p.codigo_municipio = i.codigo_municipio AND p.ano = i.nu_ano
GROUP BY p.ano, m.regiao
ORDER BY p.ano, m.regiao;


-- ----------------------------------------------------------------------------
-- 5.5.7 Consulta 9 — Cumprimento da meta do IDEB por quartil de PIB per capita
-- ----------------------------------------------------------------------------
WITH pib_faixas AS (
    SELECT 
        codigo_municipio, ano,
        NTILE(4) OVER (PARTITION BY ano ORDER BY pib_per_capita) AS quartil_pib
    FROM "PIB_MUNICIPAL"
)
SELECT 
    pf.quartil_pib,
    COUNT(*) AS total_observacoes,
    ROUND(100.0 * COUNT(*) FILTER (WHERE i."valor_IDEB" >= i.valor_meta) / COUNT(*), 1) AS pct_atingiu_meta,
    ROUND(AVG(i."valor_IDEB" - i.valor_meta)::numeric, 2) AS gap_medio_meta
FROM pib_faixas pf
INNER JOIN "IDEB" i ON pf.codigo_municipio = i.codigo_municipio AND pf.ano = i.nu_ano
WHERE i."valor_IDEB" IS NOT NULL AND i.valor_meta IS NOT NULL
GROUP BY pf.quartil_pib
ORDER BY pf.quartil_pib;


-- ============================================================================
-- SEÇÃO 5.5: ANÁLISE ORIENTADA PELOS OBJETIVOS - DETALHAMENTO DA QUESTÃO 2
-- ============================================================================

-- Q2A – Correlação de Pearson entre PIB per Capita e IDEB por Porte Populacional
SELECT 
    vp.porte_municipio,
    ROUND(CORR(i."valor_IDEB", p.pib_per_capita)::numeric, 4) AS coeficiente_correlacao,
    COUNT(*) AS n_amostras
FROM "IDEB" i
INNER JOIN "PIB_MUNICIPAL" p ON i.codigo_municipio = p.codigo_municipio AND i.nu_ano = p.ano
INNER JOIN view_municipios_porte vp ON vp.id_municipio = p.codigo_municipio AND vp.ano = p.ano
GROUP BY vp.porte_municipio
ORDER BY coeficiente_correlacao DESC;


-- Q2B – Matriz Cruzada Porte Populacional × Quartil de PIB (IDEB Médio e Volumetria)
WITH pib_faixas AS (
    SELECT 
        codigo_municipio, ano,
        NTILE(4) OVER (PARTITION BY ano ORDER BY pib_per_capita) AS quartil_pib
    FROM "PIB_MUNICIPAL"
)
SELECT 
    vp.porte_municipio,
    pf.quartil_pib,
    ROUND(AVG(i."valor_IDEB")::numeric, 2) AS ideb_medio,
    COUNT(DISTINCT vp.id_municipio) AS qtd_municipios
FROM view_municipios_porte vp
INNER JOIN pib_faixas pf ON vp.id_municipio = pf.codigo_municipio AND vp.ano = pf.ano
INNER JOIN "IDEB" i ON vp.id_municipio = i.codigo_municipio AND vp.ano = i.nu_ano
GROUP BY vp.porte_municipio, pf.quartil_pib
ORDER BY 
    CASE vp.porte_municipio WHEN 'Pequeno' THEN 1 WHEN 'Médio' THEN 2 ELSE 3 END,
    pf.quartil_pib;


-- Q2C – Evolução Temporal do IDEB Médio por Porte Populacional (Série Histórica)
SELECT 
    i.nu_ano AS ano,
    vp.porte_municipio,
    ROUND(AVG(i."valor_IDEB")::numeric, 2) AS ideb_medio,
    ROUND(AVG(p.pib_per_capita)::numeric, 2) AS pib_per_capita_medio
FROM "IDEB" i
INNER JOIN "PIB_MUNICIPAL" p ON i.codigo_municipio = p.codigo_municipio AND i.nu_ano = p.ano
INNER JOIN view_municipios_porte vp ON vp.id_municipio = p.codigo_municipio AND vp.ano = p.ano
GROUP BY i.nu_ano, vp.porte_municipio
ORDER BY i.nu_ano, 
    CASE vp.porte_municipio WHEN 'Pequeno' THEN 1 WHEN 'Médio' THEN 2 ELSE 3 END;


-- Q2D – Cumprimento de Metas do IDEB por Porte Populacional e Gap Médio
SELECT 
    vp.porte_municipio,
    COUNT(*) AS total_observacoes,
    ROUND(100.0 * COUNT(*) FILTER (WHERE i."valor_IDEB" >= i.valor_meta) / COUNT(*), 1) AS pct_atingiu_meta,
    ROUND(AVG(i."valor_IDEB" - i.valor_meta)::numeric, 2) AS gap_medio_meta
FROM view_municipios_porte vp
INNER JOIN "IDEB" i ON vp.id_municipio = i.codigo_municipio AND vp.ano = i.nu_ano
WHERE i."valor_IDEB" IS NOT NULL AND i.valor_meta IS NOT NULL
GROUP BY vp.porte_municipio
ORDER BY pct_atingiu_meta DESC;


-- Q2E – Distribuição Geográfica de Municípios Grandes (Metrópoles) por Desempenho Educacional
WITH media_grandes AS (
    SELECT AVG(i."valor_IDEB") AS media_ideb_grandes
    FROM "IDEB" i
    INNER JOIN view_municipios_porte vp ON vp.id_municipio = i.codigo_municipio AND vp.ano = i.nu_ano
    WHERE vp.porte_municipio = 'Grande'
)
SELECT 
    m.regiao,
    COUNT(*) FILTER (WHERE i."valor_IDEB" >= mg.media_ideb_grandes) AS grandes_acima_da_media,
    COUNT(*) FILTER (WHERE i."valor_IDEB" < mg.media_ideb_grandes) AS grandes_abaixo_da_media,
    ROUND(100.0 * COUNT(*) FILTER (WHERE i."valor_IDEB" >= mg.media_ideb_grandes) / COUNT(*), 1) AS pct_sucesso
FROM "IDEB" i
INNER JOIN view_municipios_porte vp ON vp.id_municipio = i.codigo_municipio AND vp.ano = i.nu_ano
INNER JOIN "município" m ON m.codigo_municipio = i.codigo_municipio
CROSS JOIN media_grandes mg
WHERE vp.porte_municipio = 'Grande'
GROUP BY m.regiao
ORDER BY pct_sucesso DESC;