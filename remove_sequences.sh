#!/bin/bash
# =============================================================================
# Script: remove_sequences.sh
# Descrição: Remove sequências de um arquivo FASTA com base em uma lista de IDs
#
# Autor: Edson Delatorre
# Laboratório: LAGEV - UFES
# Data: 2026-05-01
# Versão: 2.0
# =============================================================================
#
# USO:
#   ./remove_sequences.sh input.fasta remove.txt output.fasta [modo]
#
# MODOS:
#   id       → matching pelo ID (antes do "|") [RECOMENDADO]
#   exact    → matching pelo header completo
#   partial  → matching por substring (menos seguro)
#
# EXEMPLOS:
#   ./remove_sequences.sh input.fasta remove.txt output.fasta id
#   ./remove_sequences.sh input.fasta remove.txt output.fasta exact
#
# DEPENDÊNCIAS:
#   seqkit
#
# =============================================================================

# -----------------------------
# Verificação de argumentos
# -----------------------------
if [ $# -lt 3 ]; then
    echo "Uso: $0 <input.fasta> <remove.txt> <output.fasta> [modo]"
    exit 1
fi

FASTA="$1"
LIST="$2"
OUTPUT="$3"
MODE="${4:-id}"

# -----------------------------
# Verificação de arquivos
# -----------------------------
if [ ! -f "$FASTA" ]; then
    echo "Erro: FASTA não encontrado: $FASTA"
    exit 1
fi

if [ ! -f "$LIST" ]; then
    echo "Erro: lista de remoção não encontrada: $LIST"
    exit 1
fi

# -----------------------------
# Verificação de dependência
# -----------------------------
if ! command -v seqkit &> /dev/null; then
    echo "Erro: seqkit não está instalado ou não está no PATH"
    exit 1
fi

# =============================================================================
# PROCESSAMENTO
# =============================================================================

echo "----------------------------------------"
echo "Remoção de sequências FASTA"
echo "Arquivo entrada : $FASTA"
echo "Lista remoção   : $LIST"
echo "Arquivo saída   : $OUTPUT"
echo "Modo            : $MODE"
echo "----------------------------------------"

case "$MODE" in

    id)
        echo "[INFO] Matching pelo ID (antes do '|')"
        seqkit grep -v -f "$LIST" -n "$FASTA" -o "$OUTPUT"
        ;;

    exact)
        echo "[INFO] Matching pelo header completo"
        seqkit grep -v -f "$LIST" "$FASTA" -o "$OUTPUT"
        ;;

    partial)
        echo "[INFO] Matching por substring (menos seguro)"
        seqkit grep -v -f "$LIST" "$FASTA" -o "$OUTPUT"
        ;;

    *)
        echo "Erro: modo inválido: $MODE"
        echo "Use: id | exact | partial"
        exit 1
        ;;
esac

# =============================================================================
# RELATÓRIO
# =============================================================================

echo "----------------------------------------"
echo "Resumo"

echo "[ANTES]"
seqkit stats "$FASTA" | tail -n +2

echo "[DEPOIS]"
seqkit stats "$OUTPUT" | tail -n +2

echo "----------------------------------------"

# -----------------------------
# Checagem de segurança
# -----------------------------
REMAINING=$(seqkit grep -f "$LIST" "$OUTPUT" | grep -c "^>" || true)

if [ "$REMAINING" -gt 0 ]; then
    echo "[AVISO] Algumas sequências da lista ainda estão presentes no output"
else
    echo "[OK] Todas as sequências foram removidas corretamente"
fi

echo "----------------------------------------"
echo "Concluído."
