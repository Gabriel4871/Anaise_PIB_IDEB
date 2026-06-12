-- ============================================================================
-- DISCIPLINA: INTRODUÇÃO A BANCOS DE DADOS (IBD) - UFMG
-- TRABALHO PRÁTICO - PARTE 1: DEFINIÇÃO DE SCHEMA E CARGA DOS DADOS
-- SGBD: PostgreSQL
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. LIMPEZA DO AMBIENTE (Garante que o script pode ser reexecutado)
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS "IDEB" CASCADE;
DROP TABLE IF EXISTS "PIB_MUNICIPAL" CASCADE;
DROP TABLE IF EXISTS "POPULACAO_ANO" CASCADE;
DROP TABLE IF EXISTS "municipio" CASCADE;

-- ----------------------------------------------------------------------------
-- 2. CRIAÇÃO DAS TABELAS (DDL)
-- ----------------------------------------------------------------------------

-- Tabela Dimensão: Municipio
CREATE TABLE "municipio" (
    codigo_municipio INT8 NOT NULL,
    nome_municipio TEXT NOT NULL,
    sigla_uf TEXT NOT NULL,
    regiao TEXT NOT NULL,
    area_km2 FLOAT8,
    CONSTRAINT pk_municipio PRIMARY KEY (codigo_municipio)
);

-- Fato/Dimensão: Populacao por Ano
CREATE TABLE "POPULACAO_ANO" (
    ano INT8 NOT NULL,
    id_municipio INT8 NOT NULL,
    populacao INT8,
    CONSTRAINT pk_populacao_ano PRIMARY KEY (ano, id_municipio),
    CONSTRAINT fk_populacao_municipio FOREIGN KEY (id_municipio) 
        REFERENCES "municipio" (codigo_municipio) ON DELETE CASCADE
);

-- Fato: IDEB
CREATE TABLE "IDEB" (
    codigo_municipio INT4 NOT NULL,
    nu_ano INT8 NOT NULL,
    rede TEXT NOT NULL,
    indicador_rendimento FLOAT8,
    valor_ideb FLOAT8,
    valor_meta FLOAT8,
    CONSTRAINT pk_ideb PRIMARY KEY (codigo_municipio, nu_ano, rede)
    -- NOTA: Se você quiser criar a FK explicitamente aqui para município:
    -- CONSTRAINT fk_ideb_municipio FOREIGN KEY (codigo_municipio) REFERENCES "municipio" (codigo_municipio)
);

-- Fato: PIB Municipal
CREATE TABLE "PIB_MUNICIPAL" (
    ano INT4 NOT NULL,
    codigo_municipio INT4 NOT NULL,
    pib FLOAT8,
    pib_per_capita FLOAT8,
    CONSTRAINT pk_pib_municipal PRIMARY KEY (ano, codigo_municipio)
);


-- ----------------------------------------------------------------------------
-- 3. CARGA DOS DADOS 
-- ----------------------------------------------------------------------------
-- IMPORTANTE: A ordem importa! Você deve carregar "municipio" primeiro, 
-- pois "POPULACAO_ANO" depende dela por causa da Chave Estrangeira (FK).

-- ----------------------------------------------------------------------------
-- CARGA DOS DADOS VIA COMANDO \COPY (Ambiente Local / Ingestão Supabase)
-- ----------------------------------------------------------------------------

-- Carga da tabela municipio
\copy "municipio" FROM '/home/dados/municipios.csv' WITH (FORMAT CSV, HEADER true, DELIMITER ',');

-- Carga da tabela POPULACAO_ANO
\copy "POPULACAO_ANO" FROM '/home/dados/populacao.csv' WITH (FORMAT CSV, HEADER true, DELIMITER ',');

-- Carga da tabela IDEB
\copy "IDEB" FROM '/home/dados/ideb.csv' WITH (FORMAT CSV, HEADER true, DELIMITER ',');

-- Carga da tabela PIB_MUNICIPAL
\copy "PIB_MUNICIPAL" FROM '/home/dados/pib_municipal.csv' WITH (FORMAT CSV, HEADER true, DELIMITER ',');


-- ----------------------------------------------------------------------------
-- 4. VALIDAÇÃO DA CARGA (Para garantir que os dados entraram)
-- ----------------------------------------------------------------------------
SELECT 'municipio' AS tabela, COUNT(*) AS total_registros FROM "municipio"
UNION ALL
SELECT 'POPULACAO_ANO', COUNT(*) FROM "POPULACAO_ANO"
UNION ALL
SELECT 'IDEB', COUNT(*) FROM "IDEB"
UNION ALL
SELECT 'PIB_MUNICIPAL', COUNT(*) FROM "PIB_MUNICIPAL";