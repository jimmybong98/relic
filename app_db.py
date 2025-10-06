# app.py
from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
from pathlib import Path
from typing import List, Optional, Tuple
from collections import defaultdict
import os
import re
import json
import io
import math
import unicodedata
from decimal import Decimal
from datetime import date, datetime

from openpyxl import Workbook

# --------- MySQL ----------
import pymysql
from pymysql.cursors import DictCursor
from werkzeug.security import check_password_hash, generate_password_hash

app = Flask(__name__)
CORS(app)
app.config["JSON_AS_ASCII"] = False  # Flask 2.x
try:  # Flask 3.x
    app.json.ensure_ascii = False
except Exception:
    pass

    # FORCE 'charset=utf-8' em todas as respostas JSON


@app.after_request
def _force_utf8_json(resp):
    if resp.mimetype == "application/json":
        ct = resp.headers.get("Content-Type", "")
        if "charset" not in ct.lower():
            resp.headers["Content-Type"] = "application/json; charset=utf-8"
    return resp


# ========= DB (MySQL) =========
DB_HOST = os.getenv("DB_HOST", "192.168.0.31")
DB_PORT = int(os.getenv("DB_PORT", "3306"))
DB_USER = os.getenv("DB_USER", "relic")
DB_PASS = os.getenv("DB_PASS", "veALZ2FBnDkG749")
DB_NAME = os.getenv("DB_NAME", "relic_quality")


def _conn_db(dbname: Optional[str] = None):
    return pymysql.connect(
        host=DB_HOST,
        port=DB_PORT,
        user=DB_USER,
        password=DB_PASS,
        database=dbname,
        autocommit=False,
        cursorclass=DictCursor,
        charset="utf8mb4",
    )


def _run_sql_report(sql_path: str, dbname: str = DB_NAME):
    """Lê um arquivo .sql contendo um SELECT e retorna o resultado."""
    sql_file = Path(sql_path)
    if not sql_file.exists():
        raise FileNotFoundError(f"Arquivo SQL não encontrado: {sql_path}")
    query = sql_file.read_text(encoding="utf-8")
    with _conn_db(dbname) as conn:
        with conn.cursor() as cur:
            cur.execute(query)
            rows = cur.fetchall()
    return rows


def _sql_operador_context_filter(alias: str = "a") -> str:
    """Cláusula SQL que ignora registros de troca de ferramenta."""

    alias = alias.strip() or "operador_amostragem"
    return (
        f"(COALESCE(LOWER({alias}.contexto), '') <> 'troca_ferramenta'"
        " AND NOT EXISTS ("
        "SELECT 1 FROM operador_amostragem_item tf "
        f"WHERE tf.amostragem_id = {alias}.id "
        "AND LOWER(COALESCE(tf.observacao, '')) LIKE '%%troca de ferramenta%%')"
        ")"
    )


def _tables_exist(cur, *names) -> bool:
    """Verifica se todas as tabelas informadas existem no banco atual."""
    placeholders = ",".join(["%s"] * len(names))
    cur.execute(
        f"""
        SELECT COUNT(*) AS cnt
          FROM information_schema.tables
         WHERE table_schema = DATABASE()
           AND table_name IN ({placeholders})
        """,
        names,
    )
    return cur.fetchone()["cnt"] == len(names)


def _ensure_column(conn, table: str, column: str, definition: str) -> None:
    """Adiciona uma coluna a uma tabela se ela ainda não existir."""
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
             WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME=%s AND COLUMN_NAME=%s
            """,
            (table, column),
        )
        if not cur.fetchone():
            cur.execute(f"ALTER TABLE {table} ADD COLUMN {column} {definition}")


def _ensure_fk(conn, table: str, constraint: str, definition: str) -> None:
    """Adiciona uma constraint de chave estrangeira se ela não existir."""
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT CONSTRAINT_NAME
              FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
             WHERE TABLE_SCHEMA = DATABASE()
               AND TABLE_NAME=%s AND CONSTRAINT_NAME=%s
            """,
            (table, constraint),
        )
        if not cur.fetchone():
            cur.execute(f"ALTER TABLE {table} ADD CONSTRAINT {constraint} {definition}")


