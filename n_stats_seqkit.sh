#!/usr/bin/env bash
# =============================================================================
# Script: n_stats_seqkit.sh
# Descrição: Calcula estatísticas de Ns (bases indefinidas) em sequências FASTA,
#            incluindo comprimento, contagem de Ns, razão N/(não-N) e proporção
#            de Ns. Utiliza seqkit para parsing eficiente e awk para cálculo.
#
# Autor: Edson Delatorre
# Laboratório: Laboratório de Genômica e Ecologia Viral (LAGEV) - UFES
# Repositório: https://github.com/lagev-ufes
# Data: 2026-04-29
# Versão: 1.0
# =============================================================================
#
# INSTRUÇÕES DE USO:
# =============================================================================
# O script requer 1 argumento:
#   1. Arquivo FASTA de entrada
#
# Exemplo de uso:
#   ./n_stats_seqkit.sh sequencias.fasta > estatisticas.tsv
#
# Saída:
#   Seq_ID   Length   N_count   N_ratio   N_perc
#
# Onde:
#   - Seq_ID   : identificador da sequência
#   - Length   : comprimento total da sequência
#   - N_count  : número de bases 'N' ou 'n'
#   - N_ratio  : razão N / (bases não-N)
#   - N_perc   : proporção de Ns em relação ao comprimento total
#
# Também são calculadas médias ao final:
#   - Comprimento médio
#   - N_ratio médio
#   - N_perc médio
#
# =============================================================================
# DEPENDÊNCIAS:
# =============================================================================
# Este script depende da ferramenta:
#   - seqkit (https://bioinf.shenwei.me/seqkit/)
#
# O script verifica automaticamente se o seqkit está instalado.
# Caso não esteja, tenta instalar utilizando:
#   - conda / mamba (preferencial)
#   - apt (Linux)
#   - brew (macOS)
#
# Caso nenhuma opção esteja disponível, instruções de instalação são exibidas.
#
# =============================================================================
# COMO FUNCIONA:
# =============================================================================
# 1. seqkit fx2tab converte o FASTA em formato tabular:
#    -n : nome da sequência
#    -l : comprimento
#    -i : ID simplificado
#    -s : sequência completa
#
# 2. awk processa cada linha:
#    - calcula comprimento (length)
#    - conta Ns (gsub)
#    - calcula proporções
#    - acumula métricas globais
#
# 3. Ao final (END), calcula médias
#
# =============================================================================
# OBSERVAÇÕES IMPORTANTES:
# =============================================================================
# - O cálculo de N_ratio é definido como:
#     N / (Length - N)
#
# - Se uma sequência contiver apenas Ns, a razão é definida como 0
#   para evitar divisão por zero
#
# - O script é case-insensitive para Ns (considera N e n)
#
# - A saída é enviada para stdout
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
# Verificação de dependência: seqkit
########################################

instalar_seqkit() {
    log "seqkit não encontrado. Tentando instalar..."

    if command -v conda >/dev/null 2>&1; then
        log "Instalando via conda (bioconda)..."
        conda install -y -c bioconda seqkit

    elif command -v mamba >/dev/null 2>&1; then
        log "Instalando via mamba..."
        mamba install -y -c bioconda seqkit

    elif command -v apt-get >/dev/null 2>&1; then
        log "Instalando via apt..."
        sudo apt-get update
        sudo apt-get install -y seqkit || \
            erro "Pacote seqkit não disponível via apt. Use conda."

    elif command -v brew >/dev/null 2>&1; then
        log "Instalando via Homebrew..."
        brew install seqkit

    else
        erro "Nenhum gerenciador de pacotes suportado encontrado.

Instalação manual:
  conda install -c bioconda seqkit
  ou baixar em:
  https://bioinf.shenwei.me/seqkit/download/"
    fi
}

########################################
# Validação de entrada
########################################

if [[ $# -ne 1 ]]; then
    echo "ERRO: Número de argumentos incorreto!"
    echo ""
    echo "Uso:"
    echo "  $0 <arquivo.fasta>"
    echo ""
    echo "Exemplo:"
    echo "  $0 sequencias.fasta > estatisticas.tsv"
    exit 1
fi

infile="$1"

[[ -f "$infile" ]] || erro "Arquivo não encontrado: $infile"

########################################
# Garantir disponibilidade do seqkit
########################################

if ! command -v seqkit >/dev/null 2>&1; then
    instalar_seqkit
fi

command -v seqkit >/dev/null 2>&1 || erro "Falha ao instalar seqkit."

log "seqkit detectado: $(seqkit version)"
log "Processando arquivo: $infile"

########################################
# Execução principal
########################################

echo -e "Seq_ID\tLength\tN_count\tN_ratio\tN_perc"

seqkit fx2tab -n -l -i -s "$infile" | \
awk '
{
    seq=$4
    len=length(seq)

    # Contar Ns (N ou n)
    n_count=gsub(/[Nn]/,"",seq)

    # Proporção de Ns
    n_perc=n_count/len

    # Razão N / não-N
    if (len-n_count > 0) {
        n_ratio=n_count/(len-n_count)
    } else {
        n_ratio=0
    }

    # Acumuladores globais
    total_len += len
    n_ratio_t += n_ratio
    n_perc_t  += n_perc
    seq_ct++

    # Saída por sequência
    printf "%s\t%d\t%d\t%.2f\t%.2f\n",$1,len,n_count,n_ratio,n_perc
}

END {
    if (seq_ct > 0) {
        printf "\nAverage length, N-ratio and N-percent for input :   %.0f\t%.2f\t%.2f\n",
        total_len/seq_ct, n_ratio_t/seq_ct, n_perc_t/seq_ct
    }
}'
