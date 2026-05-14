#!/bin/bash
# =============================================================================
# Script: rename_fasta_safe.sh
# Descrição: Renomeia cabeçalhos FASTA usando correspondência EXATA de accession
#            (GISAID: EPI_ISL_XXXXX), evitando matches parciais perigosos.
# Autor: Edson Delatorre (revisado)
# Versão: 2.0 (segura)
# =============================================================================

set -euo pipefail

# -----------------------------
# Validação de argumentos
# -----------------------------
if [ "$#" -ne 2 ]; then
    echo "Uso: $0 <mapping.txt> <input.fasta>" >&2
    exit 1
fi

MAP="$1"
FASTA="$2"

# -----------------------------
# Checagem do arquivo mapping
# -----------------------------
if [ ! -f "$MAP" ]; then
    echo "Erro: arquivo de mapeamento não encontrado." >&2
    exit 1
fi

if [ ! -f "$FASTA" ]; then
    echo "Erro: arquivo FASTA não encontrado." >&2
    exit 1
fi

# -----------------------------
# Processamento
# -----------------------------
awk -v map_file="$MAP" '
BEGIN {
    FS = "\t"

    # -------------------------
    # Carregar mapping com validação
    # -------------------------
    while ((getline < map_file) > 0) {
        key = $1
        value = $2

        # Validar formato GISAID
        if (key !~ /^EPI_ISL_[0-9]+$/) {
            print "ERRO: chave inválida no mapping:", key > "/dev/stderr"
            exit 1
        }

        if (key in map) {
            print "ERRO: accession duplicado no mapping:", key > "/dev/stderr"
            exit 1
        }

        map[key] = value
    }
    close(map_file)
}

# -----------------------------
# Função para extrair accession
# -----------------------------
function extract_accession(header,   match_arr) {
    if (match(header, /EPI_ISL_[0-9]+/, match_arr)) {
        return match_arr[0]
    }
    return ""
}

# -----------------------------
# Processamento do FASTA
# -----------------------------
{
    if ($0 ~ /^>/) {

        original_header = $0
        accession = extract_accession($0)

        if (accession == "") {
            print "WARNING: accession não encontrado:", original_header > "/dev/stderr"
            print original_header
            next
        }

        if (accession in map) {
            print ">" map[accession]
        } else {
            print "WARNING: accession sem mapping:", accession > "/dev/stderr"
            print original_header
        }

    } else {
        print $0
    }
}
' "$FASTA"
