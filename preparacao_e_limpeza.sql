-- ============================================================================
-- DISCIPLINA: INTRODUÇÃO A BANCOS DE DADOS (IBD) - UFMG
-- TRABALHO PRÁTICO - PARTE 2: PREPARAÇÃO E LIMPEZA DOS DADOS (SEÇÃO 5.3)
-- SGBD: PostgreSQL (Supabase)
-- ============================================================================

-- REQUISITO DE IDEMPOTÊNCIA: Limpa as tabelas finais antes de iniciar a transformação
TRUNCATE TABLE "POPULACAO_ANO" CASCADE;
TRUNCATE TABLE "PIB_MUNICIPAL" CASCADE;
TRUNCATE TABLE "IDEB" CASCADE;
TRUNCATE TABLE "municipio" CASCADE;

-- ----------------------------------------------------------------------------
-- ETAPA 1: TRATAMENTO E POVOAMENTO DA TABELA DIMENSÃO (municipio)
-- ----------------------------------------------------------------------------
-- Transforma o código do IBGE para 6 dígitos, mapeia regiões e insere na dimensão.
INSERT INTO municipio (codigo_municipio, nome_municipio, sigla_uf, regiao, area_km2)
SELECT DISTINCT ON (codigo_municipio_calc)
    codigo_municipio_calc AS codigo_municipio,
    "NM_MUN" AS nome_municipio,
    "NM_UF_SIGLA" AS sigla_uf,
    
    -- Mapeamento da região (Equivalente ao dicionário Python e .map)
    CASE 
        WHEN "NM_UF_SIGLA" IN ('AC', 'AM', 'AP', 'PA', 'RO', 'RR', 'TO') THEN 'Norte'
        WHEN "NM_UF_SIGLA" IN ('AL', 'BA', 'CE', 'MA', 'PB', 'PE', 'PI', 'RN', 'SE') THEN 'Nordeste'
        WHEN "NM_UF_SIGLA" IN ('DF', 'GO', 'MT', 'MS') THEN 'Centro-Oeste'
        WHEN "NM_UF_SIGLA" IN ('ES', 'MG', 'RJ', 'SP') THEN 'Sudeste'
        WHEN "NM_UF_SIGLA" IN ('PR', 'RS', 'SC') THEN 'Sul'
    END AS regiao,
    
    -- Adicionar a Área (Equivalente ao pd.to_numeric)
    CAST("AR_MUN_2025" AS DECIMAL) AS area_km2
FROM (
    SELECT 
        *,
        CAST(LEFT(CAST("CD_MUN" AS VARCHAR), 6) AS INTEGER) AS codigo_municipio_calc
    FROM ibge_raw
    WHERE "CD_MUN" IS NOT NULL 
) AS dados_tratados
ORDER BY codigo_municipio_calc;


-- ----------------------------------------------------------------------------
-- ETAPA 2: TRATAMENTO E POVOAMENTO DA TABELA PIB_MUNICIPAL
-- ----------------------------------------------------------------------------
-- Insere os dados brutos na tabela final, aplicando o alinhamento de 6 dígitos 
-- para garantir a integridade referencial com a tabela municipio.
INSERT INTO "PIB_MUNICIPAL" (ano, codigo_municipio, pib, pib_per_capita)
SELECT 
    CAST(ano AS INT4),
    CAST(LEFT(CAST(codigo_municipio_bruto AS VARCHAR), 6) AS INT4) AS codigo_municipio,
    CAST(pib AS FLOAT8),
    CAST(pib_per_capita AS FLOAT8)
FROM pib_raw -- Nome da sua tabela com o CSV bruto do PIB
WHERE codigo_municipio_bruto IS NOT NULL;

-- Query 2: Mantém apenas os anos ímpares de 2011 a 2023 no PIB (Alinhamento Temporal)
DELETE FROM "PIB_MUNICIPAL" 
WHERE ano NOT IN (2011, 2013, 2015, 2017, 2019, 2021, 2023);

