#!/usr/bin/env bash
# =============================================================================
# Script: extract_sequences.sh
# Descrição: Extrai sequências de um arquivo FASTA multi-sequência com base em
#            uma lista de IDs e verifica quais IDs não foram encontrados.
#
# Autor: Edson Delatorre
# Laboratório: Laboratório de Genômica e Ecologia Viral (LAGEV) - UFES
# Repositório: https://github.com/lagev-ufes
# Data: 2026-05-03
# Versão: 1.1
# =============================================================================
#
# INSTRUÇÕES DE USO:
# =============================================================================
# O script requer 2 argumentos:
#   1. Arquivo contendo lista de IDs (um por linha)
#   2. Arquivo FASTA de entrada
#
# Exemplo de uso:
#   ./extract_sequences.sh ids.txt sequencias.fasta > subset.fasta
#
# =============================================================================
# SAÍDA:
# =============================================================================
# - FASTA com sequências extraídas (stdout)
# - Relatório de IDs não encontrados (stderr)
#
# =============================================================================

set -euo pipefail

########################################
# Funções auxiliares
########################################

log() {
    echo "[INFO] $*" >&2
}

erro() {
    echo "[ERRO] $*" >&2
    exit 1
}

########################################
# Instalação do seqkit
########################################

instalar_seqkit() {
    log "seqkit não encontrado. Tentando instalar..."

    if command -v conda >/dev/null 2>&1; then
        conda install -y -c bioconda seqkit
    elif command -v mamba >/dev/null 2>&1; then
        mamba install -y -c bioconda seqkit
    elif command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y seqkit || \
            erro "Pacote seqkit não disponível via apt."
    elif command -v brew >/dev/null 2>&1; then
        brew install seqkit
    else
        erro "Instale seqkit manualmente (conda recomendado)."
    fi
}

########################################
# Validação de entrada
########################################

if [[ $# -ne 2 ]]; then
    echo "Uso: $0 <ids.txt> <arquivo.fasta>" >&2
    exit 1
fi

ids="$1"
fasta="$2"

[[ -f "$ids" ]] || erro "Arquivo de IDs não encontrado: $ids"
[[ -f "$fasta" ]] || erro "Arquivo FASTA não encontrado: $fasta"

########################################
# Garantir seqkit
########################################

if ! command -v seqkit >/dev/null 2>&1; then
    instalar_seqkit
fi

command -v seqkit >/dev/null 2>&1 || erro "Falha ao instalar seqkit."

log "seqkit detectado: $(seqkit version)"

########################################
# Arquivos temporários
########################################

tmp_ids_sorted=$(mktemp)
tmp_found_ids=$(mktemp)

trap 'rm -f "$tmp_ids_sorted" "$tmp_found_ids"' EXIT

########################################
# Normalizar lista de IDs
########################################

sort "$ids" | uniq > "$tmp_ids_sorted"

########################################
# Extração das sequências
########################################

log "Extraindo sequências de: $fasta"

seqkit grep -f "$tmp_ids_sorted" "$fasta" | tee >(seqkit seq -n > "$tmp_found_ids")

########################################
# Verificação de IDs não encontrados
########################################

missing=$(comm -23 "$tmp_ids_sorted" <(sort "$tmp_found_ids") || true)

if [[ -n "$missing" ]]; then
    log "IDs NÃO encontrados:"
    echo "$missing" >&2
else
    log "Todos os IDs foram encontrados com sucesso."
fi
