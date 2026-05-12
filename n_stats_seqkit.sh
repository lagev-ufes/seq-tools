#!/usr/bin/env bash
# =============================================================================
# Script: n_stats_seqkit.sh
# Descrição: Calcula estatísticas de Ns (bases indefinidas) em sequências FASTA,
#            ignorando gaps (-) e espaços. Funciona com FASTA multilinha,
#            sequências com gaps, cabeçalhos complexos, etc.
#
# Autor: Edson Delatorre
# Laboratório: Laboratório de Genômica e Ecologia Viral (LAGEV) - UFES
# Data: 2026-04-29
# Versão: 2.0 (genérico)
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

uso() {
    cat << EOF
Uso: $0 <arquivo.fasta> [opções]

Opções:
  -g, --include-gaps  Incluir gaps no comprimento total (padrão: excluir)
  -h, --help          Mostrar esta ajuda

Exemplos:
  $0 sequencias.fasta
  $0 --include-gaps sequencias.fasta > stats.tsv

Saída:
  Seq_ID  Length  N_count  N_ratio  N_perc(%)
  Average comprimento médio, ratio médio e percentual médio

EOF
    exit 0
}

########################################
# Parâmetros padrão
########################################

INCLUDE_GAPS=false

# Processar argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        -g|--include-gaps)
            INCLUDE_GAPS=true
            shift
            ;;
        -h|--help)
            uso
            ;;
        *)
            if [[ -z "${INFILE:-}" ]]; then
                INFILE="$1"
                shift
            else
                erro "Argumento desconhecido: $1"
            fi
            ;;
    esac
done

# Validar arquivo de entrada
if [[ -z "${INFILE:-}" ]]; then
    erro "Arquivo de entrada não especificado"
fi

[[ -f "$INFILE" ]] || erro "Arquivo não encontrado: $INFILE"

########################################
# Verificar dependências
########################################

# Verificar se awk está disponível (sempre presente)
if ! command -v awk >/dev/null 2>&1; then
    erro "awk não encontrado. Instale o pacote gawk ou mawk."
fi

# Verificar seqkit (opcional, mas recomendado)
if command -v seqkit >/dev/null 2>&1; then
    USE_SEQKIT=true
    log "seqkit detectado: $(seqkit version 2>&1 | head -1)"
else
    USE_SEQKIT=false
    log "seqkit não encontrado. Usando awk puro (mais lento para arquivos grandes)."
fi

########################################
# Função para processar com AWK puro (genérico)
########################################

process_awk_puro() {
    awk -v include_gaps="$INCLUDE_GAPS" '
    BEGIN {
        # Cabeçalho da saída
        printf "Seq_ID\tLength\tN_count\tN_ratio\tN_perc(%%)\n"
        
        # Inicializar variáveis
        seq_id = ""
        seq = ""
        total_len = 0
        total_n_ratio = 0
        total_n_perc = 0
        count = 0
    }
    
    # Linha de cabeçalho
    /^>/ {
        # Processar sequência anterior (se existir)
        if (seq_id != "") {
            process_sequence(seq_id, seq)
        }
        
        # Novo cabeçalho (remove o ">" e espaços extras)
        seq_id = substr($0, 2)
        gsub(/^[ \t]+|[ \t]+$/, "", seq_id)
        seq = ""
        next
    }
    
    # Linhas de sequência (acumular)
    {
        seq = seq $0
    }
    
    # Processar última sequência
    END {
        if (seq_id != "") {
            process_sequence(seq_id, seq)
        }
        
        # Mostrar médias
        if (count > 0) {
            printf "\nAverage\t%.0f\t%.6f\t%.2f\n",
                   total_len/count, total_n_ratio/count, total_n_perc/count
        }
    }
    
    function process_sequence(id, s) {
        # Remover espaços em branco e caracteres de controle
        gsub(/[[:space:]]/, "", s)
        
        # Contar comprimento total (com ou sem gaps)
        if (include_gaps == "true") {
            len_total = length(s)
        } else {
            # Remover gaps (hífens) e pontos (.) - common em alinhamentos
            gsub(/[-.]/, "", s)
            len_total = length(s)
        }
        
        # Caso especial: sequência vazia ou só gaps
        if (len_total == 0) {
            printf "%s\t%d\t%d\t%.2f\t%.2f\n", id, 0, 0, 0, 0
            count++
            return
        }
        
        # Contar Ns (case insensitive)
        s_copy = s
        n_count = gsub(/[Nn]/, "", s_copy)
        
        # Calcular proporções
        n_perc = (n_count / len_total) * 100
        
        if (len_total - n_count > 0) {
            n_ratio = n_count / (len_total - n_count)
        } else {
            n_ratio = 0
        }
        
        # Saída para esta sequência
        printf "%s\t%d\t%d\t%.6f\t%.2f\n", id, len_total, n_count, n_ratio, n_perc
        
        # Acumular para médias
        total_len += len_total
        total_n_ratio += n_ratio
        total_n_perc += n_perc
        count++
    }
    ' "$1"
}