-- Query 4: Exclusão das colunas hierárquicas e valores brutos não utilizados
-- Nota: Como o INSERT acima selecionou apenas as colunas necessárias da tabela raw, 
-- se você optou por criar a tabela PIB_MUNICIPAL com todas as colunas originalmente,
-- o comando abaixo remove os campos excedentes:
ALTER TABLE "PIB_MUNICIPAL"
    DROP COLUMN IF EXISTS "Código da Grande Região",
    DROP COLUMN IF EXISTS "Código da Unidade da Federação",
    DROP COLUMN IF EXISTS "Nome da Unidade da Federação",
    DROP COLUMN IF EXISTS "Região Metropolitana",
    DROP COLUMN IF EXISTS "Código da Mesorregião",
    DROP COLUMN IF EXISTS "Nome da Mesorregião",
    DROP COLUMN IF EXISTS "Código da Microrregião",
    DROP COLUMN IF EXISTS "Nome da Microrregião",
    DROP COLUMN IF EXISTS "Código da Região Geográfica Imediata",
    DROP COLUMN IF EXISTS "Nome da Região Geográfica Imediata",
    DROP COLUMN IF EXISTS "Município da Região Geográfica Imediata",
    DROP COLUMN IF EXISTS "Código da Região Geográfica Intermediária",
    DROP COLUMN IF EXISTS "Nome da Região Geográfica Intermediária",
    DROP COLUMN IF EXISTS "Município da Região Geográfica Intermediária",
    DROP COLUMN IF EXISTS "Código Concentração Urbana",
    DROP COLUMN IF EXISTS "Nome Concentração Urbana",
    DROP COLUMN IF EXISTS "Tipo Concentração Urbana",
    DROP COLUMN IF EXISTS "Código Arranjo Populacional",
    DROP COLUMN IF EXISTS "Nome Arranjo Populacional",
    DROP COLUMN IF EXISTS "Hierarquia Urbana",
    DROP COLUMN IF EXISTS "Hierarquia Urbana (principais categorias)",
    DROP COLUMN IF EXISTS "Código da Região Rural",
    DROP COLUMN IF EXISTS "Nome da Região Rural",
    DROP COLUMN IF EXISTS "Região rural (segundo classificação do núcleo)",
    DROP COLUMN IF EXISTS "Amazônia Legal",
    DROP COLUMN IF EXISTS "Semiárido",
    DROP COLUMN IF EXISTS "Cidade-Região de São Paulo",
    DROP COLUMN IF EXISTS "Valor adicionado bruto da Agropecuária, a preços correntes (R$ 1.000)",
    DROP COLUMN IF EXISTS "Valor adicionado bruto da Indústria, a preços correntes (R$ 1.000)",
    DROP COLUMN IF EXISTS "Valor adicionado bruto dos Serviços, a preços correntes - exceto Administração, defesa, educação e saúde públicas e seguridade social (R$ 1.000)",
    DROP COLUMN IF EXISTS "Valor adicionado bruto da Administração, defesa, educação e saúde públicas e seguridade social, a preços correntes (R$ 1.000)",
    DROP COLUMN IF EXISTS "Valor adicionado bruto total, a preços correntes (R$ 1.000)",
    DROP COLUMN IF EXISTS "Impostos, líquidos de subsídios, sobre produtos, a preços correntes (R$ 1.000)",
    DROP COLUMN IF EXISTS "Atividade com maior valor adicionado bruto",
    DROP COLUMN IF EXISTS "Atividade com segundo maior valor adicionado bruto",
    DROP COLUMN IF EXISTS "Atividade com terceiro maior valor adicionado bruto";


-- ----------------------------------------------------------------------------
-- ETAPA 3: TRATAMENTO E POVOAMENTO DA TABELA POPULACAO_ANO
-- ----------------------------------------------------------------------------
-- Insere os dados vindos do arquivo bruto de população
INSERT INTO "POPULACAO_ANO" (ano, id_municipio, populacao)
SELECT 
    CAST(ano AS INT8),
    CAST(LEFT(CAST(codigo_municipio_bruto AS VARCHAR), 6) AS INT8) AS id_municipio,
    CAST(populacao AS INT8)
FROM populacao_raw; -- Nome da sua tabela com o CSV bruto da população

-- Query 5: Remoção de anos fora do nosso escopo (mantendo apenas de 2011 a 2023)
DELETE FROM "POPULACAO_ANO"
WHERE ano NOT IN (2011, 2013, 2015, 2017, 2019, 2021, 2023);