def _ensure_schema():
    """Garante que o banco e as tabelas principais existam (sem DDL agressivo)."""
    # Cria o database, se não existir
    with _conn_db(None) as c:
        with c.cursor() as cur:
            cur.execute(
                f"CREATE DATABASE IF NOT EXISTS `{DB_NAME}` "
                "CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
            )
        c.commit()

    # Cria tabelas mínimas usadas aqui (se já existem, não mexe)
    with _conn_db(DB_NAME) as c:
        with c.cursor() as cur:
            # Tabela-mestra de OS
            cur.execute(
                """
                  CREATE TABLE IF NOT EXISTS ordem_servico (
                    os VARCHAR(64) NOT NULL,
                    descricao VARCHAR(255) DEFAULT NULL,
                    cliente VARCHAR(255) DEFAULT NULL,
                    status VARCHAR(32) DEFAULT 'aberta',
                    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    atualizado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                    PRIMARY KEY (os)
                  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
                  """
            )
            _ensure_column(c, "ordem_servico", "status", "VARCHAR(32) DEFAULT 'aberta'")
            # Operador (já estava)

            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS operador_amostragem (
                    id BIGINT AUTO_INCREMENT PRIMARY KEY,
                    os VARCHAR(64) NOT NULL,
                    partnumber VARCHAR(128) NOT NULL,
                    operacao VARCHAR(64) NOT NULL,
                    re_operador VARCHAR(64) NOT NULL,
                    maquina VARCHAR(128) DEFAULT NULL,
                    observacao TEXT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    KEY idx_oa_os (os),
                    KEY idx_oa_part_op (partnumber, operacao),
                    KEY idx_oa_created (created_at),
                    CONSTRAINT fk_oa_os FOREIGN KEY (os) REFERENCES ordem_servico(os) ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
                """
            )

            cur.execute(
                """
                  CREATE TABLE IF NOT EXISTS operador_amostragem_item (

                    id BIGINT AUTO_INCREMENT PRIMARY KEY,
                    amostragem_id BIGINT NOT NULL,
                    idx_medida INT NOT NULL,
                    titulo TEXT,
                    instrumento VARCHAR(255),
                    faixa_texto TEXT,
                    minimo DOUBLE NULL,
                    maximo DOUBLE NULL,
                    unidade VARCHAR(64) NULL,
                    periodicidade VARCHAR(128) NULL,
                    tolerancias LONGTEXT
                      CHARACTER SET utf8mb4
                      COLLATE utf8mb4_bin
                      NULL,
                    escolha VARCHAR(128) NOT NULL,
                    status VARCHAR(64) NULL,
                    observacao TEXT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE KEY uq_oa_item (amostragem_id, idx_medida),
                    CONSTRAINT fk_oa_item_oa
                        FOREIGN KEY (amostragem_id)
                        REFERENCES operador_amostragem(id)

                        ON DELETE CASCADE
                  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
                  """
            )
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS operador_jornada (
                    id BIGINT AUTO_INCREMENT PRIMARY KEY,
                    os VARCHAR(64) NOT NULL,
                    partnumber VARCHAR(128) DEFAULT NULL,
                    operacao VARCHAR(64) DEFAULT NULL,
                    re_operador VARCHAR(64) NOT NULL,
                    motivo VARCHAR(128) DEFAULT NULL,
                    pausa_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    retorno_at TIMESTAMP NULL DEFAULT NULL,
                    KEY idx_oj_os (os),
                    CONSTRAINT fk_oj_os FOREIGN KEY (os) REFERENCES ordem_servico(os) ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
                """
            )
            _ensure_column(
                c, "operador_jornada", "motivo", "VARCHAR(128) DEFAULT NULL"
            )
            _ensure_column(
                c,
                "operador_jornada",
                "retorno_at",
                "TIMESTAMP NULL DEFAULT NULL",
            )
            # Preparador (registro + itens)

            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS preparador_registro (
                  id BIGINT AUTO_INCREMENT PRIMARY KEY,
                  os VARCHAR(64) NOT NULL,
                  partnumber VARCHAR(128) NOT NULL,
                  operacao VARCHAR(64) NOT NULL,
                  re_preparador VARCHAR(64) NOT NULL,
                  maquina VARCHAR(128) DEFAULT NULL,
                  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                  KEY idx_os (os),
                  KEY idx_part_op (partnumber, operacao)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
                """
            )
            _ensure_fk(
                c,
                "preparador_registro",
                "fk_pr_os",
                "FOREIGN KEY (os) REFERENCES ordem_servico(os) ON UPDATE CASCADE",
            )
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS preparador_registro_item (
                  id BIGINT AUTO_INCREMENT PRIMARY KEY,
                  registro_id BIGINT NOT NULL,
                  idx_medida INT NOT NULL,
                  titulo TEXT DEFAULT NULL,
                  faixa_texto TEXT DEFAULT NULL,
                  minimo DOUBLE DEFAULT NULL,
                  maximo DOUBLE DEFAULT NULL,
                  unidade VARCHAR(64) DEFAULT NULL,
                  medicao TEXT DEFAULT NULL,
                  status VARCHAR(64) DEFAULT NULL,
                  observacao TEXT DEFAULT NULL,
                  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                  KEY idx_cab (registro_id),
                  KEY idx_idx (idx_medida),
                  CONSTRAINT fk_prep_registro
                    FOREIGN KEY (registro_id)
                    REFERENCES preparador_registro(id)
                    ON DELETE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
                """
            )
            # Preparador (finalização + itens)
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS preparador_finalizacao (
                  id BIGINT AUTO_INCREMENT PRIMARY KEY,
                  os VARCHAR(64) NOT NULL,
                  partnumber VARCHAR(128) NOT NULL,
                  operacao VARCHAR(64) NOT NULL,
                  re_preparador VARCHAR(64) NOT NULL,
                  maquina VARCHAR(128) DEFAULT NULL,
                  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                  KEY idx_os (os),
                  KEY idx_part_op (partnumber, operacao)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
                """
            )
            _ensure_fk(
                c,
                "preparador_finalizacao",
                "fk_pf_os",
                "FOREIGN KEY (os) REFERENCES ordem_servico(os) ON UPDATE CASCADE",
            )
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS preparador_finalizacao_item (
                  id BIGINT AUTO_INCREMENT PRIMARY KEY,
                  finalizacao_id BIGINT NOT NULL,
                  idx_medida INT NOT NULL,
                  titulo TEXT DEFAULT NULL,
                  faixa_texto TEXT DEFAULT NULL,
                  minimo DOUBLE DEFAULT NULL,
                  maximo DOUBLE DEFAULT NULL,
                  unidade VARCHAR(64) DEFAULT NULL,
                  medicao TEXT DEFAULT NULL,
                  status VARCHAR(64) DEFAULT NULL,
                  observacao TEXT DEFAULT NULL,
                  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                  KEY idx_cab (finalizacao_id),
                  KEY idx_idx (idx_medida),
                  CONSTRAINT fk_pf_item
                    FOREIGN KEY (finalizacao_id)
                    REFERENCES preparador_finalizacao(id)
                    ON DELETE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
                """
            )
            # Preparador (liberação consolidada)
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS preparador_liberacao (
                  id BIGINT AUTO_INCREMENT PRIMARY KEY,
                  os VARCHAR(64) NOT NULL,
                  partnumber VARCHAR(128) NOT NULL,
                  operacao VARCHAR(64) NOT NULL,
                  re_preparador VARCHAR(64) NOT NULL,
                  maquina VARCHAR(128) DEFAULT NULL,
                  status_geral VARCHAR(32) DEFAULT NULL,
                  observacao TEXT DEFAULT NULL,
                  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                  KEY idx_pl_os (os),
                  KEY idx_pl_part_op (partnumber, operacao),
                  KEY idx_pl_created (created_at)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
                """
            )
            _ensure_fk(
                c,
                "preparador_liberacao",
                "fk_pl_os",
                "FOREIGN KEY (os) REFERENCES ordem_servico(os) ON UPDATE CASCADE",
            )
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS preparador_liberacao_item (
                  id BIGINT AUTO_INCREMENT PRIMARY KEY,
                  liberacao_id BIGINT NOT NULL,
                  idx_medida INT NOT NULL,
                  titulo TEXT DEFAULT NULL,
                  faixa_texto TEXT DEFAULT NULL,
                  minimo DOUBLE DEFAULT NULL,
                  maximo DOUBLE DEFAULT NULL,
                  unidade VARCHAR(64) DEFAULT NULL,
                  medicao DOUBLE DEFAULT NULL,
                  status VARCHAR(64) NOT NULL,
                  periodicidade VARCHAR(128) DEFAULT NULL,
                  instrumento VARCHAR(255) DEFAULT NULL,
                  observacao TEXT DEFAULT NULL,
                  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                  UNIQUE KEY uq_pl_item (liberacao_id, idx_medida),
                  CONSTRAINT fk_pl_item_pl
                    FOREIGN KEY (liberacao_id)
                    REFERENCES preparador_liberacao(id)
                    ON DELETE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
                """
            )
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS checklist_liberacao (
                  id BIGINT AUTO_INCREMENT PRIMARY KEY,
                  re VARCHAR(64) NOT NULL,
                  grupo_maquina VARCHAR(128) NOT NULL,
                  maquina VARCHAR(128) NOT NULL,
                  status VARCHAR(16) NOT NULL DEFAULT 'ativo',
                  expired_at TIMESTAMP NULL DEFAULT NULL,
                  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                  KEY idx_checklist_re (re),
                  KEY idx_checklist_maquina (maquina),
                  KEY idx_checklist_created (created_at)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
                """
            )
            _ensure_column(
                c,
                "checklist_liberacao",
                "status",
                "VARCHAR(16) NOT NULL DEFAULT 'ativo'",
            )
            _ensure_column(
                c,
                "checklist_liberacao",
                "expired_at",
                "TIMESTAMP NULL DEFAULT NULL",
            )
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS checklist_liberacao_item (
                  id BIGINT AUTO_INCREMENT PRIMARY KEY,
                  checklist_id BIGINT NOT NULL,
                  ordem INT NOT NULL,
                  grupo VARCHAR(128) NOT NULL,
                  pergunta TEXT NOT NULL,
                  resposta VARCHAR(16) NOT NULL,
                  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                  KEY idx_cl_item_checklist (checklist_id),
                  CONSTRAINT fk_cl_item_checklist
                    FOREIGN KEY (checklist_id)
                    REFERENCES checklist_liberacao(id)
                    ON DELETE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
                """
            )
            cur.execute(
                """
                  CREATE TABLE IF NOT EXISTS maquinas (
                    codigo VARCHAR(64) NOT NULL PRIMARY KEY,
                    categoria VARCHAR(128) DEFAULT NULL,
                    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
                  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
                """
            )
            cur.execute(
                """ALTER TABLE maquinas
                      ADD COLUMN IF NOT EXISTS categoria VARCHAR(128) DEFAULT NULL"""
            )
            cur.execute(
                """
                  CREATE TABLE IF NOT EXISTS supervisao_log (
                    id BIGINT AUTO_INCREMENT PRIMARY KEY,
                    tabela VARCHAR(64) NOT NULL,
                    acao VARCHAR(16) NOT NULL,
                    registro_antes JSON NULL,
                    registro_depois JSON NOT NULL,
                    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
                  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
                  """
            )
            cur.execute(
                """
                  CREATE TABLE IF NOT EXISTS for07_norm (
                    partnumber VARCHAR(128) NOT NULL,
                    operacao VARCHAR(64) NOT NULL,
                    idx_medida INT NOT NULL,
                    titulo VARCHAR(128) NOT NULL,
                    faixa_texto TEXT NOT NULL,
                    instrumento VARCHAR(255) DEFAULT NULL,
                    minimo DOUBLE DEFAULT NULL,
                    maximo DOUBLE DEFAULT NULL,
                    nome_peca VARCHAR(255) DEFAULT NULL,
                    tipo_maquina VARCHAR(255) DEFAULT NULL,
                    cliente VARCHAR(255) DEFAULT NULL,
                    data_inclusao DATE DEFAULT NULL,
                    PRIMARY KEY (partnumber, operacao, idx_medida)
                  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
                """
            )
            cur.execute(
                """
                  CREATE TABLE IF NOT EXISTS for09_norm (
                    idx_medida BIGINT NOT NULL,
                    partnumber VARCHAR(128) NOT NULL,
                    operacao VARCHAR(64) NOT NULL,
                    tipo_maquina VARCHAR(128) DEFAULT NULL,
                    nome_peca VARCHAR(255) DEFAULT NULL,
                    data_inclusao DATE DEFAULT NULL,
                    cliente VARCHAR(255) DEFAULT NULL,
                    titulo VARCHAR(128) NOT NULL,
                    faixa_texto TEXT NOT NULL,
                    minimo DOUBLE DEFAULT NULL,
                    maximo DOUBLE DEFAULT NULL,
                    periodicidade VARCHAR(128) DEFAULT NULL,
                    instrumento VARCHAR(255) DEFAULT NULL,
                    reprovada_abaixo DOUBLE DEFAULT NULL,
                    alerta_abaixo DOUBLE DEFAULT NULL,
                    alerta_acima DOUBLE DEFAULT NULL,
                    reprovada_acima DOUBLE DEFAULT NULL,
                    PRIMARY KEY (idx_medida, partnumber, operacao)
                  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
                """
            )
            # Garante coluna 'maquina' nas tabelas principais
            _ensure_column(
                c, "preparador_liberacao", "maquina", "VARCHAR(128) DEFAULT NULL"
            )
            cur.execute(
                "CREATE UNIQUE INDEX IF NOT EXISTS uq_pl_os_part_maquina "
                "ON preparador_liberacao (os, partnumber, maquina)"
            )
        _ensure_column(c, "operador_amostragem", "maquina", "VARCHAR(128) DEFAULT NULL")
        _ensure_column(
            c, "operador_amostragem", "contexto", "VARCHAR(64) DEFAULT NULL"
        )
        _ensure_column(c, "preparador_registro", "maquina", "VARCHAR(128) DEFAULT NULL")
        _ensure_column(
            c, "preparador_finalizacao", "maquina", "VARCHAR(128) DEFAULT NULL"
        )
        with c.cursor() as cur:
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS usuarios (
                  id BIGINT AUTO_INCREMENT PRIMARY KEY,
                  username VARCHAR(64) NOT NULL UNIQUE,
                  password VARCHAR(255) NOT NULL,
                  is_admin TINYINT(1) DEFAULT 0
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
                """
            )
        c.commit()


# ========= Utils =========


def _norm(text):
    return (str(text or "")).strip()


def _strip_leading_zeros(t: str) -> str:
    t = re.sub(r"^0+", "", t)
    return t or "0"


def _norm_part(text):
    """Normaliza o partnumber removendo espaços extras e zeros à esquerda."""
    t = _norm(text)
    if not t:
        return ""
    return _strip_leading_zeros(t)


def _norm_op(text):
    t = _norm(text)
    if not t:
        return ""
    return _strip_leading_zeros(t)


def _strip_side_prefix(part: str) -> str:
    """Remove prefixos de lado (LP/LNP) e retorna o status em minúsculas."""
    p = _norm(part).lower()
    if p.startswith("lp "):
        return p[3:]
    if p.startswith("lnp "):
        return p[4:]
    return p


def _to_float(s):
    try:
        return float(str(s).replace(",", ".").strip())
    except Exception:
        return None


def _serialize(obj):
    """Converte Decimals e datas para tipos compatíveis com JSON."""
    if isinstance(obj, list):
        return [_serialize(v) for v in obj]
    if isinstance(obj, dict):
        return {k: _serialize(v) for k, v in obj.items()}
    if isinstance(obj, Decimal):
        if not obj.is_finite():
            return None
        return float(obj)
    if isinstance(obj, float):
        if math.isnan(obj) or math.isinf(obj):
            return None
        return obj
    if isinstance(obj, (datetime, date)):
        return obj.isoformat()
    return obj


def _log_supervisao(cur, tabela: str, acao: str, antes, depois):
    try:
        cur.execute(
            """
            INSERT INTO supervisao_log (tabela, acao, registro_antes, registro_depois)
            VALUES (%s, %s, %s, %s)
            """,
            (
                tabela,
                acao,
                json.dumps(antes, ensure_ascii=False) if antes is not None else None,
                json.dumps(depois, ensure_ascii=False),
            ),
        )
    except Exception:
        pass


# chama ao subir
_ensure_schema()


def _normalize_text(s: str) -> str:
    t = _norm(s).lower()
    rep = {
        "á": "a",
        "à": "a",
        "ã": "a",
        "â": "a",
        "é": "e",
        "ê": "e",
        "í": "i",
        "ó": "o",
        "ô": "o",
        "õ": "o",
        "ú": "u",
        "ç": "c",
    }
    for a, b in rep.items():
        t = t.replace(a, b)
    return t


def _has_min_token(s: str) -> bool:
    t = _normalize_text(s)
    return "minimo" in t or re.search(r"\bmin\b", t) is not None


def _has_max_token(s: str) -> bool:
    t = _normalize_text(s)
    return "maximo" in t or re.search(r"\bmax\b", t) is not None


def _is_rugosidade_text(s: str) -> bool:
    t = _normalize_text(s)
    # "rug" + ("ra" ou "rz")
    return ("rug" in t) and ("ra" in t or "rz" in t)


def _first_number(s: str):
    m = re.search(r"-?\d+(?:[.,]\d+)?", str(s))
    return _to_float(m.group(0)) if m else None


def _parse_range_any(texto: str):
    """
    Extrai (min, max, unidade) com tolerância:
      - Faixas: '27,50-28,10', '27.50 ~ 28.10', '27,5 a 28,1', etc.
      - Único valor -> (v, v, uni).
      - Se houver token 'mínimo' (ou 'máximo'), respeita só um lado.
    Unidade: melhor-possível (sufixo final).
    """
    if not texto:
        return (None, None, None)
    s = str(texto)

    # Faixa
    m = re.search(
        r"(-?\d+(?:[.,]\d+)?)\s*(?:-|–|~|a|ate|até|to)\s*(-?\d+(?:[.,]\d+)?)\s*([^\d\s]+.*)?$",
        s,
        re.IGNORECASE,
    )
    if m:
        v1 = _to_float(m.group(1))
        v2 = _to_float(m.group(2))
        uni = (m.group(3) or "").strip() or None
        if v1 is not None and v2 is not None and v1 > v2:
            v1, v2 = v2, v1
        return (v1, v2, uni)
    # Único valor com possíveis tokens
    v = _first_number(s)
    uni_m = re.search(r"[a-zA-Zµ°]+[a-zA-Z0-9/%²³]*$", _norm(s))
    uni = (uni_m.group(0) if uni_m else "").strip() or None

    if v is None:
        return (None, None, None)

    has_min = _has_min_token(s)
    has_max = _has_max_token(s)
    if has_min and not has_max:
        return (v, None, uni)  # mínimo somente
    if has_max and not has_min:
        return (None, v, uni)  # máximo somente
    return (v, v, uni)  # valor exato


_ALLOWED_TABELAS = {"FOR07": "for07_norm", "FOR09": "for09_norm"}


def _resolve_tabela(nome: str):
    return _ALLOWED_TABELAS.get((nome or "").upper())


# ========= Consulta de medidas no BD =========
def _medidas_preparador_db(part: str, op: str):
    part = _norm_part(part)
    op = _norm_op(op)
    rows = []
    with _conn_db(DB_NAME) as c:
        with c.cursor() as cur:
            cur.execute(
                """
                SELECT idx_medida, titulo, faixa_texto, instrumento, minimo, maximo,
                       data_inclusao
                FROM for07_norm

                WHERE TRIM(LEADING '0' FROM TRIM(partnumber))=%s
                  AND TRIM(LEADING '0' FROM TRIM(operacao))=%s

                ORDER BY idx_medida
                """,
                (part, op),
            )
            rows = cur.fetchall()
    medidas = []
    for row in rows:
        titulo = row.get("titulo") or ""
        faixa = row.get("faixa_texto") or ""
        instrumento = row.get("instrumento") or ""
        mn = row.get("minimo")
        mx = row.get("maximo")
        uni = None
        if mn is None and mx is None:
            mn, mx, uni = _parse_range_any(faixa)
            if mn is None and mx is None:
                mn, mx, uni = _parse_range_any(titulo)
        else:
            _, _, uni = _parse_range_any(faixa)
            if uni is None:
                _, _, uni = _parse_range_any(titulo)
        if _is_rugosidade_text(titulo):
            if mn is not None and mx is not None and mn == mx:
                mx = mn
                mn = 0.0
            elif mn is None and mx is not None:
                mn = 0.0
        idx = row.get("idx_medida")
        medidas.append(
            {
                "indice": idx,
                "idx_medida": idx,
                "titulo": titulo,
                "faixaTexto": faixa,
                "min": mn,
                "max": mx,
                "unidade": uni,
                "instrumento": row.get("instrumento") or "",
                "data_inclusao": row.get("data_inclusao"),
            }
        )
    return medidas


def _normalize_title_key(text: str) -> str:
    t = _norm(text).lower()
    if not t:
        return ""
    norm = unicodedata.normalize("NFD", t)
    without_marks = "".join(
        ch for ch in norm if unicodedata.category(ch) != "Mn"
    )
    collapsed = re.sub(r"\s+", " ", without_marks)
    return collapsed.strip()


def _medidas_operador_db(part: str, op: str, os_num: Optional[str] = None):
    part = _norm_part(part)
    op = _norm_op(op)
    os_norm = _norm(os_num)
    if not os_norm:
        os_norm = None
    rows = []
    contagens_rows = []
    with _conn_db(DB_NAME) as c:
        with c.cursor() as cur:
            cur.execute(
                """
                SELECT idx_medida, titulo, faixa_texto, minimo, maximo,
                       periodicidade, instrumento, data_inclusao,
                       reprovada_abaixo, alerta_abaixo, alerta_acima, reprovada_acima
                FROM for09_norm
                WHERE TRIM(LEADING '0' FROM TRIM(partnumber))=%s
                  AND TRIM(LEADING '0' FROM TRIM(operacao))=%s

                ORDER BY idx_medida
                """,
                (part, op),
            )
            rows = cur.fetchall()
        with c.cursor() as cur:
            params = [part, op]
            filtro_os = ""
            if os_norm:
                filtro_os = " AND a.os=%s"
                params.append(os_norm)

            filtro_contexto = _sql_operador_context_filter("a")
            cur.execute(
                f"""
                SELECT i.idx_medida,
                       i.titulo,
                       i.escolha,
                       COUNT(*) AS qtd
                  FROM operador_amostragem_item i
                  JOIN operador_amostragem a ON a.id = i.amostragem_id
                 WHERE TRIM(LEADING '0' FROM TRIM(a.partnumber))=%s
                   AND TRIM(LEADING '0' FROM TRIM(a.operacao))=%s
                   AND {filtro_contexto}
                   {filtro_os}
                 GROUP BY i.idx_medida, i.titulo, i.escolha
                """,
                params,
            )
            contagens_rows = cur.fetchall()

    contagens_por_indice = defaultdict(lambda: defaultdict(int))
    contagens_por_titulo = defaultdict(lambda: defaultdict(int))
    for cnt in contagens_rows:
        idx = cnt.get("idx_medida")
        escolha = (cnt.get("escolha") or "").strip()
        titulo_key = _normalize_title_key(cnt.get("titulo"))
        qtd = int(cnt.get("qtd") or 0)
        if not escolha or qtd <= 0:
            continue
        partes = [p.strip() for p in escolha.split("|") if p.strip()]
        if not partes:
            partes = [escolha]
        for parte in partes:
            if idx is not None:
                contagens_por_indice[idx][parte] += qtd
            if titulo_key:
                contagens_por_titulo[titulo_key][parte] += qtd

    medidas = []
    for row in rows:
        idx = row.get("idx_medida")
        titulo = row.get("titulo") or ""
        faixa = row.get("faixa_texto") or ""
        mn = row.get("minimo")
        mx = row.get("maximo")
        uni = None
        if mn is None and mx is None:
            mn, mx, uni = _parse_range_any(faixa)
            if mn is None and mx is None:
                mn, mx, uni = _parse_range_any(titulo)
        else:
            _, _, uni = _parse_range_any(faixa)
            if uni is None:
                _, _, uni = _parse_range_any(titulo)
        if _is_rugosidade_text(titulo):
            if mn is not None and mx is not None and mn == mx:
                mx = mn
                mn = 0.0
            elif mn is None and mx is not None:
                mn = 0.0
        tolerancias = [
            row.get("reprovada_abaixo"),
            row.get("alerta_abaixo"),
            row.get("alerta_acima"),
            row.get("reprovada_acima"),
        ]
        tolerancias = [t for t in tolerancias if t is not None]
        raw_counts = contagens_por_indice.get(idx)
        if not raw_counts:
            raw_counts = contagens_por_titulo.get(_normalize_title_key(titulo))
        raw_counts = {k: int(v) for k, v in (raw_counts or {}).items()}
        medidas.append(
            {
                "indice": idx,
                "idx_medida": idx,
                "titulo": titulo,
                "faixaTexto": faixa,
                "min": mn,
                "max": mx,
                "unidade": uni,
                "periodicidade": row.get("periodicidade") or "",
                "instrumento": row.get("instrumento") or "",
                "tolerancias": tolerancias,
                "contagens": {k: int(v) for k, v in raw_counts.items()},
                "data_inclusao": row.get("data_inclusao"),
            }
        )
    return medidas


# ========= HELPERS DE NEGÓCIO =========
def _outra_os_em_andamento(
        conn, os_num: str, maquina: str
) -> Tuple[bool, Optional[str]]:
    os_num = _norm(os_num)
    maquina = _norm(maquina)
    if not os_num or not maquina:
        return (False, None)

    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT DISTINCT os
              FROM preparador_liberacao
             WHERE maquina=%s
               AND os<>%s
            """,
            (maquina, os_num),
        )
        outros = [row.get("os") for row in cur.fetchall() if row.get("os")]

    for outro in outros:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT status FROM ordem_servico WHERE os=%s", (outro,)
            )
            st_row = cur.fetchone()
        status = (st_row.get("status") or "").strip().lower() if st_row else ""
        if status != "encerrada":
            return (True, outro)

    return (False, None)


