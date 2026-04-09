#!/bin/bash
# =============================================================================
# Script: fasta_to_phylip.sh
# Descrição: Converte um arquivo FASTA (alinhado) para o formato PHYLIP
#            sequencial, compatível com PhyML.
#
# Autor: Edson Delatorre
# Laboratório: Laboratório de Genômica e Ecologia Viral (LAGEV) - UFES
# Repositório: https://github.com/lagev-ufes
# Data: 2026-04-09
# Versão: 1.0
# =============================================================================
#
# INSTRUÇÕES DE USO:
# =============================================================================
# O script requer 1 argumento obrigatório:
#   1. Arquivo FASTA de entrada (ALINHADO)
#
# A saída será enviada para stdout (redirecione para arquivo).
#
# Exemplo de uso:
#   ./fasta_to_phylip.sh alinhamento.fasta > alinhamento.phy
#
# =============================================================================
#
# DESCRIÇÃO DO FORMATO PHYLIP:
# =============================================================================
# O formato PHYLIP sequencial consiste em:
#
#   <número_de_sequências> <comprimento_do_alinhamento>
#   nome1     SEQUENCIA1
#   nome2     SEQUENCIA2
#   ...
#
# Exemplo:
#   2 10
#   seq1      ATGCTAGCTA
#   seq2      ATGCTAGATA
#
# Observações:
#   - Nomes são limitados a 10 caracteres (formato clássico PHYLIP)
#   - Sequências devem ter exatamente o mesmo comprimento
#
# =============================================================================
#
# PRÉ-REQUISITOS IMPORTANTES:
# =============================================================================
# - O FASTA DEVE conter sequências alinhadas
# - Todas as sequências devem ter o mesmo tamanho
# - Não pode haver entradas vazias
#
# Caso contrário, o PhyML irá falhar
#
# =============================================================================
#
# COMO O SCRIPT FUNCIONA:
# =============================================================================
# 1. Divide o FASTA em registros usando ">" como separador
# 2. Extrai o nome da sequência (cabeçalho)
# 3. Junta linhas de sequência (caso estejam quebradas)
# 4. Armazena tudo em arrays
# 5. Verifica se todas as sequências têm o mesmo tamanho
# 6. Gera saída no formato PHYLIP
#
# =============================================================================

# -----------------------------
# Verificação de argumentos
# -----------------------------
if [ $# -ne 1 ]; then
    echo "ERRO: Número de argumentos incorreto!"
    echo ""
    echo "Uso correto:"
    echo "  $0 <arquivo.fasta>"
    echo ""
    echo "Exemplo:"
    echo "  $0 alinhamento.fasta > alinhamento.phy"
    echo ""
    exit 1
fi

FASTA="$1"

# Verificar se o arquivo existe
if [ ! -f "$FASTA" ]; then
    echo "ERRO: Arquivo não encontrado: $FASTA"
    exit 1
fi

# =============================================================================
# PROCESSAMENTO COM AWK
# =============================================================================
#
# AWK é utilizado para:
# - Ler e processar texto linha a linha
# - Manipular registros FASTA
# - Gerar saída estruturada
#

awk '
# =============================================================================
# FASE BEGIN
# =============================================================================
BEGIN {
    RS=">"        # Cada sequência FASTA é um registro
    FS="\n"       # Linhas dentro do registro
}

# =============================================================================
# PROCESSAMENTO PRINCIPAL
# =============================================================================
NR > 1 {

    # -----------------------------
    # Capturar nome da sequência
    # -----------------------------
    # $1 contém o cabeçalho (sem ">")
    nome = $1

    # Remover espaços extras
    gsub(/^[ \t]+|[ \t]+$/, "", nome)

    # Substituir espaços por underscore
    gsub(/ /, "_", nome)

    # Limitar a 10 caracteres (PHYLIP clássico)
    nome = substr(nome, 1, 10)

    # -----------------------------
    # Montar sequência completa
    # -----------------------------
    seq = ""
    for (i = 2; i <= NF; i++) {
        seq = seq $i
    }

    # Armazenar em arrays
    nomes[++n] = nome
    seqs[n] = seq
}

# =============================================================================
# FASE END
# =============================================================================
END {

    # Verificar se há sequências
    if (n == 0) {
        print "ERRO: Nenhuma sequência encontrada!" > "/dev/stderr"
        exit 1
    }

    # Definir comprimento de referência
    comprimento = length(seqs[1])

    # -----------------------------
    # Validar alinhamento
    # -----------------------------
    for (i = 2; i <= n; i++) {
        if (length(seqs[i]) != comprimento) {
            print "ERRO: Sequências não alinhadas (tamanhos diferentes)!" > "/dev/stderr"
            exit 1
        }
    }

    # -----------------------------
    # Imprimir cabeçalho PHYLIP
    # -----------------------------
    print n, comprimento

    # -----------------------------
    # Imprimir sequências
    # -----------------------------
    for (i = 1; i <= n; i++) {
        printf "%-10s %s\n", nomes[i], seqs[i]
    }
}
' "$FASTA"

# =============================================================================
# FIM DO SCRIPT
# =============================================================================
#
# COMO TESTAR:
# =============================================================================
# 1. Crie um arquivo "teste.fasta":
#
#    >seq1
#    ATGCTAGCTA
#    >seq2
#    ATGCTAGCTA
#
# 2. Execute:
#    ./fasta_to_phylip.sh teste.fasta > teste.phy
#
# 3. Resultado esperado:
#    2 10
#    seq1      ATGCTAGCTA
#    seq2      ATGCTAGCTA
#
# =============================================================================
#
# NOTAS PARA O REPOSITÓRIO:
# =============================================================================
# Este script faz parte do repositório do Laboratório de Genômica e Ecologia Viral
# (LAGEV) da Universidade Federal do Espírito Santo (UFES).
#
# Para citar este script:
#   Delatorre, E. (2026). fasta_to_phylip.sh: Conversão de FASTA para PHYLIP.
#   LAGEV - UFES. https://github.com/lagev-ufes
#
# Licença: MIT
# =============================================================================
