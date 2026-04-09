#!/bin/bash
# =============================================================================
# Script: fasta_to_phylip_relaxed.sh
# Descrição: Converte FASTA (alinhado) para PHYLIP RELAXED (nomes longos)
#
# Autor: Edson Delatorre
# Laboratório: LAGEV - UFES
# Data: 2026-04-09
# Versão: 1.1
# =============================================================================
#
# USO:
#   ./fasta_to_phylip_relaxed.sh input.fasta > output.phy
#
# =============================================================================

# -----------------------------
# Verificação de argumentos
# -----------------------------
if [ $# -ne 1 ]; then
    echo "Uso: $0 <arquivo.fasta>"
    exit 1
fi

FASTA="$1"

if [ ! -f "$FASTA" ]; then
    echo "Erro: arquivo não encontrado: $FASTA"
    exit 1
fi

# =============================================================================
# PROCESSAMENTO
# =============================================================================

awk '
BEGIN {
    RS=">"
    FS="\n"
}

NR > 1 {

    # -----------------------------
    # Nome COMPLETO (sem truncar)
    # -----------------------------
    nome = $1

    # Limpeza básica
    gsub(/^[ \t]+|[ \t]+$/, "", nome)
    gsub(/ /, "_", nome)

    # -----------------------------
    # Sequência
    # -----------------------------
    seq = ""
    for (i = 2; i <= NF; i++) {
        seq = seq $i
    }

    nomes[++n] = nome
    seqs[n] = seq
}

END {

    if (n == 0) {
        print "Erro: nenhuma sequência encontrada" > "/dev/stderr"
        exit 1
    }

    comprimento = length(seqs[1])

    # Validar alinhamento
    for (i = 2; i <= n; i++) {
        if (length(seqs[i]) != comprimento) {
            print "Erro: sequências com tamanhos diferentes" > "/dev/stderr"
            exit 1
        }
    }

    # Cabeçalho PHYLIP
    print n, comprimento

    # -----------------------------
    # PHYLIP RELAXED
    # Nome + espaço + sequência
    # -----------------------------
    for (i = 1; i <= n; i++) {
        print nomes[i], seqs[i]
    }
}
' "$FASTA"