def _maquina_liberada(
        conn, os_num: str, part: str, op: str, maquina: str
) -> Tuple[bool, str, str]:
    """
    Retorna (liberada, fonte, detalhe).
    fonte: 'preparador_liberacao' | 'preparador_registro' | ''
    """
    os_num = _norm(os_num)
    part = _norm_part(part)
    op = _norm_op(op)
    maquina = _norm(maquina)
    if not (os_num and part and op and maquina):
        return (False, "", "Parâmetros insuficientes para validação.")

    with conn.cursor() as cur:
        cur.execute("SELECT status FROM ordem_servico WHERE os=%s", (os_num,))
        st_row = cur.fetchone()
        status_atual = ""
        if st_row:
            status_atual = (st_row.get("status") or "").strip().lower()
        if status_atual == "encerrada":
            return (False, "ordem_servico", "status=encerrada")
        if status_atual == "pausada":
            return (False, "ordem_servico", "status=pausada")
        # 1) Se existir liberação com status final, já libera

        cur.execute(
            """
            SELECT status_geral
            FROM preparador_liberacao
            WHERE os=%s

              AND TRIM(LEADING '0' FROM TRIM(partnumber))=%s
              AND maquina=%s

            ORDER BY id DESC LIMIT 1
            """,
            (os_num, part, maquina),
        )
        row = cur.fetchone()
        if row:
            st = (row.get("status_geral") or "").strip().lower()
            if st in ("liberada", "liberado", "ok", "aprovada", "aprovado"):
                return (True, "preparador_liberacao", f"status_geral={st}")
            # se há registro mas não liberada, informa
            return (False, "preparador_liberacao", f"status_geral={st or 'indefinido'}")

        # 2) Caso não tenha liberação, checa o último registro do preparador:
        cur.execute(
            """
            SELECT id
            FROM preparador_registro
            WHERE os=%s
              AND TRIM(LEADING '0' FROM TRIM(partnumber))=%s
              AND TRIM(LEADING '0' FROM TRIM(operacao))=%s
              AND maquina=%s

            ORDER BY created_at DESC, id DESC LIMIT 1
            """,
            (os_num, part, op, maquina),
        )
        reg = cur.fetchone()
        if not reg:
            return (False, "", "Sem registro do preparador para esta OS/peça/operação.")

        reg_id = reg["id"]
        cur.execute(
            """
            SELECT
              SUM(CASE WHEN LOWER(COALESCE(status,''))='ok' OR LOWER(COALESCE(status,'')) LIKE '%%aprovado%%'
                      THEN 1 ELSE 0 END) AS ok_cnt,
              COUNT(*) AS total
            FROM preparador_registro_item
            WHERE registro_id=%s
            """,
            (reg_id,),
        )
        stats = cur.fetchone() or {}
        ok_cnt = int(stats.get("ok_cnt") or 0)
        total = int(stats.get("total") or 0)
        if total > 0 and ok_cnt == total:
            return (
                True,
                "preparador_registro",
                f"registro_id={reg_id}; {ok_cnt}/{total} aprovadas",
            )
        else:
            return (
                False,
                "preparador_registro",
                f"registro_id={reg_id}; {ok_cnt}/{total} aprovadas",
            )


def _has_checklist_ativo(conn, re: Optional[str], maquina: str) -> bool:
    maquina = _norm(maquina)
    if not maquina:
        return False

    re_filtro = _norm(re) if re else None
    with conn.cursor() as cur:
        if re_filtro:
            cur.execute(
                """
                SELECT id
                  FROM checklist_liberacao
                 WHERE maquina=%s
                   AND re=%s
                   AND status='ativo'
                 ORDER BY created_at DESC
                 LIMIT 1
                """,
                (maquina, re_filtro),
            )
        else:
            cur.execute(
                """
                SELECT id
                  FROM checklist_liberacao
                 WHERE maquina=%s
                   AND status='ativo'
                 ORDER BY created_at DESC
                 LIMIT 1
                """,
                (maquina,),
            )
        return cur.fetchone() is not None


def _expirar_checklists(conn, maquina: str, re: Optional[str] = None) -> int:
    maquina = _norm(maquina)
    if not maquina:
        return 0

    re_filtro = _norm(re) if re else None
    sql = (
        """
        UPDATE checklist_liberacao
           SET status='expirado', expired_at=COALESCE(expired_at, CURRENT_TIMESTAMP)
         WHERE maquina=%s
           AND status='ativo'
        """
    )
    params: List[str] = [maquina]
    if re_filtro:
        sql += " AND re=%s"
        params.append(re_filtro)

    with conn.cursor() as cur:
        cur.execute(sql, params)
        return cur.rowcount


# ========= Rotas de Leitura =========
# ========= Supervisão =========


@app.route("/supervisor/campos")
def supervisor_campos():
    tabela = _resolve_tabela(request.args.get("tabela"))
    if not tabela:
        return jsonify({"error": "tabela inválida"}), 400
    try:
        with _conn_db(DB_NAME) as c:
            with c.cursor() as cur:
                cur.execute(f"DESCRIBE {tabela}")
                rows = cur.fetchall()
        campos = [row["Field"] for row in rows if row["Field"] != "id"]
        return jsonify(campos)
    except Exception as e:
        return jsonify({"error": f"Falha ao listar campos: {e}"}), 500


@app.route("/supervisor/registros")
def supervisor_registros():
    tabela = _resolve_tabela(request.args.get("tabela"))
    part = _norm_part(request.args.get("partnumber"))
    op = _norm_op(request.args.get("operacao"))
    if not tabela or not part or not op:
        return jsonify({"error": "parâmetros inválidos"}), 400
    try:
        with _conn_db(DB_NAME) as c:
            with c.cursor() as cur:
                cur.execute(
                    f"SELECT * FROM {tabela} WHERE TRIM(LEADING '0' FROM TRIM(partnumber))=%s AND TRIM(LEADING '0' FROM TRIM(operacao))=%s ORDER BY idx_medida",
                    (part, op),
                )
                rows = cur.fetchall()
        return jsonify(rows)
    except Exception as e:
        return jsonify({"error": f"Falha ao buscar registros: {e}"}), 500


@app.route("/supervisor/registros", methods=["POST"])
def supervisor_inserir():
    tabela = _resolve_tabela(request.args.get("tabela"))
    dados = request.get_json(silent=True) or {}
    if not tabela or not dados:
        return jsonify({"error": "dados inválidos"}), 400
    try:
        with _conn_db(DB_NAME) as c:
            with c.cursor() as cur:
                # Se o índice não for informado, calcula o próximo
                part = _norm_part(dados.get("partnumber"))
                op = _norm_op(dados.get("operacao"))
                idx = dados.get("idx_medida")
                if idx in (None, "", 0):
                    if not part or not op:
                        return (
                            jsonify(
                                {"error": "partnumber e operacao são obrigatórios"}
                            ),
                            400,
                        )
                    cur.execute(
                        f"SELECT COALESCE(MAX(idx_medida),0)+1 AS next_idx FROM {tabela} "
                        "WHERE TRIM(LEADING '0' FROM TRIM(partnumber))=%s "
                        "AND TRIM(LEADING '0' FROM TRIM(operacao))=%s",
                        (part, op),
                    )
                    dados["idx_medida"] = cur.fetchone()["next_idx"]

                cols = list(dados.keys())
                vals = [dados[k] for k in cols]
                placeholders = ", ".join(["%s"] * len(cols))
                cur.execute(
                    f"INSERT INTO {tabela} ({', '.join(cols)}) VALUES ({placeholders})",
                    vals,
                )
                _log_supervisao(cur, tabela, "insert", None, dados)
            c.commit()
        return jsonify({"status": "ok"})
    except Exception as e:
        return jsonify({"error": f"Falha ao inserir: {e}"}), 500


@app.route("/supervisor/registros", methods=["PUT"])
def supervisor_atualizar():
    tabela = _resolve_tabela(request.args.get("tabela"))
    dados = request.get_json(silent=True) or {}
    part = _norm_part(dados.get("partnumber"))
    op = _norm_op(dados.get("operacao"))
    idx = dados.get("idx_medida")
    if not tabela or not part or not op or idx is None:
        return jsonify({"error": "parâmetros obrigatórios faltando"}), 400
    updates = {
        k: v
        for k, v in dados.items()
        if k not in ("partnumber", "operacao", "idx_medida")
    }
    if not updates:
        return jsonify({"error": "sem campos para atualizar"}), 400
    try:
        with _conn_db(DB_NAME) as c:
            with c.cursor() as cur:
                cur.execute(
                    f"SELECT * FROM {tabela} WHERE TRIM(LEADING '0' FROM TRIM(partnumber))=%s AND TRIM(LEADING '0' FROM TRIM(operacao))=%s AND idx_medida=%s",
                    (part, op, idx),
                )
                antes = cur.fetchone()
                set_sql = ", ".join([f"{k}=%s" for k in updates.keys()])
                cur.execute(
                    f"UPDATE {tabela} SET {set_sql} WHERE TRIM(LEADING '0' FROM TRIM(partnumber))=%s AND TRIM(LEADING '0' FROM TRIM(operacao))=%s AND idx_medida=%s",
                    list(updates.values()) + [part, op, idx],
                    )
                _log_supervisao(
                    cur,
                    tabela,
                    "update",
                    antes,
                    {
                        **{"partnumber": part, "operacao": op, "idx_medida": idx},
                        **updates,
                    },
                )
            c.commit()
        return jsonify({"status": "ok"})
    except Exception as e:
        return jsonify({"error": f"Falha ao atualizar: {e}"}), 500


# ========= Rotas de Leitura =========
@app.route("/preparador/medidas")
def medidas_preparador():
    part = _norm_part(request.args.get("partnumber"))
    op = _norm_op(request.args.get("operacao"))
    if not part or not op:
        return (
            jsonify({"error": "Parâmetros 'partnumber' e 'operacao' são obrigatórios"}),
            400,
        )

    try:
        data = _medidas_preparador_db(part, op)
        if not data:
            return (
                jsonify(
                    {"error": "Nenhuma medida encontrada para os parâmetros informados"}
                ),
                404,
            )
        return jsonify(data)
    except Exception as e:
        return jsonify({"error": f"Falha ao consultar BD do PREPARADOR: {e}"}), 500


