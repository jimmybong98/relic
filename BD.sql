-- Schema-only dump for relic_quality
CREATE DATABASE IF NOT EXISTS `relic_quality`;
USE `relic_quality`;

CREATE TABLE `for07_norm` (
  `partnumber` varchar(128) NOT NULL,
  `operacao` varchar(64) NOT NULL,
  `idx_medida` int(11) NOT NULL,
  `titulo` varchar(128) NOT NULL,
  `faixa_texto` text NOT NULL,
  `instrumento` varchar(255) DEFAULT NULL,
  `minimo` double DEFAULT NULL,
  `maximo` double DEFAULT NULL,
  `nome_peca` varchar(255) DEFAULT NULL,
  `tipo_maquina` varchar(255) DEFAULT NULL,
  `cliente` varchar(255) DEFAULT NULL,
  `data_inclusao` date DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
CREATE TABLE `for09_norm` (
  `idx_medida` bigint(20) NOT NULL,
  `partnumber` varchar(128) NOT NULL,
  `operacao` varchar(64) NOT NULL,
  `tipo_maquina` varchar(128) DEFAULT NULL,
  `nome_peca` varchar(255) DEFAULT NULL,
  `data_inclusao` date DEFAULT NULL,
  `cliente` varchar(255) DEFAULT NULL,
  `titulo` varchar(128) NOT NULL,
  `faixa_texto` text NOT NULL,
  `minimo` double DEFAULT NULL,
  `maximo` double DEFAULT NULL,
  `periodicidade` varchar(128) DEFAULT NULL,
  `instrumento` varchar(255) DEFAULT NULL,
  `reprovada_abaixo` double DEFAULT NULL,
  `alerta_abaixo` double DEFAULT NULL,
  `alerta_acima` double DEFAULT NULL,
  `reprovada_acima` double DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
CREATE TABLE `maquinas` (
  `codigo` varchar(64) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `categoria` varchar(128) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
CREATE TABLE `operador_amostragem` (
  `id` bigint(20) NOT NULL,
  `os` varchar(64) NOT NULL,
  `partnumber` varchar(128) NOT NULL,
  `operacao` varchar(64) NOT NULL,
  `re_operador` varchar(64) NOT NULL,
  `observacao` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `maquina` varchar(128) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
CREATE TABLE `operador_amostragem_item` (
  `id` bigint(20) NOT NULL,
  `amostragem_id` bigint(20) NOT NULL,
  `idx_medida` int(11) NOT NULL,
  `titulo` text DEFAULT NULL,
  `instrumento` varchar(255) DEFAULT NULL,
  `faixa_texto` text DEFAULT NULL,
  `minimo` double DEFAULT NULL,
  `maximo` double DEFAULT NULL,
  `unidade` varchar(64) DEFAULT NULL,
  `periodicidade` varchar(128) DEFAULT NULL,
  `tolerancias` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`tolerancias`)),
  `escolha` varchar(128) NOT NULL,
  `status` varchar(64) DEFAULT NULL,
  `observacao` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
CREATE TABLE `operador_jornada` (
  `id` bigint(20) NOT NULL,
  `os` varchar(64) NOT NULL,
  `partnumber` varchar(128) DEFAULT NULL,
  `operacao` varchar(64) DEFAULT NULL,
  `re_operador` varchar(64) NOT NULL,
  `pausa_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
CREATE TABLE `ordem_servico` (
  `os` varchar(64) NOT NULL,
  `descricao` varchar(255) DEFAULT NULL,
  `cliente` varchar(255) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `atualizado_em` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `status` varchar(32) DEFAULT 'aberta'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
CREATE TABLE `preparador_liberacao` (
  `id` bigint(20) NOT NULL,
  `os` varchar(64) NOT NULL,
  `partnumber` varchar(128) NOT NULL,
  `operacao` varchar(64) NOT NULL,
  `re_preparador` varchar(64) NOT NULL,
  `status_geral` varchar(32) DEFAULT NULL,
  `observacao` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `maquina` varchar(128) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
CREATE TABLE `preparador_liberacao_item` (
  `id` bigint(20) NOT NULL,
  `liberacao_id` bigint(20) NOT NULL,
  `idx_medida` int(11) NOT NULL,
  `titulo` text DEFAULT NULL,
  `faixa_texto` text DEFAULT NULL,
  `minimo` double DEFAULT NULL,
  `maximo` double DEFAULT NULL,
  `unidade` varchar(64) DEFAULT NULL,
  `medicao` double DEFAULT NULL,
  `status` varchar(64) NOT NULL,
  `periodicidade` varchar(128) DEFAULT NULL,
  `instrumento` varchar(255) DEFAULT NULL,
  `observacao` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
CREATE TABLE `preparador_registro` (
  `id` bigint(20) NOT NULL,
  `os` varchar(64) NOT NULL,
  `partnumber` varchar(128) NOT NULL,
  `operacao` varchar(64) NOT NULL,
  `re_preparador` varchar(64) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `maquina` varchar(128) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
CREATE TABLE `preparador_registro_item` (
  `id` bigint(20) NOT NULL,
  `registro_id` bigint(20) NOT NULL,
  `idx_medida` int(11) NOT NULL,
  `titulo` text DEFAULT NULL,
  `faixa_texto` text DEFAULT NULL,
  `minimo` double DEFAULT NULL,
  `maximo` double DEFAULT NULL,
  `unidade` varchar(64) DEFAULT NULL,
  `medicao` text DEFAULT NULL,
  `status` varchar(64) DEFAULT NULL,
  `observacao` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
CREATE TABLE `supervisao_log` (
  `id` bigint(20) NOT NULL,
  `tabela` varchar(64) NOT NULL,
  `acao` varchar(16) NOT NULL,
  `registro_antes` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`registro_antes`)),
  `registro_depois` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL CHECK (json_valid(`registro_depois`)),
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
CREATE TABLE `usuarios` (
  `id` bigint(20) NOT NULL,
  `username` varchar(64) NOT NULL,
  `password` varchar(255) NOT NULL,
  `is_admin` tinyint(1) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
CREATE TABLE `v_dash_kpis_30d` (
`total_itens` bigint(21)
,`qtd_aprovadas` decimal(22,0)
,`qtd_alertas` decimal(22,0)
,`qtd_reprovadas` decimal(22,0)
,`pct_aprovadas` decimal(28,2)
,`pct_alertas` decimal(28,2)
,`pct_reprovadas` decimal(28,2)
);

-- --------------------------------------------------------

--
-- Estrutura stand-in para vista `v_dash_os_status_30d`
-- (Veja abaixo para a view atual)
--
CREATE TABLE `v_dash_os_status_30d` (
`os` varchar(64)
,`total_itens` bigint(21)
,`aprovadas` decimal(22,0)
,`alertas` decimal(22,0)
,`reprovadas` decimal(22,0)
,`pct_aprovadas` decimal(28,2)
,`pct_alertas` decimal(28,2)
,`pct_reprovadas` decimal(28,2)
,`last_item_at` timestamp
);

-- --------------------------------------------------------

--
-- Estrutura stand-in para vista `v_dash_preparador_itens`
-- (Veja abaixo para a view atual)
--
CREATE TABLE `v_dash_preparador_itens` (
`id` bigint(20)
,`os` varchar(64)
,`partnumber` varchar(128)
,`operacao` varchar(64)
,`idx_medida` int(11)
,`titulo` text
,`instrumento` varchar(255)
,`faixa_texto` text
,`minimo` double
,`maximo` double
,`medicao` double
,`status` varchar(64)
,`created_at` timestamp
);

-- --------------------------------------------------------

--
-- Estrutura stand-in para vista `v_dash_preparador_itens_classif`
-- (Veja abaixo para a view atual)
--
CREATE TABLE `v_dash_preparador_itens_classif` (
`id` bigint(20)
,`os` varchar(64)
,`partnumber` varchar(128)
,`operacao` varchar(64)
,`idx_medida` int(11)
,`titulo` text
,`instrumento` varchar(255)
,`faixa_texto` text
,`minimo` double
,`maximo` double
,`medicao` double
,`status` varchar(64)
,`created_at` timestamp
,`classe` varchar(9)
);

-- --------------------------------------------------------

--
-- Estrutura stand-in para vista `v_dash_recent_os`
-- (Veja abaixo para a view atual)
--
CREATE TABLE `v_dash_recent_os` (
`os` varchar(64)
,`descricao` varchar(255)
,`cliente` varchar(255)
,`atualizado_em` timestamp
);

-- --------------------------------------------------------

--
-- Estrutura stand-in para vista `v_dash_top_falhas_por_instrumento`
-- (Veja abaixo para a view atual)
--
CREATE TABLE `v_dash_top_falhas_por_instrumento` (
`instrumento` varchar(255)
,`total_itens` bigint(21)
,`reprovadas` decimal(22,0)
,`pct_reprovadas` decimal(28,2)
);

-- --------------------------------------------------------

--
-- Estrutura stand-in para vista `v_dash_top_falhas_por_titulo`
-- (Veja abaixo para a view atual)
--
CREATE TABLE `v_dash_top_falhas_por_titulo` (
`titulo` text
,`total_itens` bigint(21)
,`reprovadas` decimal(22,0)
,`pct_reprovadas` decimal(28,2)
);

-- --------------------------------------------------------

--
-- Estrutura stand-in para vista `v_for007_preparador`
-- (Veja abaixo para a view atual)
--
CREATE TABLE `v_for007_preparador` (
`os` varchar(64)
,`registro_id` bigint(20)
,`partnumber` varchar(128)
,`operacao` varchar(64)
,`re_preparador` varchar(64)
,`header_created_at` timestamp
,`idx_medida` int(11)
,`titulo` text
,`faixa_texto` text
,`minimo` double
,`maximo` double
,`unidade` varchar(64)
,`medicao` text
,`status` varchar(64)
,`observacao` text
,`item_created_at` timestamp
);

-- --------------------------------------------------------

--
-- Estrutura stand-in para vista `v_for09_operador`
-- (Veja abaixo para a view atual)
--
CREATE TABLE `v_for09_operador` (
`os` varchar(64)
,`amostragem_id` bigint(20)
,`partnumber` varchar(128)
,`operacao` varchar(64)
,`re_operador` varchar(64)
,`header_created_at` timestamp
,`idx_medida` int(11)
,`titulo` text
,`instrumento` varchar(255)
,`faixa_texto` text
,`minimo` double
,`maximo` double
,`unidade` varchar(64)
,`periodicidade` varchar(128)
,`tolerancias` longtext
,`escolha` varchar(128)
,`status` varchar(64)
,`observacao` text
,`item_created_at` timestamp
);

-- --------------------------------------------------------

--
-- Estrutura stand-in para vista `v_os_amostragens`
-- (Veja abaixo para a view atual)
--
CREATE TABLE `v_os_amostragens` (
`os` varchar(64)
,`amostragem_id` bigint(20)
,`partnumber` varchar(128)
,`operacao` varchar(64)
,`re_operador` varchar(64)
,`created_at` timestamp
);

-- --------------------------------------------------------

--
-- Estrutura stand-in para vista `v_os_liberacoes`
-- (Veja abaixo para a view atual)
--
CREATE TABLE `v_os_liberacoes` (
`os` varchar(64)
,`liberacao_id` bigint(20)
,`partnumber` varchar(128)
,`operacao` varchar(64)
,`re_preparador` varchar(64)
,`status_geral` varchar(32)
,`created_at` timestamp
);

-- --------------------------------------------------------

--
-- Estrutura para vista `v_dash_kpis_30d`
--
DROP TABLE IF EXISTS `v_dash_kpis_30d`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `v_dash_kpis_30d`  AS SELECT count(0) AS `total_itens`, sum(case when `v_dash_preparador_itens_classif`.`classe` = 'aprovada' then 1 else 0 end) AS `qtd_aprovadas`, sum(case when `v_dash_preparador_itens_classif`.`classe` = 'alerta' then 1 else 0 end) AS `qtd_alertas`, sum(case when `v_dash_preparador_itens_classif`.`classe` = 'reprovada' then 1 else 0 end) AS `qtd_reprovadas`, round(100.0 * sum(case when `v_dash_preparador_itens_classif`.`classe` = 'aprovada' then 1 else 0 end) / nullif(count(0),0),2) AS `pct_aprovadas`, round(100.0 * sum(case when `v_dash_preparador_itens_classif`.`classe` = 'alerta' then 1 else 0 end) / nullif(count(0),0),2) AS `pct_alertas`, round(100.0 * sum(case when `v_dash_preparador_itens_classif`.`classe` = 'reprovada' then 1 else 0 end) / nullif(count(0),0),2) AS `pct_reprovadas` FROM `v_dash_preparador_itens_classif` WHERE `v_dash_preparador_itens_classif`.`created_at` >= curdate() - interval 30 day ;

-- --------------------------------------------------------

--
-- Estrutura para vista `v_dash_os_status_30d`
--
DROP TABLE IF EXISTS `v_dash_os_status_30d`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `v_dash_os_status_30d`  AS SELECT `v_dash_preparador_itens_classif`.`os` AS `os`, count(0) AS `total_itens`, sum(case when `v_dash_preparador_itens_classif`.`classe` = 'aprovada' then 1 else 0 end) AS `aprovadas`, sum(case when `v_dash_preparador_itens_classif`.`classe` = 'alerta' then 1 else 0 end) AS `alertas`, sum(case when `v_dash_preparador_itens_classif`.`classe` = 'reprovada' then 1 else 0 end) AS `reprovadas`, round(100.0 * sum(case when `v_dash_preparador_itens_classif`.`classe` = 'aprovada' then 1 else 0 end) / nullif(count(0),0),2) AS `pct_aprovadas`, round(100.0 * sum(case when `v_dash_preparador_itens_classif`.`classe` = 'alerta' then 1 else 0 end) / nullif(count(0),0),2) AS `pct_alertas`, round(100.0 * sum(case when `v_dash_preparador_itens_classif`.`classe` = 'reprovada' then 1 else 0 end) / nullif(count(0),0),2) AS `pct_reprovadas`, max(`v_dash_preparador_itens_classif`.`created_at`) AS `last_item_at` FROM `v_dash_preparador_itens_classif` WHERE `v_dash_preparador_itens_classif`.`created_at` >= curdate() - interval 30 day GROUP BY `v_dash_preparador_itens_classif`.`os` ORDER BY max(`v_dash_preparador_itens_classif`.`created_at`) DESC ;

-- --------------------------------------------------------

--
-- Estrutura para vista `v_dash_preparador_itens`
--
DROP TABLE IF EXISTS `v_dash_preparador_itens`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `v_dash_preparador_itens`  AS SELECT `pli`.`id` AS `id`, `pl`.`os` AS `os`, `pl`.`partnumber` AS `partnumber`, `pl`.`operacao` AS `operacao`, `pli`.`idx_medida` AS `idx_medida`, `pli`.`titulo` AS `titulo`, `pli`.`instrumento` AS `instrumento`, `pli`.`faixa_texto` AS `faixa_texto`, `pli`.`minimo` AS `minimo`, `pli`.`maximo` AS `maximo`, `pli`.`medicao` AS `medicao`, `pli`.`status` AS `status`, `pli`.`created_at` AS `created_at` FROM (`preparador_liberacao_item` `pli` join `preparador_liberacao` `pl` on(`pl`.`id` = `pli`.`liberacao_id`)) ;

-- --------------------------------------------------------

--
-- Estrutura para vista `v_dash_preparador_itens_classif`
--
DROP TABLE IF EXISTS `v_dash_preparador_itens_classif`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `v_dash_preparador_itens_classif`  AS SELECT `v_dash_preparador_itens`.`id` AS `id`, `v_dash_preparador_itens`.`os` AS `os`, `v_dash_preparador_itens`.`partnumber` AS `partnumber`, `v_dash_preparador_itens`.`operacao` AS `operacao`, `v_dash_preparador_itens`.`idx_medida` AS `idx_medida`, `v_dash_preparador_itens`.`titulo` AS `titulo`, `v_dash_preparador_itens`.`instrumento` AS `instrumento`, `v_dash_preparador_itens`.`faixa_texto` AS `faixa_texto`, `v_dash_preparador_itens`.`minimo` AS `minimo`, `v_dash_preparador_itens`.`maximo` AS `maximo`, `v_dash_preparador_itens`.`medicao` AS `medicao`, `v_dash_preparador_itens`.`status` AS `status`, `v_dash_preparador_itens`.`created_at` AS `created_at`, CASE WHEN lcase(`v_dash_preparador_itens`.`status`) like 'reprovada_%' THEN 'reprovada' WHEN lcase(`v_dash_preparador_itens`.`status`) = 'alerta' THEN 'alerta' WHEN lcase(`v_dash_preparador_itens`.`status`) in ('aprovada','ok','conforme') THEN 'aprovada' ELSE 'aprovada' END AS `classe` FROM `v_dash_preparador_itens` ;

-- --------------------------------------------------------

--
-- Estrutura para vista `v_dash_recent_os`
--
DROP TABLE IF EXISTS `v_dash_recent_os`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `v_dash_recent_os`  AS SELECT `ordem_servico`.`os` AS `os`, coalesce(`ordem_servico`.`descricao`,'') AS `descricao`, coalesce(`ordem_servico`.`cliente`,'') AS `cliente`, `ordem_servico`.`atualizado_em` AS `atualizado_em` FROM `ordem_servico` ORDER BY `ordem_servico`.`atualizado_em` DESC LIMIT 0, 10 ;

-- --------------------------------------------------------

--
-- Estrutura para vista `v_dash_top_falhas_por_instrumento`
--
DROP TABLE IF EXISTS `v_dash_top_falhas_por_instrumento`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `v_dash_top_falhas_por_instrumento`  AS SELECT coalesce(`v_dash_preparador_itens_classif`.`instrumento`,'(s/ instrumento)') AS `instrumento`, count(0) AS `total_itens`, sum(case when `v_dash_preparador_itens_classif`.`classe` = 'reprovada' then 1 else 0 end) AS `reprovadas`, round(100.0 * sum(case when `v_dash_preparador_itens_classif`.`classe` = 'reprovada' then 1 else 0 end) / nullif(count(0),0),2) AS `pct_reprovadas` FROM `v_dash_preparador_itens_classif` WHERE `v_dash_preparador_itens_classif`.`created_at` >= curdate() - interval 30 day GROUP BY `v_dash_preparador_itens_classif`.`instrumento` ORDER BY sum(case when `v_dash_preparador_itens_classif`.`classe` = 'reprovada' then 1 else 0 end) DESC, round(100.0 * sum(case when `v_dash_preparador_itens_classif`.`classe` = 'reprovada' then 1 else 0 end) / nullif(count(0),0),2) DESC LIMIT 0, 10 ;

-- --------------------------------------------------------

--
-- Estrutura para vista `v_dash_top_falhas_por_titulo`
--
DROP TABLE IF EXISTS `v_dash_top_falhas_por_titulo`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `v_dash_top_falhas_por_titulo`  AS SELECT `v_dash_preparador_itens_classif`.`titulo` AS `titulo`, count(0) AS `total_itens`, sum(case when `v_dash_preparador_itens_classif`.`classe` = 'reprovada' then 1 else 0 end) AS `reprovadas`, round(100.0 * sum(case when `v_dash_preparador_itens_classif`.`classe` = 'reprovada' then 1 else 0 end) / nullif(count(0),0),2) AS `pct_reprovadas` FROM `v_dash_preparador_itens_classif` WHERE `v_dash_preparador_itens_classif`.`created_at` >= curdate() - interval 30 day GROUP BY `v_dash_preparador_itens_classif`.`titulo` HAVING count(0) >= 1 ORDER BY sum(case when `v_dash_preparador_itens_classif`.`classe` = 'reprovada' then 1 else 0 end) DESC, round(100.0 * sum(case when `v_dash_preparador_itens_classif`.`classe` = 'reprovada' then 1 else 0 end) / nullif(count(0),0),2) DESC LIMIT 0, 10 ;

-- --------------------------------------------------------

--
-- Estrutura para vista `v_for007_preparador`
--
DROP TABLE IF EXISTS `v_for007_preparador`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `v_for007_preparador`  AS SELECT `r`.`os` AS `os`, `r`.`id` AS `registro_id`, `r`.`partnumber` AS `partnumber`, `r`.`operacao` AS `operacao`, `r`.`re_preparador` AS `re_preparador`, `r`.`created_at` AS `header_created_at`, `i`.`idx_medida` AS `idx_medida`, `i`.`titulo` AS `titulo`, `i`.`faixa_texto` AS `faixa_texto`, `i`.`minimo` AS `minimo`, `i`.`maximo` AS `maximo`, `i`.`unidade` AS `unidade`, `i`.`medicao` AS `medicao`, `i`.`status` AS `status`, `i`.`observacao` AS `observacao`, `i`.`created_at` AS `item_created_at` FROM (`preparador_registro` `r` join `preparador_registro_item` `i` on(`i`.`registro_id` = `r`.`id`)) ;

-- --------------------------------------------------------

--
-- Estrutura para vista `v_for09_operador`
--
DROP TABLE IF EXISTS `v_for09_operador`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `v_for09_operador`  AS SELECT `a`.`os` AS `os`, `a`.`id` AS `amostragem_id`, `a`.`partnumber` AS `partnumber`, `a`.`operacao` AS `operacao`, `a`.`re_operador` AS `re_operador`, `a`.`created_at` AS `header_created_at`, `i`.`idx_medida` AS `idx_medida`, `i`.`titulo` AS `titulo`, `i`.`instrumento` AS `instrumento`, `i`.`faixa_texto` AS `faixa_texto`, `i`.`minimo` AS `minimo`, `i`.`maximo` AS `maximo`, `i`.`unidade` AS `unidade`, `i`.`periodicidade` AS `periodicidade`, `i`.`tolerancias` AS `tolerancias`, `i`.`escolha` AS `escolha`, `i`.`status` AS `status`, `i`.`observacao` AS `observacao`, `i`.`created_at` AS `item_created_at` FROM (`operador_amostragem` `a` join `operador_amostragem_item` `i` on(`i`.`amostragem_id` = `a`.`id`)) ;

-- --------------------------------------------------------

--
-- Estrutura para vista `v_os_amostragens`
--
DROP TABLE IF EXISTS `v_os_amostragens`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `v_os_amostragens`  AS SELECT `a`.`os` AS `os`, `a`.`id` AS `amostragem_id`, `a`.`partnumber` AS `partnumber`, `a`.`operacao` AS `operacao`, `a`.`re_operador` AS `re_operador`, `a`.`created_at` AS `created_at` FROM `operador_amostragem` AS `a` ;

-- --------------------------------------------------------

--
-- Estrutura para vista `v_os_liberacoes`
--
DROP TABLE IF EXISTS `v_os_liberacoes`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `v_os_liberacoes`  AS SELECT `l`.`os` AS `os`, `l`.`id` AS `liberacao_id`, `l`.`partnumber` AS `partnumber`, `l`.`operacao` AS `operacao`, `l`.`re_preparador` AS `re_preparador`, `l`.`status_geral` AS `status_geral`, `l`.`created_at` AS `created_at` FROM `preparador_liberacao` AS `l` ;

--
-- Índices para tabelas despejadas
--

--
-- Índices para tabela `for07_norm`
--
ALTER TABLE `for07_norm`
  ADD PRIMARY KEY (`partnumber`,`operacao`,`idx_medida`),
  ADD KEY `idx_part_op` (`partnumber`,`operacao`),
  ADD KEY `idx_op` (`operacao`),
  ADD KEY `idx_titulo` (`titulo`);

--
-- Índices para tabela `for09_norm`
--
ALTER TABLE `for09_norm`
  ADD PRIMARY KEY (`idx_medida`),
  ADD KEY `idx_part_op` (`partnumber`,`operacao`);

--
-- Índices para tabela `maquinas`
--
ALTER TABLE `maquinas`
  ADD PRIMARY KEY (`codigo`);

--
-- Índices para tabela `operador_amostragem`
--
ALTER TABLE `operador_amostragem`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_oa_os` (`os`),
  ADD KEY `idx_oa_part_op` (`partnumber`,`operacao`),
  ADD KEY `idx_oa_created` (`created_at`);

--
-- Índices para tabela `operador_amostragem_item`
--
ALTER TABLE `operador_amostragem_item`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_oa_item` (`amostragem_id`,`idx_medida`);

--
-- Índices para tabela `operador_jornada`
--
ALTER TABLE `operador_jornada`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_oj_os` (`os`);

--
-- Índices para tabela `ordem_servico`
--
ALTER TABLE `ordem_servico`
  ADD PRIMARY KEY (`os`);

--
-- Índices para tabela `preparador_liberacao`
--
ALTER TABLE `preparador_liberacao`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_pl_os` (`os`),
  ADD KEY `idx_pl_part_op` (`partnumber`,`operacao`),
  ADD KEY `idx_pl_created` (`created_at`);

--
-- Índices para tabela `preparador_liberacao_item`
--
ALTER TABLE `preparador_liberacao_item`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_pl_item` (`liberacao_id`,`idx_medida`);

--
-- Índices para tabela `preparador_registro`
--
ALTER TABLE `preparador_registro`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_os` (`os`),
  ADD KEY `idx_part_op` (`partnumber`,`operacao`);

--
-- Índices para tabela `preparador_registro_item`
--
ALTER TABLE `preparador_registro_item`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_cab` (`registro_id`),
  ADD KEY `idx_idx` (`idx_medida`);

--
-- Índices para tabela `supervisao_log`
--
ALTER TABLE `supervisao_log`
  ADD PRIMARY KEY (`id`);

--
-- Índices para tabela `usuarios`
--
ALTER TABLE `usuarios`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `username` (`username`);

--
-- AUTO_INCREMENT de tabelas despejadas
--

--
-- AUTO_INCREMENT de tabela `operador_amostragem`
--
ALTER TABLE `operador_amostragem`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=46;

--
-- AUTO_INCREMENT de tabela `operador_amostragem_item`
--
ALTER TABLE `operador_amostragem_item`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=100;

--
-- AUTO_INCREMENT de tabela `operador_jornada`
--
ALTER TABLE `operador_jornada`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT de tabela `preparador_liberacao`
--
ALTER TABLE `preparador_liberacao`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=27;

--
-- AUTO_INCREMENT de tabela `preparador_liberacao_item`
--
ALTER TABLE `preparador_liberacao_item`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de tabela `preparador_registro`
--
ALTER TABLE `preparador_registro`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=34;

--
-- AUTO_INCREMENT de tabela `preparador_registro_item`
--
ALTER TABLE `preparador_registro_item`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=149;

--
-- AUTO_INCREMENT de tabela `supervisao_log`
--
ALTER TABLE `supervisao_log`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de tabela `usuarios`
--
ALTER TABLE `usuarios`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- Restrições para despejos de tabelas
--

--
-- Limitadores para a tabela `operador_amostragem`
--
ALTER TABLE `operador_amostragem`
  ADD CONSTRAINT `fk_oa_os` FOREIGN KEY (`os`) REFERENCES `ordem_servico` (`os`) ON UPDATE CASCADE;

--
-- Limitadores para a tabela `operador_amostragem_item`
--
ALTER TABLE `operador_amostragem_item`
  ADD CONSTRAINT `fk_oa_item_oa` FOREIGN KEY (`amostragem_id`) REFERENCES `operador_amostragem` (`id`) ON DELETE CASCADE;

--
-- Limitadores para a tabela `operador_jornada`
--
ALTER TABLE `operador_jornada`
  ADD CONSTRAINT `fk_oj_os` FOREIGN KEY (`os`) REFERENCES `ordem_servico` (`os`) ON UPDATE CASCADE;

--
-- Limitadores para a tabela `preparador_liberacao`
--
ALTER TABLE `preparador_liberacao`
  ADD CONSTRAINT `fk_pl_os` FOREIGN KEY (`os`) REFERENCES `ordem_servico` (`os`) ON UPDATE CASCADE;

--
-- Limitadores para a tabela `preparador_liberacao_item`
--
ALTER TABLE `preparador_liberacao_item`
  ADD CONSTRAINT `fk_pl_item_pl` FOREIGN KEY (`liberacao_id`) REFERENCES `preparador_liberacao` (`id`) ON DELETE CASCADE;

--
-- Limitadores para a tabela `preparador_registro`
--
ALTER TABLE `preparador_registro`
  ADD CONSTRAINT `fk_pr_os` FOREIGN KEY (`os`) REFERENCES `ordem_servico` (`os`) ON UPDATE CASCADE;

--
-- Limitadores para a tabela `preparador_registro_item`
--
ALTER TABLE `preparador_registro_item`
  ADD CONSTRAINT `fk_prep_registro` FOREIGN KEY (`registro_id`) REFERENCES `preparador_registro` (`id`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;