-- Exclusão de colunas irrelevantes para manter a tabela estritamente normalizada (2FN/3FN)
ALTER TABLE "POPULACAO_ANO"
    DROP COLUMN IF EXISTS nome_municipio, 
    DROP COLUMN IF EXISTS sigla_uf;       


-- ----------------------------------------------------------------------------
-- ETAPA 4: TRATAMENTO E POVOAMENTO DA TABELA IDEB
-- ----------------------------------------------------------------------------
-- Insere a carga de dados na tabela final do IDEB
INSERT INTO "IDEB" (codigo_municipio, nu_ano, rede, indicador_rendimento, valor_ideb, valor_meta)
SELECT 
    CAST(co_municipio AS INT4),
    CAST(nu_ano AS INT8),
    TRIM(rede),
    CAST(indicador_rendimento AS FLOAT8),
    CAST(valor_ideb AS FLOAT8),
    CAST(valor_meta AS FLOAT8)
FROM ideb_raw;

-- Query 1: Remove as linhas de rodapé e possíveis valores nulos de identificação
DELETE FROM "IDEB" 
WHERE codigo_municipio IS NULL; -- Ajustado para bater com o nome da coluna do seu modelo físico

-- Query 3: Exclusão de colunas de anos antigos, notas brutas do SAEB e componentes fragmentados
ALTER TABLE "IDEB"
    DROP COLUMN IF EXISTS vl_aprovacao_2005_si_4, DROP COLUMN IF EXISTS vl_aprovacao_2005_1, DROP COLUMN IF EXISTS vl_aprovacao_2005_2, DROP COLUMN IF EXISTS vl_aprovacao_2005_3, DROP COLUMN IF EXISTS vl_aprovacao_2005_4, DROP COLUMN IF EXISTS vl_indicador_rend_2005,
    DROP COLUMN IF EXISTS vl_aprovacao_2007_si_4, DROP COLUMN IF EXISTS vl_aprovacao_2007_1, DROP COLUMN IF EXISTS vl_aprovacao_2007_2, DROP COLUMN IF EXISTS vl_aprovacao_2007_3, DROP COLUMN IF EXISTS vl_aprovacao_2007_4, DROP COLUMN IF EXISTS vl_indicador_rend_2007,
    DROP COLUMN IF EXISTS vl_aprovacao_2009_si_4, DROP COLUMN IF EXISTS vl_aprovacao_2009_1, DROP COLUMN IF EXISTS vl_aprovacao_2009_2, DROP COLUMN IF EXISTS vl_aprovacao_2009_3, DROP COLUMN IF EXISTS vl_aprovacao_2009_4, DROP COLUMN IF EXISTS vl_indicador_rend_2009,
    DROP COLUMN IF EXISTS vl_aprovacao_2011_si_4, DROP COLUMN IF EXISTS vl_aprovacao_2011_1, DROP COLUMN IF EXISTS vl_aprovacao_2011_2, DROP COLUMN IF EXISTS vl_aprovacao_2011_3, DROP COLUMN IF EXISTS vl_aprovacao_2011_4,
    DROP COLUMN IF EXISTS vl_aprovacao_2013_si_4, DROP COLUMN IF EXISTS vl_aprovacao_2013_1, DROP COLUMN IF EXISTS vl_aprovacao_2013_2, DROP COLUMN IF EXISTS vl_aprovacao_2013_3, DROP COLUMN IF EXISTS vl_aprovacao_2013_4,
    DROP COLUMN IF EXISTS vl_aprovacao_2015_si_4, DROP COLUMN IF EXISTS vl_aprovacao_2015_1, DROP COLUMN IF EXISTS vl_aprovacao_2015_2, DROP COLUMN IF EXISTS vl_aprovacao_2015_3, DROP COLUMN IF EXISTS vl_aprovacao_2015_4,
    DROP COLUMN IF EXISTS vl_aprovacao_2017_si_4, DROP COLUMN IF EXISTS vl_aprovacao_2017_1, DROP COLUMN IF EXISTS vl_aprovacao_2017_2, DROP COLUMN IF EXISTS vl_aprovacao_2017_3, DROP COLUMN IF EXISTS vl_aprovacao_2017_4,
    DROP COLUMN IF EXISTS vl_aprovacao_2019_si_4, DROP COLUMN IF EXISTS vl_aprovacao_2019_1, DROP COLUMN IF EXISTS vl_aprovacao_2019_2, DROP COLUMN IF EXISTS vl_aprovacao_2019_3, DROP COLUMN IF EXISTS vl_aprovacao_2019_4,
    DROP COLUMN IF EXISTS vl_aprovacao_2021_si_4, DROP COLUMN IF EXISTS vl_aprovacao_2021_1, DROP COLUMN IF EXISTS vl_aprovacao_2021_2, DROP COLUMN IF EXISTS vl_aprovacao_2021_3, DROP COLUMN IF EXISTS vl_aprovacao_2021_4,
    DROP COLUMN IF EXISTS vl_aprovacao_2023_si_4, DROP COLUMN IF EXISTS vl_aprovacao_2023_1, DROP COLUMN IF EXISTS vl_aprovacao_2023_2, DROP COLUMN IF EXISTS vl_aprovacao_2023_3, DROP COLUMN IF EXISTS vl_aprovacao_2023_4,
    DROP COLUMN IF EXISTS vl_nota_matematica_2005, DROP COLUMN IF EXISTS vl_nota_portugues_2005, DROP COLUMN IF EXISTS vl_nota_media_2005,
    DROP COLUMN IF EXISTS vl_nota_matematica_2007, DROP COLUMN IF EXISTS vl_nota_portugues_2007, DROP COLUMN IF EXISTS vl_nota_media_2007,
    DROP COLUMN IF EXISTS vl_nota_matematica_2009, DROP COLUMN IF EXISTS vl_nota_portugues_2009, DROP COLUMN IF EXISTS vl_nota_media_2009,
    DROP COLUMN IF EXISTS vl_nota_matematica_2011, DROP COLUMN IF EXISTS vl_nota_portugues_2011, DROP COLUMN IF EXISTS vl_nota_media_2011,
    DROP COLUMN IF EXISTS vl_nota_matematica_2013, DROP COLUMN IF EXISTS vl_nota_portugues_2013, DROP COLUMN IF EXISTS vl_nota_media_2013,
    DROP COLUMN IF EXISTS vl_nota_matematica_2015, DROP COLUMN IF EXISTS vl_nota_portugues_2015, DROP COLUMN IF EXISTS vl_nota_media_2015,
    DROP COLUMN IF EXISTS vl_nota_matematica_2017, DROP COLUMN IF EXISTS vl_nota_portugues_2017, DROP COLUMN IF EXISTS vl_nota_media_2017,
    DROP COLUMN IF EXISTS vl_nota_matematica_2019, DROP COLUMN IF EXISTS vl_nota_portugues_2019, DROP COLUMN IF EXISTS vl_nota_media_2019,
    DROP COLUMN IF EXISTS vl_nota_matematica_2021, DROP COLUMN IF EXISTS vl_nota_portugues_2021, DROP COLUMN IF EXISTS vl_nota_media_2021,
    DROP COLUMN IF EXISTS vl_nota_matematica_2023, DROP COLUMN IF EXISTS vl_nota_portugues_2023, DROP COLUMN IF EXISTS vl_nota_media_2023,
    DROP COLUMN IF EXISTS vl_observado_2005, DROP COLUMN IF EXISTS vl_observado_2007, DROP COLUMN IF EXISTS vl_observado_2009,
    DROP COLUMN IF EXISTS vl_projecao_2007, DROP COLUMN IF EXISTS vl_projecao_2009;

-- Adicional necessário: Limpa registros antigos remanescentes de anos inferiores a 2011
DELETE FROM "IDEB" 
WHERE nu_ano < 2011;


-- ----------------------------------------------------------------------------
-- ETAPA 5: CRIAÇÃO DE ATRIBUTOS DERIVADOS (REQUISITO P5)
-- ----------------------------------------------------------------------------
-- Criação da View para classificação do porte com base na população limpa
CREATE OR REPLACE VIEW view_municipios_porte AS
SELECT 
    id_municipio,
    ano,
    populacao,
    CASE 
        WHEN populacao <= 20000 THEN 'Pequeno'
        WHEN populacao > 20000 AND populacao <= 100000 THEN 'Médio'
        ELSE 'Grande'
    END AS porte_municipio
FROM "POPULACAO_ANO";