@app.route("/operador/medidas")
def medidas_operador():
    part = _norm_part(request.args.get("partnumber"))
    op = _norm_op(request.args.get("operacao"))
    os_num = _norm(request.args.get("os"))
    if not part or not op:
        return (
            jsonify({"error": "Parâmetros 'partnumber' e 'operacao' são obrigatórios"}),
            400,
        )

    try:
        medidas = _medidas_operador_db(part, op, os_num or None)
        if not medidas:
            return (
                jsonify(
                    {"error": "Nenhuma medida encontrada para os parâmetros informados"}
                ),
                404,
            )
        return jsonify(medidas)
    except Exception as e:
        return jsonify({"error": f"Falha ao consultar BD do OPERADOR: {e}"}), 500


# ========= Registro (MySQL): PREPARADOR =========
@app.route("/preparador/resultado", methods=["POST"])
def resultado_preparador():
    """
    Recebe o registro do PREPARADOR e grava no MySQL.
    Payload:
    {
      "os": "...", "re": "...", "partnumber": "...", "operacao": "...",
      "itens": [
        {
          "indice": 0,
          "titulo": "...",
          "faixaTexto": "...",
          "min": 1.23, "max": 4.56, "unidade": "mm",
          "medicao": "1.30",
          "status": "OK|Reprovada acima|Reprovada abaixo|Alerta acima|Alerta abaixo|pendente",
          "observacao": ""
        }, ...
      ]
    }
    (Para medições de tampão, o campo `status` envia os dois lados como
    "LP Aprovado | LNP Reprovado".)
    """

    payload = request.get_json(silent=True) or {}
    print(f"[DEBUG] /preparador/resultado recebido: {payload}", flush=True)

    os_num = _norm(payload.get("os"))
    re_prep = _norm(payload.get("re"))
    part = _norm_part(payload.get("partnumber"))
    op = _norm_op(payload.get("operacao"))
    maquina = _norm(payload.get("maquina"))
    contexto = _norm(payload.get("contexto"))
    contexto_tipo = contexto.lower()
    itens = payload.get("itens", [])

    if not os_num or not re_prep or not part or not op or not maquina:
        return (
            jsonify(
                {
                    "error": "Campos 'os', 're', 'partnumber', 'operacao' e 'maquina' são obrigatórios"
                }
            ),
            400,
        )
    if not isinstance(itens, list) or len(itens) == 0:
        return (
            jsonify({"error": "Lista 'itens' é obrigatória e não pode ser vazia"}),
            400,
        )

    try:
        with _conn_db(DB_NAME) as c:
            # Garante que as tabelas envolvidas possuam a coluna 'maquina'
            _ensure_column(
                c, "preparador_liberacao", "maquina", "VARCHAR(128) DEFAULT NULL"
            )
            _ensure_column(
                c, "operador_amostragem", "maquina", "VARCHAR(128) DEFAULT NULL"
            )
            _ensure_column(
                c, "preparador_registro", "maquina", "VARCHAR(128) DEFAULT NULL"
            )

            with c.cursor() as cur:
                cur.execute("SELECT 1 FROM maquinas WHERE codigo=%s", (maquina,))
                if not cur.fetchone():
                    return jsonify({"error": "máquina não cadastrada"}), 400
                cur.execute(
                    """
                    SELECT TRIM(LEADING '0' FROM TRIM(partnumber)) AS partnumber
                    FROM preparador_liberacao
                    WHERE os=%s
                    LIMIT 1
                    """,
                    (os_num,),
                )
                row_part = cur.fetchone()
                if row_part and row_part.get("partnumber") != part:
                    return (
                        jsonify(
                            {
                                "code": "partnumber_divergente",
                                "error": "Partnumber diferente das liberações já registradas para esta OS.",
                            }
                        ),
                        409,
                    )

            if not _has_checklist_ativo(c, re_prep, maquina):
                return (
                    jsonify(
                        {
                            "code": "checklist_obrigatorio",
                            "error": "Checklist de liberação obrigatório antes de liberar a máquina.",
                        }
                    ),
                    409,
                )

            ok, fonte, detalhe = _maquina_liberada(c, os_num, part, op, maquina)
            if ok and contexto_tipo != "troca_ferramenta":
                return (
                    jsonify(
                        {
                            "code": "ja_liberada",
                            "error": "Máquina já liberada pelo preparador. Novos registros não são permitidos.",
                            "fonte": fonte,
                            "detalhe": detalhe,
                        }
                    ),
                    409,
                )

            with c.cursor() as cur:
                cur.execute(
                    """
                    SELECT partnumber, operacao, status_geral
                    FROM preparador_liberacao
                    WHERE os=%s
                      AND TRIM(LEADING '0' FROM TRIM(partnumber))=%s
                      AND maquina=%s
                      AND status_geral IN ('liberada','liberado','ok','aprovada','aprovado')
                    ORDER BY id DESC LIMIT 1
                    """,
                    (os_num, part, maquina),
                )
                row_os = cur.fetchone()
                if row_os and contexto_tipo != "troca_ferramenta":
                    return (
                        jsonify(
                            {
                                "code": "ja_liberada",
                                "error": "OS já liberada pelo preparador. Novos registros não são permitidos.",
                                "fonte": "preparador_liberacao",
                                "detalhe": f"status_geral={row_os.get('status_geral')}",
                            }
                        ),
                        409,
                    )

                # garante OS na mestre (por causa de FKs futuras)
                cur.execute(
                    "INSERT IGNORE INTO ordem_servico (os) VALUES (%s)", (os_num,)
                )

                amostragem_id = None

                # cabeçalho
                cur.execute(
                    """
                    INSERT INTO preparador_registro (os, partnumber, operacao, re_preparador, maquina)
                    VALUES (%s, %s, %s, %s, %s)
                    """,
                    (os_num, part, op, re_prep, maquina),
                )
                registro_id = cur.lastrowid

                # itens
                parsed_items = []
                all_status = []
                for it in itens:
                    idx = int(it.get("indice", 0))
                    titulo = _norm(it.get("titulo"))
                    faixa_texto = _norm(it.get("faixaTexto"))
                    minimo = it.get("min")
                    maximo = it.get("max")
                    unidade = _norm(it.get("unidade"))
                    medicao_txt = _norm(it.get("medicao"))
                    medicao_sanitizada = medicao_txt.replace(",", ".")
                    status_original = _norm(it.get("status"))
                    status_lower = status_original.lower()
                    observacao = _norm(it.get("observacao"))
                    periodicidade = _norm(it.get("periodicidade"))
                    instrumento = _norm(it.get("instrumento"))
                    tolerancias = it.get("tolerancias", [])
                    if isinstance(tolerancias, (list, tuple)):
                        tolerancias = list(tolerancias)
                    else:
                        tolerancias = []

                    parsed = {
                        "idx": idx,
                        "titulo": titulo,
                        "faixa_texto": faixa_texto,
                        "minimo": minimo,
                        "maximo": maximo,
                        "unidade": unidade,
                        "medicao_txt": medicao_txt,
                        "medicao_sanitizada": medicao_sanitizada,
                        "medicao_float": _to_float(medicao_sanitizada),
                        "status_original": status_original,
                        "status_lower": status_lower,
                        "observacao": observacao,
                        "periodicidade": periodicidade,
                        "instrumento": instrumento,
                        "tolerancias": tolerancias,
                    }
                    parsed_items.append(parsed)

                    cur.execute(
                        """
                        INSERT INTO preparador_registro_item
                          (registro_id, idx_medida, titulo, faixa_texto, minimo, maximo, unidade,
                           medicao, status, observacao)
                        VALUES
                          (%s, %s, %s, %s, %s, %s, %s,
                           %s, %s, %s)
                        """,
                        (
                            registro_id,
                            idx,
                            titulo,
                            faixa_texto,
                            minimo,
                            maximo,
                            unidade,
                            medicao_sanitizada,
                            status_lower,
                            observacao,
                        ),
                    )
                    all_status.append(status_lower)

                # Consolida liberação
                has_reprov = any(
                    any(_strip_side_prefix(parte).startswith("reprov") for parte in s.split("|"))
                    for s in all_status
                )
                all_ok = len(all_status) > 0 and all(
                    all(_strip_side_prefix(parte) in ("ok", "aprovado") for parte in s.split("|"))
                    for s in all_status
                )
                status_geral = "Liberada" if all_ok else "Pendente"

                # upsert em preparador_liberacao e obtém id para itens
                cur.execute(
                    """
                    SELECT id FROM preparador_liberacao
                    WHERE os=%s
                      AND TRIM(LEADING '0' FROM TRIM(partnumber))=%s
                      AND maquina=%s
                    ORDER BY id DESC LIMIT 1
                    """,
                    (os_num, part, maquina),
                )
                row = cur.fetchone()
                if row:
                    cur.execute(
                        "UPDATE preparador_liberacao SET re_preparador=%s, status_geral=%s, operacao=%s, maquina=%s WHERE id=%s",
                        (re_prep, status_geral, op, maquina, row["id"]),
                    )
                    liberacao_id = row["id"]
                else:
                    cur.execute(
                        """
                        INSERT INTO preparador_liberacao
                          (os, partnumber, operacao, re_preparador, status_geral, maquina)
                        VALUES (%s, %s, %s, %s, %s, %s)
                        """,
                        (os_num, part, op, re_prep, status_geral, maquina),
                    )
                    liberacao_id = cur.lastrowid

                # guarda itens consolidados
                cur.execute(
                    "DELETE FROM preparador_liberacao_item WHERE liberacao_id=%s",
                    (liberacao_id,),
                )
                for parsed in parsed_items:
                    cur.execute(
                        """
                        INSERT INTO preparador_liberacao_item
                          (liberacao_id, idx_medida, titulo, faixa_texto, minimo, maximo, unidade,
                           medicao, status, periodicidade, instrumento, observacao)
                        VALUES
                          (%s, %s, %s, %s, %s, %s, %s,
                           %s, %s, %s, %s, %s)
                        """,
                        (
                            liberacao_id,
                            parsed["idx"],
                            parsed["titulo"],
                            parsed["faixa_texto"],
                            parsed["minimo"],
                            parsed["maximo"],
                            parsed["unidade"],
                            parsed["medicao_float"],
                            parsed["status_lower"],
                            parsed["periodicidade"] or None,
                            parsed["instrumento"] or None,
                            parsed["observacao"],
                        ),
                    )

                novo_status_os = "liberada" if all_ok else "aberta"
                cur.execute(
                    "UPDATE ordem_servico SET status=%s WHERE os=%s",
                    (novo_status_os, os_num),
                )

                if contexto_tipo == "troca_ferramenta":
                    cur.execute(
                        """
                        INSERT INTO operador_amostragem (os, partnumber, operacao, re_operador, maquina, contexto)
                        VALUES (%s, %s, %s, %s, %s, %s)
                        """,
                        (os_num, part, op, re_prep, maquina, contexto_tipo),
                    )
                    amostragem_id = cur.lastrowid

                    for parsed in parsed_items:
                        tolerancias = parsed["tolerancias"]
                        tol_txt = None
                        if tolerancias:
                            try:
                                tol_txt = json.dumps(tolerancias, ensure_ascii=False)
                            except Exception:
                                tol_txt = None

                        cur.execute(
                            """
                            INSERT INTO operador_amostragem_item
                              (amostragem_id, idx_medida, titulo, instrumento, faixa_texto,
                               minimo, maximo, unidade, periodicidade, tolerancias,
                               escolha, status, observacao)
                            VALUES
                              (%s, %s, %s, %s, %s,
                               %s, %s, %s, %s, %s,
                               %s, %s, %s)
                            """,
                            (
                                amostragem_id,
                                parsed["idx"],
                                parsed["titulo"],
                                parsed["instrumento"] or None,
                                parsed["faixa_texto"],
                                parsed["minimo"],
                                parsed["maximo"],
                                parsed["unidade"],
                                parsed["periodicidade"] or None,
                                tol_txt,
                                parsed["medicao_txt"],
                                parsed["status_original"]
                                or parsed["status_lower"],
                                parsed["observacao"] or "Troca de ferramenta",
                            ),
                        )

            c.commit()

            resposta = {
                "status": "ok",
                "registro_id": registro_id,
                "status_geral": status_geral,
            }
            if amostragem_id is not None:
                resposta["amostragem_id"] = amostragem_id

            return jsonify(resposta)

    except Exception as e:
        return jsonify({"error": f"Falha ao inserir registro do preparador: {e}"}), 500


