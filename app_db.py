# app.py
from flask import Flask, request, jsonify, send_file
from pathlib import Path
from typing import Optional, Tuple
import os
import re
import json
import io

from openpyxl import Workbook

# --------- MySQL ----------
import pymysql
from pymysql.cursors import DictCursor

app = Flask(__name__)
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
            cur.execute(
                """ALTER TABLE ordem_servico
                      ADD COLUMN IF NOT EXISTS status VARCHAR(32) DEFAULT 'aberta'"""
            )
            # Operador (já estava)

            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS operador_amostragem (
                    id BIGINT AUTO_INCREMENT PRIMARY KEY,
                    os VARCHAR(64) NOT NULL,
                    partnumber VARCHAR(128) NOT NULL,
                    operacao VARCHAR(64) NOT NULL,
                    re_operador VARCHAR(64) NOT NULL,
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
                    pausa_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    KEY idx_oj_os (os),
                    CONSTRAINT fk_oj_os FOREIGN KEY (os) REFERENCES ordem_servico(os) ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
                """
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
                  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                  KEY idx_os (os),
                  KEY idx_part_op (partnumber, operacao)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
                """
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
            # Preparador (liberação consolidada)
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS preparador_liberacao (
                  id BIGINT AUTO_INCREMENT PRIMARY KEY,
                  os VARCHAR(64) NOT NULL,
                  partnumber VARCHAR(128) NOT NULL,
                  operacao VARCHAR(64) NOT NULL,
                  re_preparador VARCHAR(64) NOT NULL,
                  status_geral VARCHAR(32) DEFAULT NULL,
                  observacao TEXT DEFAULT NULL,
                  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                  KEY idx_pl_os (os),
                  KEY idx_pl_part_op (partnumber, operacao),
                  KEY idx_pl_created (created_at)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
                """
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


def _to_float(s):
    try:
        return float(str(s).replace(",", ".").strip())
    except Exception:
        return None


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
                SELECT idx_medida, titulo, faixa_texto, instrumento, minimo, maximo
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
        medidas.append(
            {
                "titulo": titulo,
                "faixaTexto": faixa,
                "min": mn,
                "max": mx,
                "unidade": uni,
                "instrumento": row.get("instrumento") or "",
            }
        )
    return medidas


def _medidas_operador_db(part: str, op: str):
    part = _norm_part(part)
    op = _norm_op(op)
    rows = []
    with _conn_db(DB_NAME) as c:
        with c.cursor() as cur:
            cur.execute(
                """
                SELECT idx_medida, titulo, faixa_texto, minimo, maximo,
                       periodicidade, instrumento,
                       reprovada_abaixo, alerta_abaixo, alerta_acima, reprovada_acima
                FROM for09_norm
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
        medidas.append(
            {
                "titulo": titulo,
                "faixaTexto": faixa,
                "min": mn,
                "max": mx,
                "unidade": uni,
                "periodicidade": row.get("periodicidade") or "",
                "instrumento": row.get("instrumento") or "",
                "tolerancias": tolerancias,
            }
        )
    return medidas


# ========= HELPERS DE NEGÓCIO =========
def _maquina_liberada(conn, os_num: str, part: str, op: str) -> Tuple[bool, str, str]:
    """
    Retorna (liberada, fonte, detalhe).
    fonte: 'preparador_liberacao' | 'preparador_registro' | ''
    """
    os_num = _norm(os_num)
    part = _norm_part(part)
    op = _norm_op(op)
    if not (os_num and part and op):
        return (False, "", "Parâmetros insuficientes para validação.")

    with conn.cursor() as cur:
        cur.execute("SELECT status FROM ordem_servico WHERE os=%s", (os_num,))
        st_row = cur.fetchone()
        if st_row and (st_row.get("status") or "").strip().lower() == "encerrada":
            return (False, "ordem_servico", "status=encerrada")
        # 1) Se existir liberação com status final, já libera

        cur.execute(
            """
            SELECT status_geral
            FROM preparador_liberacao
            WHERE os=%s

              AND TRIM(LEADING '0' FROM TRIM(partnumber))=%s
              AND TRIM(LEADING '0' FROM TRIM(operacao))=%s

            ORDER BY id DESC LIMIT 1
            """,
            (os_num, part, op),
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

            ORDER BY created_at DESC, id DESC LIMIT 1
            """,
            (os_num, part, op),
        )
        reg = cur.fetchone()
        if not reg:
            return (False, "", "Sem registro do preparador para esta OS/peça/operação.")

        reg_id = reg["id"]
        cur.execute(
            """
            SELECT
              SUM(CASE WHEN LOWER(COALESCE(status,''))='ok' OR LOWER(COALESCE(status,'')) LIKE '%aprovado%'
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

                        f"SELECT COALESCE(MAX(idx_medida),0)+1 FROM {tabela} WHERE TRIM(LEADING '0' FROM TRIM(partnumber))=%s AND TRIM(LEADING '0' FROM TRIM(operacao))=%s",

                        (part, op),
                    )
                    dados["idx_medida"] = cur.fetchone()[0]

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
    if not part or not op:
        return (
            jsonify({"error": "Parâmetros 'partnumber' e 'operacao' são obrigatórios"}),
            400,
        )

    try:
        medidas = _medidas_operador_db(part, op)
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
          "status": "ok|reprovada_acima|reprovada_abaixo|alerta_acima|alerta_abaixo|alerta|pendente",
          "observacao": ""
        }, ...
      ]
    }
    (Para medições de tampão, o campo `status` envia os dois lados como
    "aprovado|reprovado".)
    """
    payload = request.get_json(silent=True) or {}
    print(f"[DEBUG] /preparador/resultado recebido: {payload}", flush=True)

    os_num = _norm(payload.get("os"))
    re_prep = _norm(payload.get("re"))
    part = _norm_part(payload.get("partnumber"))
    op = _norm_op(payload.get("operacao"))
    itens = payload.get("itens", [])

    if not os_num or not re_prep or not part or not op:
        return (
            jsonify(
                {
                    "error": "Campos 'os', 're', 'partnumber' e 'operacao' são obrigatórios"
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
            ok, fonte, detalhe = _maquina_liberada(c, os_num, part, op)
            if ok:
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
                # garante OS na mestre (por causa de FKs futuras)
                cur.execute(
                    "INSERT IGNORE INTO ordem_servico (os) VALUES (%s)", (os_num,)
                )

                # cabeçalho
                cur.execute(
                    """
                    INSERT INTO preparador_registro (os, partnumber, operacao, re_preparador)
                    VALUES (%s, %s, %s, %s)
                    """,
                    (os_num, part, op, re_prep),
                )
                registro_id = cur.lastrowid

                # itens
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
                            medicao,
                            status,
                            observacao,
                        ),
                    )
                    all_status.append(status)

                # Consolida liberação
                has_reprov = any(
                    any(parte.strip().startswith("reprov") for parte in s.split("|"))
                    for s in all_status
                )
                all_ok = len(all_status) > 0 and all(
                    all(parte.strip() in ("ok", "aprovado") for parte in s.split("|"))
                    for s in all_status
                )
                status_geral = (
                    "liberada"
                    if all_ok
                    else ("reprovada" if has_reprov else "pendente")
                )

                # upsert simples em preparador_liberacao (não cria itens aqui)
                cur.execute(
                    """
                    SELECT id FROM preparador_liberacao
                    WHERE os=%s

                      AND TRIM(LEADING '0' FROM TRIM(partnumber))=%s
                      AND TRIM(LEADING '0' FROM TRIM(operacao))=%s

                    ORDER BY id DESC LIMIT 1
                    """,
                    (os_num, part, op),
                )
                row = cur.fetchone()
                if row:
                    cur.execute(
                        "UPDATE preparador_liberacao SET re_preparador=%s, status_geral=%s WHERE id=%s",
                        (re_prep, status_geral, row["id"]),
                    )
                else:
                    cur.execute(
                        """
                        INSERT INTO preparador_liberacao
                          (os, partnumber, operacao, re_preparador, status_geral)
                        VALUES (%s, %s, %s, %s, %s)
                        """,
                        (os_num, part, op, re_prep, status_geral),
                    )

            c.commit()

        return jsonify(
            {"status": "ok", "registro_id": registro_id, "status_geral": status_geral}
        )

    except Exception as e:
        return jsonify({"error": f"Falha ao inserir registro do preparador: {e}"}), 500


# ========= CHECAGEM (para UI) =========
@app.route("/operador/pode")
def operador_pode():
    """Consulta rápida: pode o operador amostrar? (máquina liberada?)"""
    os_num = _norm(request.args.get("os"))
    part = _norm_part(request.args.get("partnumber"))
    op = _norm_op(request.args.get("operacao"))
    if not os_num or not part or not op:
        return (
            jsonify(
                {"error": "Parâmetros 'os', 'partnumber' e 'operacao' são obrigatórios"}
            ),
            400,
        )

    try:
        with _conn_db(DB_NAME) as c:
            ok, fonte, detalhe = _maquina_liberada(c, os_num, part, op)
        return jsonify(
            {
                "os": os_num,
                "partnumber": part,
                "operacao": op,
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
          "escolha": "OK", "status": "ok|reprovada_acima|reprovada_abaixo|alerta_acima|alerta_abaixo|alerta",
          "observacao": "..."
        }, ...
      ]
    }
    (Para medições de tampão, o campo `status` envia os dois lados como
    "aprovado|reprovado".)
    """
    payload = request.get_json(silent=True) or {}

    os_num = _norm(payload.get("os"))
    re_op = _norm(payload.get("re"))
    part = _norm_part(payload.get("partnumber"))
    op = _norm_op(payload.get("operacao"))
    itens = payload.get("itens", [])

    # validações mínimas
    if not os_num or not re_op or not part or not op:
        return (
            jsonify(
                {
                    "error": "Campos 'os', 're', 'partnumber' e 'operacao' são obrigatórios"
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
            # BLOQUEIO: exige liberação
            ok, fonte, detalhe = _maquina_liberada(c, os_num, part, op)
            if not ok:
                msg = _mensagem_bloqueio(os_num, part, op, fonte, detalhe)
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
                    INSERT INTO operador_amostragem (os, partnumber, operacao, re_operador)
                    VALUES (%s, %s, %s, %s)
                    """,
                    (os_num, part, op, re_op),
                )
                amostragem_id = cur.lastrowid

                # itens
                for it in itens:
                    idx = int(it.get("indice", 0))
                    titulo = _norm(it.get("titulo"))
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
    where = []
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


@app.route("/operador/fim_jornada", methods=["POST"])
def operador_fim_jornada():
    payload = request.get_json(silent=True) or {}
    os_num = _norm(payload.get("os"))
    re_op = _norm(payload.get("re"))
    part = _norm_part(payload.get("partnumber"))
    op = _norm_op(payload.get("operacao"))
    if not os_num or not re_op:
        return jsonify({"error": "Campos 'os' e 're' são obrigatórios"}), 400
    try:
        with _conn_db(DB_NAME) as c:
            with c.cursor() as cur:
                cur.execute(
                    "INSERT IGNORE INTO ordem_servico (os) VALUES (%s)", (os_num,)
                )
                cur.execute(
                    """
                    INSERT INTO operador_jornada (os, partnumber, operacao, re_operador)
                    VALUES (%s, %s, %s, %s)
                    """,
                    (os_num, part or None, op or None, re_op),
                )
            c.commit()
        return jsonify({"status": "ok"})
    except Exception as e:
        return jsonify({"error": f"Falha ao registrar fim de jornada: {e}"}), 500


@app.route("/operador/encerrar_os", methods=["POST"])
def operador_encerrar_os():
    payload = request.get_json(silent=True) or {}
    os_num = _norm(payload.get("os"))
    if not os_num:
        return jsonify({"error": "Campo 'os' é obrigatório"}), 400
    try:
        with _conn_db(DB_NAME) as c:
            with c.cursor() as cur:
                cur.execute(
                    "SELECT COUNT(*) FROM operador_amostragem WHERE os=%s", (os_num,)
                )
                if cur.fetchone()[0] == 0:
                    return (
                        jsonify({"error": "Nenhum registro de amostragem encontrado"}),
                        400,
                    )
                cur.execute(
                    "UPDATE ordem_servico SET status='encerrada' WHERE os=%s", (os_num,)
                )
                if cur.rowcount == 0:
                    return jsonify({"error": "OS não encontrada"}), 404
            c.commit()
        return jsonify({"status": "ok"})
    except Exception as e:
        return jsonify({"error": f"Falha ao encerrar OS: {e}"}), 500


@app.route("/reports")
def listar_relatorios():
    try:
        with _conn_db(DB_NAME) as c:
            with c.cursor() as cur:
                cur.execute(
                    """
                    SELECT os, partnumber, operacao, re_preparador, status_geral, created_at
                    FROM preparador_liberacao
                    ORDER BY created_at DESC
                    LIMIT 200
                    """
                )
                rows = cur.fetchall()
        return jsonify(rows)
    except Exception as e:
        return jsonify({"error": f"Falha ao consultar relatórios: {e}"}), 500


@app.route("/reports/preparador")
def listar_relatorios_preparador():
    try:
        with _conn_db(DB_NAME) as c:
            with c.cursor() as cur:
                cur.execute(
                    """
                    SELECT os, partnumber, operacao, re_preparador, status_geral, created_at
                    FROM preparador_liberacao
                    ORDER BY created_at DESC
                    LIMIT 200
                    """
                )
                rows = cur.fetchall()
        return jsonify(rows)
    except Exception as e:
        return jsonify({"error": f"Falha ao consultar relatórios do preparador: {e}"}), 500


@app.route("/reports/operador")
def listar_relatorios_operador():
    os_num = _norm(request.args.get("os"))
    where = ""
    params = []
    order_by = "ORDER BY a.created_at DESC"
    if os_num:
        where = "WHERE a.os = %s"
        params.append(os_num)
        order_by = "ORDER BY a.created_at ASC"
    try:
        with _conn_db(DB_NAME) as c:
            with c.cursor() as cur:
                cur.execute(
                    f"""
                    SELECT a.os, a.partnumber, a.operacao, a.re_operador,
                           CASE
                             WHEN SUM(CASE WHEN LOWER(i.status) LIKE '%reprov%' THEN 1 ELSE 0 END) > 0 THEN 'reprovado'
                             WHEN SUM(CASE WHEN LOWER(i.status) LIKE '%aprov%' OR LOWER(i.status) = 'ok' THEN 1 ELSE 0 END) = COUNT(i.id) THEN 'aprovado'
                             ELSE 'pendente'
                           END AS status_geral,
                           a.created_at
                    FROM operador_amostragem a
                    LEFT JOIN operador_amostragem_item i ON i.amostragem_id = a.id
                    {where}
                    GROUP BY a.id
                    {order_by}
                    LIMIT 200
                    """,
                    params,
                )
                rows = cur.fetchall()
        return jsonify(rows)
    except Exception as e:
        return jsonify({"error": f"Falha ao consultar relatórios do operador: {e}"}), 500


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
                    cur.execute(
                        """
                        SELECT os, partnumber, operacao, re_preparador, status_geral, created_at
                        FROM preparador_liberacao
                        WHERE os=%s
                        ORDER BY created_at DESC
                        """,
                        (os_num,),
                    )
                    rows = cur.fetchall()
                    headers = ["os", "partnumber", "operacao", "re_preparador", "status_geral", "created_at"]
                else:
                    cur.execute(
                        """
                        SELECT a.os, a.partnumber, a.operacao, a.re_operador,
                               i.idx_medida, i.titulo, i.instrumento, i.faixa_texto,
                               i.minimo, i.maximo, i.unidade, i.periodicidade,
                               i.tolerancias, i.escolha, i.status, i.observacao,
                               i.created_at
                        FROM operador_amostragem a
                        JOIN operador_amostragem_item i ON i.amostragem_id = a.id
                        WHERE a.os=%s
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
            ws.append([r.get(h) for h in headers])
        stream = io.BytesIO()
        wb.save(stream)
        stream.seek(0)
        filename = f"relatorio_{os_num}_{tipo}.xlsx"
        return send_file(
            stream,
            as_attachment=True,
            download_name=filename,
            mimetype="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        )
    except Exception as e:
        return jsonify({"error": f"Falha ao exportar relatório: {e}"}), 500

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
    os_num: str, part: str, op: str, fonte: str, detalhe: str
) -> str:
    """
    Gera um texto legível explicando por que o operador não pode registrar.
    fonte: "", "preparador_registro" ou "preparador_liberacao"
    detalhe: texto livre com dicas (ex.: "3/4 OK", "status_geral=pendente")
    """
    base = f"OS: {os_num}  •  Peça: {part}  •  Operação: {op}."

    fonte = (fonte or "").strip().lower()
    det = str(detalhe or "")

    if fonte == "ordem_servico":
        return base + "\nA ordem de serviço está encerrada."

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