########################################
# Função para processar com seqkit (mais rápido)
########################################

process_seqkit() {
    if [[ "$INCLUDE_GAPS" == "true" ]]; then
        # Incluir gaps no comprimento
        seqkit fx2tab -n -l -s "$1" | \
        awk '
        BEGIN {
            printf "Seq_ID\tLength\tN_count\tN_ratio\tN_perc(%%)\n"
            total_len = 0
            total_n_ratio = 0
            total_n_perc = 0
            count = 0
        }
        {
            id = $1
            len_total = $2
            seq = $3
            
            # Remover quebras de linha e espaços
            gsub(/[[:space:]]/, "", seq)
            
            if (len_total == 0) {
                printf "%s\t%d\t%d\t%.2f\t%.2f\n", id, 0, 0, 0, 0
                count++
                next
            }
            
            # Contar Ns
            seq_copy = seq
            n_count = gsub(/[Nn]/, "", seq_copy)
            
            n_perc = (n_count / len_total) * 100
            
            if (len_total - n_count > 0) {
                n_ratio = n_count / (len_total - n_count)
            } else {
                n_ratio = 0
            }
            
            printf "%s\t%d\t%d\t%.6f\t%.2f\n", id, len_total, n_count, n_ratio, n_perc
            
            total_len += len_total
            total_n_ratio += n_ratio
            total_n_perc += n_perc
            count++
        }
        END {
            if (count > 0) {
                printf "\nAverage\t%.0f\t%.6f\t%.2f\n",
                       total_len/count, total_n_ratio/count, total_n_perc/count
            }
        }'
    else
        # Excluir gaps do comprimento (recomendado)
        seqkit seq -n -s "$1" | \
        awk '
        BEGIN {
            printf "Seq_ID\tLength\tN_count\tN_ratio\tN_perc(%%)\n"
            total_len = 0
            total_n_ratio = 0
            total_n_perc = 0
            count = 0
        }
        /^>/ {
            if (seq != "") {
                process_sequence(id, seq)
            }
            id = substr($0, 2)
            seq = ""
            next
        }
        {
            seq = seq $0
        }
        END {
            if (seq != "") {
                process_sequence(id, seq)
            }
        }
        function process_sequence(id, s) {
            # Remover gaps e espaços
            gsub(/[-.[:space:]]/, "", s)
            len_total = length(s)
            
            if (len_total == 0) {
                printf "%s\t%d\t%d\t%.2f\t%.2f\n", id, 0, 0, 0, 0
                count++
                return
            }
            
            s_copy = s
            n_count = gsub(/[Nn]/, "", s_copy)
            n_perc = (n_count / len_total) * 100
            
            if (len_total - n_count > 0) {
                n_ratio = n_count / (len_total - n_count)
            } else {
                n_ratio = 0
            }
            
            printf "%s\t%d\t%d\t%.6f\t%.2f\n", id, len_total, n_count, n_ratio, n_perc
            
            total_len += len_total
            total_n_ratio += n_ratio
            total_n_perc += n_perc
            count++
        }
        END {
            if (count > 0) {
                printf "\nAverage\t%.0f\t%.6f\t%.2f\n",
                       total_len/count, total_n_ratio/count, total_n_perc/count
            }
        }'
    fi
}

########################################
# Execução principal
########################################

log "Processando arquivo: $INFILE"
log "Incluir gaps no comprimento: $INCLUDE_GAPS"

# Escolher método
if [[ "$USE_SEQKIT" == "true" ]]; then
    log "Usando seqkit (modo rápido)"
    process_seqkit "$INFILE"
else
    log "Usando awk puro (modo compatível)"
    process_awk_puro "$INFILE"
fi

log "Processamento concluído!"