# ========= Finalização da OS pelo Preparador =========
@app.route("/preparador/finalizar_os", methods=["POST"])
def preparador_finalizar_os():
    payload = request.get_json(silent=True) or {}
    print(f"[DEBUG] /preparador/finalizar_os recebido: {payload}", flush=True)

    os_num = _norm(payload.get("os"))
    re_prep = _norm(payload.get("re"))
    part = _norm_part(payload.get("partnumber"))
    op = _norm_op(payload.get("operacao"))
    maquina = _norm(payload.get("maquina"))
    itens = payload.get("itens", [])

    if not os_num or not re_prep or not part or not op or not maquina:
        return (
            jsonify(
                {
                    "error": "Campos 'os', 're', 'partnumber', 'operacao' e 'maquina' são obrigatórios"
                }
            ),
            400,
        )
    if not isinstance(itens, list) or len(itens) == 0:
        return (
            jsonify({"error": "Lista 'itens' é obrigatória e não pode ser vazia"}),
            400,
        )

    try:
        with _conn_db(DB_NAME) as c:
            with c.cursor() as cur:
                cur.execute("SELECT 1 FROM maquinas WHERE codigo=%s", (maquina,))
                if not cur.fetchone():
                    return jsonify({"error": "máquina não cadastrada"}), 400

                cur.execute(
                    """
                    SELECT TRIM(LEADING '0' FROM TRIM(partnumber)) AS partnumber
                    FROM preparador_liberacao
                    WHERE os=%s
                    LIMIT 1
                    """,
                    (os_num,),
                )
                row_part = cur.fetchone()
                if row_part and row_part.get("partnumber") != part:
                    return (
                        jsonify(
                            {
                                "code": "partnumber_divergente",
                                "error": "Partnumber diferente das liberações já registradas para esta OS.",
                            }
                        ),
                        409,
                    )

                cur.execute("SELECT status FROM ordem_servico WHERE os=%s", (os_num,))
                st = (cur.fetchone() or {}).get("status", "").lower()
                if st == "encerrada":
                    return (
                        jsonify(
                            {"code": "ja_finalizada", "error": "OS já finalizada."}
                        ),
                        409,
                    )
                if st != "fim_prod":
                    return (
                        jsonify(
                            {
                                "code": "producao_nao_encerrada",
                                "error": "Produção não encerrada pelo operador.",
                            }
                        ),
                        409,
                    )

                cur.execute(
                    "INSERT IGNORE INTO ordem_servico (os) VALUES (%s)", (os_num,)
                )

                cur.execute(
                    """
                    INSERT INTO preparador_finalizacao (os, partnumber, operacao, re_preparador, maquina)
                    VALUES (%s, %s, %s, %s, %s)
                    """,
                    (os_num, part, op, re_prep, maquina),
                )
                finalizacao_id = cur.lastrowid

                all_status = []
                for it in itens:
                    idx = int(it.get("indice", 0))
                    titulo = _norm(it.get("titulo"))
                    faixa_texto = _norm(it.get("faixaTexto"))
                    minimo = it.get("min")
                    maximo = it.get("max")
                    unidade = _norm(it.get("unidade"))
                    medicao = _norm(it.get("medicao"))
                    status = _norm(it.get("status")).lower()
                    observacao = _norm(it.get("observacao"))

                    cur.execute(
                        """
                        INSERT INTO preparador_finalizacao_item
                          (finalizacao_id, idx_medida, titulo, faixa_texto, minimo, maximo, unidade,
                           medicao, status, observacao)
                        VALUES
                          (%s, %s, %s, %s, %s, %s, %s,
                           %s, %s, %s)
                        """,
                        (
                            finalizacao_id,
                            idx,
                            titulo,
                            faixa_texto,
                            minimo,
                            maximo,
                            unidade,
                            medicao,
                            status,
                            observacao,
                        ),
                    )
                    all_status.append(status)

                has_reprov = any(
                    any(_strip_side_prefix(parte).startswith("reprov") for parte in s.split("|"))
                    for s in all_status
                )
                all_ok = len(all_status) > 0 and all(
                    all(_strip_side_prefix(parte) in ("ok", "aprovado") for parte in s.split("|"))
                    for s in all_status
                )
                status_geral = "Liberada" if all_ok else "Pendente"
                cur.execute(
                    "UPDATE ordem_servico SET status='encerrada' WHERE os=%s",
                    (os_num,),
                )
            c.commit()

        return jsonify(
            {
                "status": "ok",
                "registro_id": finalizacao_id,
                "status_geral": status_geral,
            }
        )
    except Exception as e:
        return jsonify({"error": f"Falha ao finalizar OS: {e}"}), 500


# ========= CHECAGEM (para UI) =========
@app.route("/operador/pode")
def operador_pode():
    """Consulta rápida: pode o operador amostrar? (máquina liberada?)"""
    os_num = _norm(request.args.get("os"))
    part = _norm_part(request.args.get("partnumber"))
    op = _norm_op(request.args.get("operacao"))
    maquina = _norm(request.args.get("maquina"))
    if not os_num or not part or not op or not maquina:
        return (
            jsonify(
                {
                    "error": "Parâmetros 'os', 'partnumber', 'operacao' e 'maquina' são obrigatórios"
                }
            ),
            400,
        )

    try:
        with _conn_db(DB_NAME) as c:
            with c.cursor() as cur:
                cur.execute("SELECT 1 FROM maquinas WHERE codigo=%s", (maquina,))
                if not cur.fetchone():
                    return jsonify({"error": "máquina não cadastrada"}), 400

            ok, fonte, detalhe = _maquina_liberada(c, os_num, part, op, maquina)
        return jsonify(
            {
                "os": os_num,
                "partnumber": part,
                "operacao": op,
                "maquina": maquina,
                "liberada": ok,
                "fonte": fonte,
                "detalhe": detalhe,
            }
        )
    except Exception as e:
        return jsonify({"error": f"Falha ao consultar liberação: {e}"}), 500


# ========= Registro (MySQL): OPERADOR =========
@app.route("/operador/registrar", methods=["POST"])
def operador_registrar():
    """
    Recebe a amostragem do Operador para gravar no MySQL.
    BLOQUEIA se máquina não estiver liberada pelo preparador.

    Payload:
    {
      "os": "...", "re": "...", "partnumber": "...", "operacao": "...",
      "itens": [
        {
          "indice": 0, "titulo": "...", "instrumento": "...",
          "faixaTexto": "...", "min": 1.23, "max": 4.56, "unidade": "mm",
          "periodicidade": "5 peças", "tolerancias": [..],
          "escolha": "OK", "status": "OK|Reprovada acima|Reprovada abaixo|Alerta acima|Alerta abaixo",
          "observacao": "..."
        }, ...
      ]
    }
    (Para medições de tampão, o campo `status` envia os dois lados como
    "LP Aprovado | LNP Reprovado".)
    """

    payload = request.get_json(silent=True) or {}

    os_num = _norm(payload.get("os"))
    re_op = _norm(payload.get("re"))
    part = _norm_part(payload.get("partnumber"))
    op = _norm_op(payload.get("operacao"))
    maquina = _norm(payload.get("maquina"))
    itens = payload.get("itens", [])
    contexto = _norm(payload.get("contexto"))
    contexto_tipo = contexto.lower() if contexto else "operador"

    # validações mínimas
    if not os_num or not re_op or not part or not op or not maquina:
        return (
            jsonify(
                {
                    "error": "Campos 'os', 're', 'partnumber', 'operacao' e 'maquina' são obrigatórios"
                }
            ),
            400,
        )
    if not isinstance(itens, list) or len(itens) == 0:
        return (
            jsonify({"error": "Lista 'itens' é obrigatória e não pode ser vazia"}),
            400,
        )

    try:
        with _conn_db(DB_NAME) as c:
            with c.cursor() as cur:
                cur.execute("SELECT 1 FROM maquinas WHERE codigo=%s", (maquina,))
                if not cur.fetchone():
                    return jsonify({"error": "máquina não cadastrada"}), 400

            if not _has_checklist_ativo(c, re_op, maquina):
                return (
                    jsonify(
                        {
                            "code": "checklist_obrigatorio",
                            "error": "Checklist de liberação obrigatório antes de registrar amostragens.",
                        }
                    ),
                    409,
                )

            titulo_idx_map = {}
            with c.cursor() as cur:
                cur.execute(
                    """
                    SELECT idx_medida, titulo
                      FROM for09_norm
                     WHERE TRIM(LEADING '0' FROM TRIM(partnumber))=%s
                       AND TRIM(LEADING '0' FROM TRIM(operacao))=%s
                    """,
                    (part, op),
                )
                for row in cur.fetchall():
                    idx_row = row.get("idx_medida")
                    titulo_row = _normalize_title_key(row.get("titulo"))
                    if idx_row is None or not titulo_row:
                        continue
                    try:
                        titulo_idx_map[titulo_row] = int(idx_row)
                    except (TypeError, ValueError):
                        continue

            # BLOQUEIO: exige liberação
            ok, fonte, detalhe = _maquina_liberada(c, os_num, part, op, maquina)
            if not ok:
                msg = _mensagem_bloqueio(os_num, part, op, maquina, fonte, detalhe)
                return (
                    jsonify(
                        {
                            "code": "liberacao_pendente",
                            "error": msg,  # amigável (mantive a chave 'error' p/ compatibilidade)
                            "fonte": fonte,
                            "detalhe": detalhe,
                        }
                    ),
                    409,
                )

            with c.cursor() as cur:
                # garante OS na mestre (FK)
                cur.execute(
                    "INSERT IGNORE INTO ordem_servico (os) VALUES (%s)", (os_num,)
                )

                # cabeçalho
                cur.execute(
                    """
                    INSERT INTO operador_amostragem (os, partnumber, operacao, re_operador, maquina, contexto)
                    VALUES (%s, %s, %s, %s, %s, %s)
                    """,
                    (os_num, part, op, re_op, maquina, contexto_tipo),
                )
                amostragem_id = cur.lastrowid

                # itens
                for it in itens:
                    raw_idx = it.get("indice")
                    idx = None
                    if isinstance(raw_idx, (int, float)):
                        idx = int(raw_idx)
                    elif raw_idx is not None:
                        try:
                            idx = int(str(raw_idx).strip())
                        except Exception:
                            idx = None

                    if idx is not None and idx < 0:
                        idx = None

                    titulo = _norm(it.get("titulo"))
                    titulo_key = _normalize_title_key(titulo)
                    if (idx is None or idx == 0) and titulo_key:
                        guessed = titulo_idx_map.get(titulo_key)
                        if guessed is not None:
                            idx = guessed
                    if idx is None:
                        idx = i

                    instrumento = _norm(it.get("instrumento"))
                    faixa_texto = _norm(it.get("faixaTexto"))
                    minimo = it.get("min")
                    maximo = it.get("max")
                    unidade = _norm(it.get("unidade"))
                    periodicidade = _norm(it.get("periodicidade"))
                    tolerancias = it.get("tolerancias", [])
                    tol_txt = None
                    if isinstance(tolerancias, (list, tuple)):
                        try:
                            tol_txt = json.dumps(tolerancias, ensure_ascii=False)
                        except Exception:
                            tol_txt = None
                    escolha = _norm(it.get("escolha"))
                    status = _norm(it.get("status"))
                    observacao = _norm(it.get("observacao"))

                    cur.execute(
                        """
                        INSERT INTO operador_amostragem_item
                          (amostragem_id, idx_medida, titulo, instrumento, faixa_texto,
                           minimo, maximo, unidade, periodicidade, tolerancias,
                           escolha, status, observacao)
                        VALUES
                          (%s, %s, %s, %s, %s,
                           %s, %s, %s, %s, %s,
                           %s, %s, %s)
                        """,
                        (
                            amostragem_id,
                            idx,
                            titulo,
                            instrumento,
                            faixa_texto,
                            minimo,
                            maximo,
                            unidade,
                            periodicidade,
                            tol_txt,
                            escolha,
                            status,
                            observacao,
                        ),
                    )

                # Ao registrar uma nova amostragem, considera-se que o operador
                # retornou de uma pausa (se havia uma aberta).
                cur.execute(
                    """
                    UPDATE operador_jornada
                       SET retorno_at = CURRENT_TIMESTAMP
                     WHERE os=%s
                       AND re_operador=%s
                       AND retorno_at IS NULL
                       AND (partnumber IS NULL OR partnumber = %s OR %s IS NULL)
                       AND (operacao IS NULL OR operacao = %s OR %s IS NULL)
                     ORDER BY pausa_at DESC
                     LIMIT 1
                    """,
                    (
                        os_num,
                        re_op,
                        part or None,
                        part or None,
                        op or None,
                        op or None,
                    ),
                )
            c.commit()

        return jsonify(
            {"status": "ok", "amostragem_id": amostragem_id, "itens": len(itens)}
        )

    except Exception as e:
        return jsonify({"error": f"Falha ao inserir amostragem: {e}"}), 500


# (Opcional) listar por OS para futuros relatórios
@app.route("/operador/amostragens")
def operador_listar():
    os_num = _norm(request.args.get("os"))
    part = _norm_part(request.args.get("partnumber"))
    op = _norm_op(request.args.get("operacao"))
    where = [_sql_operador_context_filter("a")]
    params = []
    if os_num:
        where.append("a.os = %s")
        params.append(os_num)
    if part:
        where.append("TRIM(LEADING '0' FROM a.partnumber) = TRIM(LEADING '0' FROM %s)")
        params.append(part)
    if op:
        where.append("TRIM(LEADING '0' FROM a.operacao) = TRIM(LEADING '0' FROM %s)")
        params.append(op)

    sql = """
        SELECT a.id, a.os, a.partnumber, a.operacao, a.re_operador, a.created_at
        FROM operador_amostragem a
    """
    if where:
        sql += " WHERE " + " AND ".join(where)
    sql += " ORDER BY a.created_at DESC LIMIT 200"

    try:
        with _conn_db(DB_NAME) as c:
            with c.cursor() as cur:
                cur.execute(sql, params)
                rows = cur.fetchall()
        return jsonify(rows)
    except Exception as e:
        return jsonify({"error": f"Falha ao consultar amostragens: {e}"}), 500


def _registrar_pausa_operador(
        cur,
        os_num: str,
        re_op: str,
        part: Optional[str],
        op: Optional[str],
        motivo: Optional[str],
):
    """Registra uma pausa de jornada garantindo que não haja sobreposição."""

    cur.execute("INSERT IGNORE INTO ordem_servico (os) VALUES (%s)", (os_num,))
    cur.execute(
        """
        UPDATE operador_jornada
           SET retorno_at = CURRENT_TIMESTAMP
         WHERE os=%s
           AND re_operador=%s
           AND retorno_at IS NULL
           AND (partnumber IS NULL OR partnumber = %s OR %s IS NULL)
           AND (operacao IS NULL OR operacao = %s OR %s IS NULL)
        """,
        (
            os_num,
            re_op,
            part or None,
            part or None,
            op or None,
            op or None,
        ),
    )
    cur.execute(
        """
        INSERT INTO operador_jornada (os, partnumber, operacao, re_operador, motivo)
        VALUES (%s, %s, %s, %s, %s)
        """,
        (os_num, part or None, op or None, re_op, motivo or None),
    )

    motivo_norm = (motivo or "").strip().lower()
    if motivo_norm in {
        "troca de os",
        "troca_os",
        "troca os",
        "fim do turno",
        "fim de turno",
    }:
        cur.execute(
            "UPDATE ordem_servico SET status=%s WHERE os=%s",
            ("pausada", os_num),
        )
        cur.execute(
            """
            UPDATE preparador_liberacao
               SET status_geral=%s
             WHERE os=%s
               AND LOWER(COALESCE(status_geral, '')) IN (
                   'liberada', 'liberado', 'ok', 'aprovada', 'aprovado'
               )
            """,
            ("Pausada", os_num),
        )
    elif motivo_norm in {
        "fim do turno",
        "fim_de_turno",
        "fim de turno",
        "fim turno",
    }:
        cur.execute(
            """
            SELECT id
              FROM preparador_liberacao
             WHERE os=%s
               AND LOWER(TRIM(COALESCE(status_geral, ''))) IN ('pausada', 'pausado')
        """,
            (os_num,),
        )
        pausadas = [row.get("id") for row in cur.fetchall() if row.get("id")]
        for liberacao_id in pausadas:
            cur.execute(
                """
                SELECT COALESCE(status, '') AS status
                  FROM preparador_liberacao_item
                 WHERE liberacao_id=%s
                """,
                (liberacao_id,),
            )
            status_raw = [
                (row.get("status") or "").strip().lower()
                for row in cur.fetchall()
                if (row.get("status") or "").strip()
            ]
            if not status_raw:
                novo_status = "Liberada"
            else:
                partes = []
                for status in status_raw:
                    for parte in status.split("|"):
                        partes.append(_strip_side_prefix(parte))
                all_ok = partes and all(
                    parte in ("ok", "aprovado") for parte in partes
                )
                novo_status = "Liberada" if all_ok else "Pendente"
            cur.execute(
                "UPDATE preparador_liberacao SET status_geral=%s WHERE id=%s",
                (novo_status, liberacao_id),
            )



@app.route("/operador/fim_jornada", methods=["POST"])
def operador_fim_jornada():
    payload = request.get_json(silent=True) or {}
    os_num = _norm(payload.get("os"))
    re_op = _norm(payload.get("re"))
    part = _norm_part(payload.get("partnumber"))
    op = _norm_op(payload.get("operacao"))
    motivo = _norm(payload.get("motivo"))
    maquina = _norm(payload.get("maquina"))
    if not os_num or not re_op:
        return jsonify({"error": "Campos 'os' e 're' são obrigatórios"}), 400
    if not motivo:
        return jsonify({"error": "Campo 'motivo' é obrigatório"}), 400
    try:
        with _conn_db(DB_NAME) as c:
            with c.cursor() as cur:
                _registrar_pausa_operador(cur, os_num, re_op, part, op, motivo)
                if maquina and "turno" in (motivo or "").lower():
                    _expirar_checklists(c, maquina)
            c.commit()
        return jsonify({"status": "ok"})
    except Exception as e:
        return jsonify({"error": f"Falha ao registrar fim de jornada: {e}"}), 500


@app.route("/operador/troca_os", methods=["POST"])
def operador_troca_os():
    payload = request.get_json(silent=True) or {}
    os_num = _norm(payload.get("os"))
    re_op = _norm(payload.get("re"))
    part = _norm_part(payload.get("partnumber"))
    op = _norm_op(payload.get("operacao"))
    motivo = _norm(payload.get("motivo")) or "Troca de OS"
    if not os_num or not re_op:
        return jsonify({"error": "Campos 'os' e 're' são obrigatórios"}), 400
    try:
        with _conn_db(DB_NAME) as c:
            with c.cursor() as cur:
                cur.execute("SELECT status FROM ordem_servico WHERE os=%s", (os_num,))
                st_row = cur.fetchone()
                status_atual = ""
                if st_row:
                    status_atual = (st_row.get("status") or "").strip().lower()
                    if status_atual == "encerrada":
                        return (
                            jsonify({
                                "error": "Ordem de serviço encerrada não pode ser pausada.",
                                "code": "os_encerrada",
                            }),
                            409,
                        )

                cur.execute(
                    "INSERT INTO ordem_servico (os) VALUES (%s)"
                    " ON DUPLICATE KEY UPDATE os = VALUES(os)",
                    (os_num,),
                )

                _registrar_pausa_operador(cur, os_num, re_op, part, op, motivo)
                cur.execute(
                    "UPDATE ordem_servico SET status=%s WHERE os=%s",
                    ("pausada", os_num),
                )
            c.commit()
        return jsonify(
            {
                "status": "ok",
                "motivo": motivo,
                "os_status": "pausada",
                "status_anterior": status_atual,
            }
        )
    except Exception as e:
        return jsonify({"error": f"Falha ao registrar troca de OS: {e}"}), 500


@app.route("/operador/encerrar_producao", methods=["POST"])
def operador_encerrar_producao():
    payload = request.get_json(silent=True) or {}
    os_num = _norm(payload.get("os"))
    if not os_num:
        return jsonify({"error": "Campo 'os' é obrigatório"}), 400
    try:
        with _conn_db(DB_NAME) as c:
            with c.cursor() as cur:
                filtro_contexto = _sql_operador_context_filter("operador_amostragem")
                cur.execute(
                    f"SELECT COUNT(*) AS cnt FROM operador_amostragem"
                    " WHERE os=%s AND "
                    f"{filtro_contexto}",
                    (os_num,),
                )
                if cur.fetchone()["cnt"] == 0:
                    return (
                        jsonify({"error": "Nenhum registro de amostragem encontrado"}),
                        400,
                    )
                cur.execute(
                    "UPDATE ordem_servico SET status='fim_prod' WHERE os=%s",
                    (os_num,),
                )
                if cur.rowcount == 0:
                    return jsonify({"error": "OS não encontrada"}), 404
            c.commit()
        return jsonify({"status": "ok"})
    except Exception as e:
        return jsonify({"error": f"Falha ao encerrar produção: {e}"}), 500


@app.route("/reports")
@app.route("/reports/preparador")
def listar_relatorios():
    os_num = _norm(request.args.get("os"))
    part = _norm_part(request.args.get("partnumber"))
    op = _norm_op(request.args.get("operacao"))
    try:
        with _conn_db(DB_NAME) as c:
            with c.cursor() as cur:
                if part and op:
                    combined = {}
                    if _tables_exist(
                            cur,
                            "preparador_liberacao",
                            "preparador_liberacao_item",
                    ):
                        cur.execute(
                            """
                            SELECT l.os, l.partnumber, l.operacao, l.maquina,
                                   l.re_preparador,
                                   i.idx_medida, i.titulo, i.faixa_texto,
                                   CAST(i.medicao AS CHAR) AS medicao,
                                   i.created_at
                              FROM preparador_liberacao l
                              JOIN preparador_liberacao_item i ON i.liberacao_id = l.id
                             WHERE TRIM(LEADING '0' FROM TRIM(l.partnumber)) = %s
                               AND TRIM(LEADING '0' FROM TRIM(l.operacao)) = %s
                             ORDER BY i.idx_medida, i.created_at
                            """,
                            (part, op),
                        )
                        for r in cur.fetchall():
                            key = (r["os"], r["idx_medida"])
                            combined[key] = {
                                "os": r["os"],
                                "partnumber": r["partnumber"],
                                "operacao": r["operacao"],
                                "maquina": r["maquina"],
                                "faixa_texto": r["faixa_texto"],
                                "medicao": r["medicao"],
                                "created_at": r["created_at"],
                                "re_liberacao": r["re_preparador"],
                                "re_finalizacao": "",
                            }
                    if _tables_exist(
                            cur,
                            "preparador_finalizacao",
                            "preparador_finalizacao_item",
                    ):
                        cur.execute(
                            """
                            SELECT f.os, f.partnumber, f.operacao, f.maquina,
                                   f.re_preparador,
                                   i.idx_medida, i.titulo, i.faixa_texto,
                                   CAST(i.medicao AS CHAR) AS medicao,
                                   i.created_at
                              FROM preparador_finalizacao f
                              JOIN preparador_finalizacao_item i ON i.finalizacao_id = f.id
                             WHERE TRIM(LEADING '0' FROM TRIM(f.partnumber)) = %s
                               AND TRIM(LEADING '0' FROM TRIM(f.operacao)) = %s
                             ORDER BY i.idx_medida, i.created_at
                            """,
                            (part, op),
                        )
                        for r in cur.fetchall():
                            key = (r["os"], r["idx_medida"])
                            row = combined.setdefault(
                                key,
                                {
                                    "os": r["os"],
                                    "partnumber": r["partnumber"],
                                    "operacao": r["operacao"],
                                    "maquina": r["maquina"],
                                    "faixa_texto": r["faixa_texto"],
                                    "medicao": None,
                                    "created_at": None,
                                    "re_liberacao": "",
                                },
                            )
                            row["medicao_final"] = r["medicao"]
                            row["created_at_final"] = r["created_at"]
                            row["re_finalizacao"] = r["re_preparador"]
                    rows = list(combined.values())
                else:
                    cur.execute(
                        """
                        SELECT r.os, r.partnumber, r.operacao, r.re_preparador,
                               i.idx_medida, i.titulo,
                               CAST(i.medicao AS CHAR) AS medicao,
                               i.status,
                               i.observacao, i.created_at
                          FROM preparador_registro r
                          JOIN preparador_registro_item i ON i.registro_id = r.id
                         ORDER BY i.created_at
                         LIMIT 200
                        """,
                    )
                    rows = cur.fetchall()
        return jsonify(rows)
    except Exception as e:
        return jsonify({"error": f"Falha ao consultar relatórios: {e}"}), 500


@app.route("/reports/operador")
def listar_relatorios_operador():
    os_num = _norm(request.args.get("os"))
    part = _norm_part(request.args.get("partnumber"))
    op = _norm_op(request.args.get("operacao"))

    def _map_amostragem(rows):
        mapped = []
        for r in rows:
            row = dict(r)
            row.setdefault("retorno_at", None)
            row.setdefault("motivo", "")
            row["evento"] = "amostragem"
            mapped.append(row)
        return mapped

    def _map_pausas(rows):
        mapped = []
        for r in rows:
            mapped.append(
                {
                    "os": r.get("os"),
                    "partnumber": r.get("partnumber"),
                    "operacao": r.get("operacao"),
                    "re_operador": r.get("re_operador"),
                    "maquina": None,
                    "idx_medida": None,
                    "titulo": "Pausa de Jornada",
                    "instrumento": "",
                    "faixa_texto": "",
                    "escolha": "",
                    "status": "Pausa de jornada",
                    "observacao": None,
                    "created_at": r.get("pausa_at"),
                    "retorno_at": r.get("retorno_at"),
                    "motivo": r.get("motivo"),
                    "evento": "pausa_jornada",
                }
            )
        return mapped

    try:
        with _conn_db(DB_NAME) as c:
            with c.cursor() as cur:
                filtro_contexto = _sql_operador_context_filter("a")
                registros = []
                pausa_filters = []
                pausa_params = []
                if os_num:
                    cur.execute(
                        f"""
                        SELECT a.os, a.partnumber, a.operacao, a.re_operador, a.maquina,
                               i.idx_medida, i.titulo, i.instrumento,
                               i.faixa_texto, i.escolha, i.status, i.created_at
                          FROM operador_amostragem a
                          JOIN operador_amostragem_item i ON i.amostragem_id = a.id
                         WHERE a.os = %s
                           AND {filtro_contexto}
                         ORDER BY i.idx_medida, i.created_at
                        """,
                        (os_num,),
                    )
                    registros.extend(_map_amostragem(cur.fetchall()))
                    pausa_filters.append("os=%s")
                    pausa_params.append(os_num)
                elif part and op:
                    cur.execute(
                        f"""
                        SELECT a.os, a.partnumber, a.operacao, a.re_operador, a.maquina,
                               i.idx_medida, i.titulo, i.instrumento,
                               i.faixa_texto, i.escolha, i.status, i.created_at
                          FROM operador_amostragem a
                          JOIN operador_amostragem_item i ON i.amostragem_id = a.id
                         WHERE TRIM(LEADING '0' FROM TRIM(a.partnumber)) = %s
                           AND TRIM(LEADING '0' FROM TRIM(a.operacao)) = %s
                           AND {filtro_contexto}
                         ORDER BY i.idx_medida, i.created_at
                        """,
                        (part, op),
                    )
                    registros.extend(_map_amostragem(cur.fetchall()))
                    pausa_filters.append(
                        "TRIM(LEADING '0' FROM TRIM(partnumber)) = %s"
                    )
                    pausa_params.append(part)
                    pausa_filters.append(
                        "TRIM(LEADING '0' FROM TRIM(operacao)) = %s"
                    )
                    pausa_params.append(op)
                else:
                    cur.execute(
                        f"""
                        SELECT a.os, a.partnumber, a.operacao, a.re_operador,
                               CASE
                                  WHEN SUM(CASE WHEN LOWER(i.status) LIKE '%%reprov%%' THEN 1 ELSE 0 END) > 0 THEN 'reprovado'
                                  WHEN SUM(CASE WHEN LOWER(i.status) LIKE '%%aprov%%' OR LOWER(i.status) = 'ok' THEN 1 ELSE 0 END) = COUNT(i.id) THEN 'aprovado'
                                 ELSE 'pendente'
                               END AS status_geral,
                               a.created_at
                          FROM operador_amostragem a
                          LEFT JOIN operador_amostragem_item i ON i.amostragem_id = a.id
                         WHERE {filtro_contexto}
                          GROUP BY a.id
                          ORDER BY a.created_at DESC
                          LIMIT 200
                        """,
                    )
                    rows = cur.fetchall()
                    return jsonify(rows)

                if pausa_filters:
                    cur.execute(
                        f"""
                        SELECT os, partnumber, operacao, re_operador,
                               motivo, pausa_at, retorno_at
                          FROM operador_jornada
                         WHERE {' AND '.join(pausa_filters)}
                         ORDER BY pausa_at
                        """,
                        pausa_params,
                    )
                    registros.extend(_map_pausas(cur.fetchall()))

        registros.sort(key=lambda r: r.get("created_at") or datetime.min)
        return jsonify(_serialize(registros))
    except Exception as e:
        return (
            jsonify({"error": f"Falha ao consultar relatórios do operador: {e}"}),
            500,
        )


@app.route("/reports/os")
def relatorio_os():
    os_num = _norm(request.args.get("os"))
    section = (_norm(request.args.get("section")) or "full").lower()
    if not os_num:
        return jsonify({"error": "os inválida"}), 400
    try:
        with _conn_db(DB_NAME) as c:
            with c.cursor() as cur:
                filtro_contexto = _sql_operador_context_filter("a")
                os_data = None
                amostragem = []
                jornada = []
                liberacao = []
                finalizacao = []
                if section in ("full", "ordem_servico"):
                    cur.execute("SELECT * FROM ordem_servico WHERE os=%s", (os_num,))
                    os_data = cur.fetchone()
                if section in ("full", "amostragem"):
                    cur.execute(
                        f"""
                        SELECT a.os, a.partnumber, a.operacao, a.re_operador,
                               a.maquina,
                               i.idx_medida, i.titulo, i.instrumento,
                               i.faixa_texto, i.escolha, i.status, i.created_at
                          FROM operador_amostragem a
                          JOIN operador_amostragem_item i ON i.amostragem_id = a.id
                         WHERE a.os=%s
                           AND {filtro_contexto}
                         ORDER BY i.idx_medida, i.created_at
                        """,
                        (os_num,),
                    )
                    amostragem = cur.fetchall()
                    cur.execute(
                        """
                        SELECT os, partnumber, operacao, re_operador,
                               motivo, pausa_at, retorno_at
                          FROM operador_jornada
                         WHERE os=%s
                         ORDER BY pausa_at
                        """,
                        (os_num,),
                    )
                    jornada = cur.fetchall()
                if section in ("full", "liberacao"):
                    if _tables_exist(
                            cur,
                            "preparador_registro",
                            "preparador_registro_item",
                            "preparador_liberacao",
                    ):
                        cur.execute(
                            """
                        SELECT r.os, r.partnumber, r.operacao, r.re_preparador,
                               r.maquina,
                               i.idx_medida, i.titulo, i.faixa_texto,
                               i.minimo, i.maximo, i.unidade,
                               CAST(i.medicao AS CHAR) AS medicao,
                               i.status AS status,
                               COALESCE(l.status_geral, 'Pendente') AS status_geral,
                               i.observacao, i.created_at
                          FROM preparador_registro r
                          JOIN preparador_registro_item i ON i.registro_id = r.id
                          LEFT JOIN preparador_liberacao l
                            ON l.os = r.os
                           AND TRIM(LEADING '0' FROM TRIM(l.partnumber)) = TRIM(LEADING '0' FROM TRIM(r.partnumber))
                           AND l.operacao = r.operacao
                           AND l.maquina = r.maquina
                         WHERE r.os=%s
                         ORDER BY i.created_at
                        """,
                            (os_num,),
                        )
                        liberacao = cur.fetchall()
                    else:
                        liberacao = []
                if section in ("full", "finalizacao"):
                    if _tables_exist(
                            cur, "preparador_finalizacao", "preparador_finalizacao_item"
                    ):
                        cur.execute(
                            """
                        SELECT f.os, f.partnumber, f.operacao, f.re_preparador,
                               f.maquina,
                               i.idx_medida, i.titulo, i.faixa_texto,
                               i.minimo, i.maximo, i.unidade,
                               CAST(i.medicao AS CHAR) AS medicao,
                               i.status, i.observacao, i.created_at
                          FROM preparador_finalizacao f
                          JOIN preparador_finalizacao_item i ON i.finalizacao_id = f.id
                         WHERE f.os=%s
                         ORDER BY i.created_at
                        """,
                            (os_num,),
                        )
                        finalizacao = cur.fetchall()
                    else:
                        finalizacao = []
        return jsonify(
            {
                "ordem_servico": _serialize(os_data) if os_data else None,
                "amostragem": _serialize(amostragem),
                "jornada": _serialize(jornada),
                "liberacao": _serialize(liberacao),
                "finalizacao": _serialize(finalizacao),
            }
        )
    except Exception as e:
        app.logger.exception("Falha ao gerar relatório")
        return jsonify({"error": f"Falha ao gerar relatório: {e}"}), 500


@app.route("/reports/os_status")
def relatorio_status_os():
    def _status_label(raw_status: Optional[str]) -> str:
        normalized = _normalize_text(raw_status or "")
        if normalized in {"encerrada", "finalizada", "finalizado"}:
            return "Finalizada"
        return "Aberta"

    def _classificar_status(texto: str) -> Optional[str]:
        if not texto:
            return None
        base = _normalize_text(_strip_side_prefix(texto))
        if not base:
            return None
        if "reprov" in base:
            if "abaix" in base:
                return "reprovada_abaixo"
            if "acima" in base:
                return "reprovada_acima"
            return "reprovada_acima"
        if "alerta" in base:
            if "abaix" in base:
                return "alerta_abaixo"
            if "acima" in base:
                return "alerta_acima"
            return "alerta_acima"
        if base in {"ok", "aprovado", "aprovada", "conforme"}:
            return "ok"
        return None

    def _split_choices(escolha: str) -> List[str]:
        partes = re.split(r"[|/]+", escolha)
        return [p.strip() for p in partes if p and p.strip()]

    try:
        with _conn_db(DB_NAME) as c:
            with c.cursor() as cur:
                filtro_contexto = _sql_operador_context_filter("a")
                cur.execute(
                    """
                    SELECT codigo, categoria
                      FROM maquinas
                     WHERE codigo IS NOT NULL AND codigo <> ''
                    """,
                )
                categorias_por_maquina = {}
                for row in cur.fetchall():
                    codigo = _norm(row.get("codigo"))
                    if not codigo:
                        continue
                    categorias_por_maquina[codigo] = _norm(row.get("categoria"))

                cur.execute(
                    """
                    SELECT os, status
                      FROM ordem_servico
                     ORDER BY os
                    """,
                )
                registros = []
                por_os = {}

                def _novo_registro(os_num: str, status_label: str = "Aberta"):
                    return {
                        "os": os_num,
                        "status": status_label,
                        "reprovada_abaixo": 0,
                        "alerta_abaixo": 0,
                        "ok": 0,
                        "alerta_acima": 0,
                        "reprovada_acima": 0,
                        "_maquinas": set(),
                        "_categorias": set(),
                        "_partnumbers": set(),
                        "_amostragens_por_re": {},
                    }

                for row in cur.fetchall():
                    os_num = _norm(row.get("os"))
                    if not os_num:
                        continue
                    dados = _novo_registro(os_num, _status_label(row.get("status")))
                    registros.append(dados)
                    por_os[os_num] = dados

                cur.execute(
                    f"""
                    SELECT a.os,
                           a.partnumber,
                           a.maquina,
                           i.status,
                           i.escolha,
                           COUNT(*) AS qtd
                      FROM operador_amostragem a
                      JOIN operador_amostragem_item i ON i.amostragem_id = a.id
                     WHERE {filtro_contexto}
                     GROUP BY a.os, a.partnumber, a.maquina, i.status, i.escolha
                    """,
                )
                for row in cur.fetchall():
                    os_num = _norm(row.get("os"))
                    if not os_num:
                        continue
                    dados = por_os.get(os_num)
                    if dados is None:
                        dados = _novo_registro(os_num)
                        por_os[os_num] = dados
                        registros.append(dados)

                    partnumber = _norm(row.get("partnumber"))
                    if partnumber:
                        dados["_partnumbers"].add(partnumber)

                    maquina = _norm(row.get("maquina"))
                    if maquina:
                        dados["_maquinas"].add(maquina)
                        categoria = categorias_por_maquina.get(maquina)
                        if categoria:
                            dados["_categorias"].add(categoria)

                    qtd = int(row.get("qtd") or 0)
                    if qtd <= 0:
                        continue

                    status_bruto = row.get("status") or ""
                    partes_status = _split_choices(status_bruto)
                    classificados = False
                    for parte in partes_status:
                        chave = _classificar_status(parte)
                        if chave is None:
                            continue
                        dados[chave] = dados.get(chave, 0) + qtd
                        classificados = True

                    if not classificados:
                        escolha = row.get("escolha") or ""
                        for parte in _split_choices(escolha):
                            chave = _classificar_status(parte)
                            if chave is None:
                                continue
                            dados[chave] = dados.get(chave, 0) + qtd

                cur.execute(
                    f"""
                    SELECT os, re_operador, COUNT(*) AS qtd
                      FROM operador_amostragem
                     WHERE re_operador IS NOT NULL AND re_operador <> ''
                       AND {_sql_operador_context_filter('operador_amostragem')}
                     GROUP BY os, re_operador
                    """,
                )
                for row in cur.fetchall():
                    os_num = _norm(row.get("os"))
                    if not os_num:
                        continue
                    dados = por_os.get(os_num)
                    if dados is None:
                        dados = _novo_registro(os_num)
                        por_os[os_num] = dados
                        registros.append(dados)

                    re_operador = _norm(row.get("re_operador"))
                    if not re_operador:
                        continue

                    qtd = int(row.get("qtd") or 0)
                    if qtd <= 0:
                        continue

                    por_re = dados.setdefault("_amostragens_por_re", {})
                    por_re[re_operador] = por_re.get(re_operador, 0) + qtd

        def _ordenar(item):
            os_valor = str(item.get("os", ""))
            normalizado = _strip_leading_zeros(os_valor)
            if normalizado.isdigit():
                return (0, int(normalizado))
            return (1, normalizado)

        for item in registros:
            item["maquinas"] = sorted(item.pop("_maquinas", set()))
            item["categorias"] = sorted(item.pop("_categorias", set()))
            item["partnumbers"] = sorted(item.pop("_partnumbers", set()))
            por_re = item.pop("_amostragens_por_re", {}) or {}
            lista_re = []
            for chave, valor in por_re.items():
                re_valor = _norm(chave)
                if not re_valor:
                    continue
                try:
                    qtd = int(valor or 0)
                except (TypeError, ValueError):
                    continue
                if qtd <= 0:
                    continue
                lista_re.append({"re": re_valor, "total": qtd})
            lista_re.sort(key=lambda x: (-x["total"], x["re"]))
            item["amostragens_por_re"] = lista_re
        registros.sort(key=_ordenar)
        return jsonify(registros)
    except Exception as e:
        app.logger.exception("Falha ao gerar resumo de status das OS")
        return jsonify({"error": f"Falha ao gerar resumo: {e}"}), 500


@app.route("/reports/export")
def exportar_relatorio_excel():
    os_num = _norm(request.args.get("os"))
    tipo = (request.args.get("type") or "").upper()
    if not os_num or tipo not in ("FOR07", "FOR09"):
        return jsonify({"error": "Parâmetros 'os' e 'type' são obrigatórios"}), 400
    try:
        with _conn_db(DB_NAME) as c:
            with c.cursor() as cur:
                if tipo == "FOR07":
                    rows = []
                    headers = [
                        "os",
                        "partnumber",
                        "operacao",
                        "re_preparador",
                        "idx_medida",
                        "titulo",
                        "faixa_texto",
                        "minimo",
                        "maximo",
                        "unidade",
                        "medicao",
                        "medicao_final",
                        "etapa",
                        "etapa_final",
                        "observacao",
                        "created_at",
                        "created_at_final",
                    ]
                    combined = {}
                    if _tables_exist(
                            cur,
                            "preparador_registro",
                            "preparador_registro_item",
                    ):
                        cur.execute(
                            """
                        SELECT r.os, r.partnumber, r.operacao, r.re_preparador,
                               i.idx_medida, i.titulo, i.faixa_texto,
                               i.minimo, i.maximo, i.unidade,
                               CAST(i.medicao AS CHAR) AS medicao,
                               i.observacao, i.created_at
                          FROM preparador_registro r
                          JOIN preparador_registro_item i ON i.registro_id = r.id
                         WHERE r.os=%s
                         ORDER BY i.created_at
                        """,
                            (os_num,),
                        )
                        for r in cur.fetchall():
                            key = (
                                r["idx_medida"],
                                r["titulo"],
                                r["partnumber"],
                                r["operacao"],
                            )
                            r["etapa"] = "liberacao"
                            combined[key] = r
                    if _tables_exist(
                            cur, "preparador_finalizacao", "preparador_finalizacao_item"
                    ):
                        cur.execute(
                            """
                        SELECT f.os, f.partnumber, f.operacao, f.re_preparador,
                               i.idx_medida, i.titulo, i.faixa_texto,
                               i.minimo, i.maximo, i.unidade,
                               CAST(i.medicao AS CHAR) AS medicao,
                               i.observacao, i.created_at
                          FROM preparador_finalizacao f
                          JOIN preparador_finalizacao_item i ON i.finalizacao_id = f.id
                         WHERE f.os=%s
                         ORDER BY i.created_at
                        """,
                            (os_num,),
                        )
                        for r in cur.fetchall():
                            key = (
                                r["idx_medida"],
                                r["titulo"],
                                r["partnumber"],
                                r["operacao"],
                            )
                            row = combined.get(key)
                            if not row:
                                row = {
                                    "os": r["os"],
                                    "partnumber": r["partnumber"],
                                    "operacao": r["operacao"],
                                    "re_preparador": r["re_preparador"],
                                    "idx_medida": r["idx_medida"],
                                    "titulo": r["titulo"],
                                    "faixa_texto": r["faixa_texto"],
                                    "minimo": r["minimo"],
                                    "maximo": r["maximo"],
                                    "unidade": r["unidade"],
                                    "medicao": None,
                                    "etapa": "liberacao",
                                    "observacao": r.get("observacao"),
                                    "created_at": None,
                                }
                            row["medicao_final"] = r["medicao"]
                            row["etapa_final"] = "finalizacao"
                            row["created_at_final"] = r["created_at"]
                            if not row.get("observacao") and r.get("observacao"):
                                row["observacao"] = r["observacao"]
                            combined[key] = row
                    rows = list(combined.values())
                else:
                    filtro_contexto = _sql_operador_context_filter("a")
                    cur.execute(
                        f"""
                        SELECT a.os, a.partnumber, a.operacao, a.re_operador, a.maquina,
                               i.idx_medida, i.titulo, i.instrumento, i.faixa_texto,
                               i.minimo, i.maximo, i.unidade, i.periodicidade,
                               i.tolerancias, i.escolha, i.status, i.observacao,
                               i.created_at
                        FROM operador_amostragem a
                        JOIN operador_amostragem_item i ON i.amostragem_id = a.id

                        WHERE a.os=%s
                          AND {filtro_contexto}
                        ORDER BY a.created_at DESC, i.idx_medida ASC
                        """,
                        (os_num,),
                    )
                    rows = cur.fetchall()
                    headers = [
                        "os",
                        "partnumber",
                        "operacao",
                        "re_operador",
                        "maquina",
                        "idx_medida",
                        "titulo",
                        "instrumento",
                        "faixa_texto",
                        "minimo",
                        "maximo",
                        "unidade",
                        "periodicidade",
                        "tolerancias",
                        "escolha",
                        "status",
                        "observacao",
                        "created_at",
                    ]

        wb = Workbook()
        ws = wb.active
        ws.append(headers)
        for r in rows:
            ws.append([_serialize(r.get(h)) for h in headers])
        stream = io.BytesIO()
        wb.save(stream)
        stream.seek(0)
        filename = f"relatorio_{os_num}_{tipo}.xlsx"
        try:
            return send_file(
                stream,
                as_attachment=True,
                download_name=filename,
                mimetype="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            )
        except TypeError:
            # Compatibilidade com versões antigas do Flask (<2.0)
            return send_file(
                stream,
                as_attachment=True,
                attachment_filename=filename,
                mimetype="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            )
    except Exception as e:
        app.logger.exception("Falha ao exportar relatório")
        return jsonify({"error": f"Falha ao exportar relatório: {e}"}), 500


def _verify_and_upgrade_password(
        conn, username: str, provided: str, stored: Optional[str]
) -> bool:
    """Valida a senha e migra registros legados em texto puro."""
    if not stored:
        return False

    try:
        if check_password_hash(stored, provided):
            return True
    except (TypeError, ValueError):
        # Valor armazenado não é um hash reconhecido; trataremos como texto puro.
        pass

    if stored == provided:
        hashed = generate_password_hash(provided)
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE usuarios SET password=%s WHERE username=%s",
                (hashed, username),
            )
        conn.commit()
        return True
    return False


def _hash_password(password: str) -> str:
    """Gera o hash seguro para a senha informada."""
    return generate_password_hash(password)


def _is_admin_request() -> bool:
    """Check HTTP Basic credentials and confirm admin user."""
    auth = request.authorization
    if not auth:
        return False
    with _conn_db(DB_NAME) as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT password, is_admin FROM usuarios WHERE username=%s",
                (auth.username,),
            )
            row = cur.fetchone()
        if not row:
            return False
        if not _verify_and_upgrade_password(
                conn, auth.username, auth.password, row.get("password")
        ):
            return False
        return bool(row.get("is_admin"))


@app.route("/login", methods=["POST"])
def login():
    data = request.get_json(silent=True) or {}
    username = (data.get("username") or "").strip()
    password = (data.get("password") or "").strip()
    with _conn_db(DB_NAME) as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, username, password, is_admin FROM usuarios WHERE username=%s",
                (username,),
            )
            user = cur.fetchone()
        if user and _verify_and_upgrade_password(
                conn, username, password, user.get("password")
        ):
            user = {k: v for k, v in user.items() if k != "password"}
            return jsonify({"user": user})
    return jsonify({"error": "credenciais inválidas"}), 401


@app.route("/usuarios", methods=["GET", "POST"])
def usuarios():
    if not _is_admin_request():
        return jsonify({"error": "unauthorized"}), 401
    if request.method == "GET":
        with _conn_db(DB_NAME) as c:
            with c.cursor() as cur:
                cur.execute("SELECT id, username, is_admin FROM usuarios")
                rows = cur.fetchall()
        return jsonify(rows)

    data = request.get_json(silent=True) or {}
    username = (data.get("username") or "").strip()
    password = (data.get("password") or "").strip()
    is_admin = int(bool(data.get("is_admin")))
    if not username or not password:
        return jsonify({"error": "campos obrigatórios"}), 400
    with _conn_db(DB_NAME) as c:
        with c.cursor() as cur:
            cur.execute(
                "INSERT INTO usuarios (username, password, is_admin) VALUES (%s, %s, %s)",
                (username, _hash_password(password), is_admin),
            )
        c.commit()
    return jsonify({"status": "ok"})


@app.route("/machines", methods=["GET", "POST"])
def machines():
    if request.method == "GET":
        with _conn_db(DB_NAME) as c:
            with c.cursor() as cur:
                cur.execute(
                    "SELECT codigo, categoria FROM maquinas ORDER BY categoria, codigo"
                )
                rows = cur.fetchall()
        return jsonify(rows)

    data = request.get_json(silent=True) or {}
    codigo = (data.get("codigo") or "").strip()
    categoria = (data.get("categoria") or "").strip()
    if not codigo or not categoria:
        return jsonify({"error": "campos 'codigo' e 'categoria' obrigatórios"}), 400

    with _conn_db(DB_NAME) as c:
        with c.cursor() as cur:
            cur.execute(
                "INSERT INTO maquinas (codigo, categoria) VALUES (%s, %s) ON DUPLICATE KEY UPDATE categoria=VALUES(categoria)",
                (codigo, categoria),
            )
        c.commit()
    return jsonify({"status": "ok", "codigo": codigo, "categoria": categoria})


@app.route("/machines/<codigo>", methods=["PUT"])
def update_machine(codigo: str):
    data = request.get_json(silent=True) or {}
    new_codigo = (data.get("codigo") or "").strip()
    categoria = (data.get("categoria") or "").strip()
    if not new_codigo or not categoria:
        return jsonify({"error": "campos 'codigo' e 'categoria' obrigatórios"}), 400
    with _conn_db(DB_NAME) as c:
        with c.cursor() as cur:
            cur.execute(
                "UPDATE maquinas SET codigo=%s, categoria=%s WHERE codigo=%s",
                (new_codigo, categoria, codigo),
            )
        c.commit()
    return jsonify({"status": "ok", "codigo": new_codigo, "categoria": categoria})


@app.route("/checklist/liberacao", methods=["POST"])
def registrar_checklist_liberacao():
    data = request.get_json(silent=True) or {}
    re = (data.get("re") or "").strip()
    grupo_maquina = (data.get("grupo_maquina") or "").strip()
    maquina = (data.get("maquina") or "").strip()
    respostas_raw = data.get("respostas")

    if not re:
        return jsonify({"error": "campo 're' obrigatório"}), 400
    if not grupo_maquina:
        return jsonify({"error": "campo 'grupo_maquina' obrigatório"}), 400
    if not maquina:
        return jsonify({"error": "campo 'maquina' obrigatório"}), 400
    if not isinstance(respostas_raw, list) or not respostas_raw:
        return jsonify({"error": "lista de respostas obrigatória"}), 400
    if not re.isdigit():
        return jsonify({"error": "campo 're' deve conter apenas números"}), 400

    allowed_answers = {"sim", "nao", "nao_aplica"}
    respostas_formatadas: List[Tuple[int, str, str, str]] = []
    for idx, raw in enumerate(respostas_raw):
        if not isinstance(raw, dict):
            continue
        pergunta = (raw.get("pergunta") or "").strip()
        grupo_resposta = (raw.get("grupo") or grupo_maquina).strip()
        resposta = (raw.get("resposta") or "").strip().lower()
        ordem_raw = raw.get("ordem")
        try:
            ordem = int(ordem_raw)
        except (TypeError, ValueError):
            ordem = idx

        if not pergunta or resposta not in allowed_answers:
            continue
        if not grupo_resposta:
            grupo_resposta = grupo_maquina

        respostas_formatadas.append(
            (
                ordem,
                grupo_resposta[:128],
                pergunta[:1024],
                resposta,
            )
        )

    if not respostas_formatadas:
        return jsonify({"error": "nenhuma resposta válida informada"}), 400

    respostas_formatadas.sort(key=lambda item: item[0])
    with _conn_db(DB_NAME) as c:
        with c.cursor() as cur:
            cur.execute(
                """
                INSERT INTO checklist_liberacao (re, grupo_maquina, maquina)
                VALUES (%s, %s, %s)
                """,
                (re[:64], grupo_maquina[:128], maquina[:128]),
            )
            checklist_id = cur.lastrowid
            cur.executemany(
                """
                INSERT INTO checklist_liberacao_item
                  (checklist_id, ordem, grupo, pergunta, resposta)
                VALUES (%s, %s, %s, %s, %s)
                """,
                [
                    (checklist_id, ordem, grupo, pergunta, resposta)
                    for ordem, grupo, pergunta, resposta in respostas_formatadas
                ],
            )
        c.commit()

    return jsonify({"status": "ok", "id": checklist_id})


@app.route("/relatorios/sql")
def relatorio_sql():
    path = request.args.get("path")
    if not path:
        return jsonify({"error": "parâmetro 'path' obrigatório"}), 400
    try:
        rows = _run_sql_report(path)
        return jsonify(rows)
    except Exception as e:
        return jsonify({"error": f"Falha ao executar relatório: {e}"}), 500


@app.route("/health")
def health():

    return jsonify({"status": "ok"})


def _mensagem_bloqueio(
        os_num: str, part: str, op: str, maquina: str, fonte: str, detalhe: str
) -> str:
    """
    Gera um texto legível explicando por que o operador não pode registrar.
    fonte: "", "preparador_registro" ou "preparador_liberacao"
    detalhe: texto livre com dicas (ex.: "3/4 OK", "status_geral=pendente")
    """
    base = f"OS: {os_num}  •  Peça: {part}  •  Operação: {op}  •  Máquina: {maquina}."

    fonte = (fonte or "").strip().lower()
    det = str(detalhe or "")

    if fonte == "ordem_servico":
        det_lower = det.lower()
        if "status=pausada" in det_lower:
            return (
                    base
                    + "\nA ordem de serviço está pausada. Solicite nova liberação ao Preparador."
            )
        if "status=encerrada" in det_lower:
            return base + "\nA ordem de serviço está encerrada."
        return base + "\nSituação da ordem de serviço impede o registro no momento."

    base = "A máquina ainda não foi liberada pelo Preparador.\n" + base

    if not fonte:
        return (
                base
                + "\nNão há registro do Preparador para esta combinação. Solicite a liberação (FOR-007/008)."
        )

    if fonte == "preparador_liberacao":
        import re

        m = re.search(r"status_geral=([a-z_]+)", det, re.I)
        status = (m.group(1) if m else "pendente").replace("_", " ")
        return base + f"\nSituação da liberação: {status}. Procure o Preparador."

    if fonte == "preparador_registro":
        import re

        m = re.search(r"(\d+)\s*/\s*(\d+)", det)  # ex.: "3/4 aprovadas"
        if m:
            aprov_cnt, total = m.group(1), m.group(2)
            return (
                    base
                    + f"\nProgresso do registro do Preparador: {aprov_cnt}/{total} medidas aprovadas. Aguarde até todas estarem aprovadas."
            )
        return base + "\nO registro do Preparador ainda não está 100% aprovado."

    return base


if __name__ == "__main__":
    # threaded=True mantém atendendo enquanto indexa em background entre requests
    app.run(host="0.0.0.0", port=5005, debug=True, threaded=True, use_reloader=False)