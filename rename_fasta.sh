#!/bin/bash
# =============================================================================
# Script: rename_fasta.sh
# Descrição: Renomeia cabeçalhos de arquivos FASTA usando busca por substring
#            em uma tabela de mapeamento. Ideal para renomear sequências do GISAID
#            ou qualquer repositório onde o identificador aparece no cabeçalho.
#
# Autor: Edson Delatorre
# Laboratório: Laboratório de Genômica e Ecologia Viral (LAGEV) - UFES
# Repositório: https://github.com/lagev-ufes
# Data: 2026-04-01
# Versão: 1.0
# =============================================================================
#
# INSTRUÇÕES DE USO:
# =============================================================================
# O script requer 2 argumentos:
#   1. Arquivo de tabela com termos de busca e novos nomes (TAB-separated)
#   2. Arquivo FASTA de entrada
#
# Exemplo de uso:
#   ./rename_fasta.sh tabela_ids.txt sequencias.fasta > sequencias_renomeadas.fasta
#
# Formato do arquivo de tabela (tabela_ids.txt):
#   <termo_de_busca>   <novo_nome>
#
# Exemplos de termos de busca:
#   EPI_ISL_17460310    EPI_ISL_17460310_2018-03-20_SP_Sao_Paulo
#   17460310            EPI_ISL_17460310_2018-03-20_SP_Sao_Paulo
#   hCoV-19/Brazil      SARS-CoV-2_Brazil_2020
#   MN908947            SARS-CoV-2_Wuhan_2019
#
# Como funciona:
#   - O script busca cada termo da primeira coluna da tabela dentro do cabeçalho
#     do FASTA (linhas que começam com ">")
#   - A busca é feita por substring (index), ou seja, se o termo aparecer em
#     qualquer parte do cabeçalho, haverá correspondência
#   - Quando encontra correspondência, substitui todo o cabeçalho pelo novo nome
#   - A primeira correspondência encontrada é usada (ordem da tabela importa)
#   - Linhas que não são cabeçalho (sequências) são mantidas inalteradas
#
# Vantagens da busca por substring:
#   - Flexível: não precisa do formato exato do cabeçalho original
#   - Funciona com qualquer tipo de identificador (Accession ID, número, etc.)
#   - Permite usar apenas parte do identificador (ex: números isolados)
#   - Ideal para trabalhar com dados do GISAID, GenBank, ou bancos próprios
#
# Observações importantes:
#   - A tabela deve usar TAB como separador entre as colunas
#   - O script é case-sensitive (diferencia maiúsculas de minúsculas)
#   - Termos de busca muito curtos podem causar correspondências falsas
#   - Exemplo: buscar "123" pode casar com "12345" ou "ABC123XYZ"
#   - Recomenda-se usar termos de busca específicos (ex: "EPI_ISL_12345")
#   - Se nenhum termo de busca for encontrado, o cabeçalho original é mantido
#   - A saída é enviada para stdout; use redirecionamento para salvar em arquivo
#
# Exemplo de execução:
#   $ ./rename_fasta.sh mapping.txt sequences.fasta > renamed_sequences.fasta
#
# =============================================================================

# Verificar se o número de argumentos está correto
if [ $# -ne 2 ]; then
    echo "ERRO: Número de argumentos incorreto!"
    echo ""
    echo "Uso correto:"
    echo "  $0 <tabela_ids.txt> <arquivo.fasta>"
    echo ""
    echo "Exemplo:"
    echo "  $0 mapping.txt sequences.fasta > renamed_sequences.fasta"
    echo ""
    echo "Para mais informações, consulte os comentários no início do script."
    exit 1
fi

# Processar o arquivo FASTA usando awk
# awk é uma ferramenta de processamento de texto que permite manipular linhas e campos
awk -v map_file="$1" '
# =============================================================================
# FASE BEGIN: Executada uma vez antes de processar o arquivo FASTA
# =============================================================================
BEGIN {
    # Carregar o arquivo de mapeamento (tabela com termos de busca e novos nomes)
    # A variável map_file foi passada com -v na linha de comando
    
    # Lê cada linha do arquivo de mapeamento
    # getline lê uma linha do arquivo; a condição (getline < map_file) > 0 
    # significa "enquanto houver linhas para ler"
    while ((getline < map_file) > 0) {
        # $1 = primeira coluna (termo de busca)
        # $2 = segunda coluna (novo nome)
        # O separador padrão do awk é qualquer espaço em branco, mas como o arquivo
        # usa TAB, ele funcionará corretamente
        
        busca = $1      # Termo que será procurado no cabeçalho do FASTA
        novo_nome = $2  # Novo nome que substituirá o cabeçalho inteiro
        
        # Armazenar os dados em arrays indexados numericamente
        # count é um contador que começa em 0 e vai aumentando
        # busca_list[1] = primeiro termo de busca
        # nome_list[1] = primeiro novo nome
        # busca_list[2] = segundo termo de busca, e assim por diante
        busca_list[++count] = busca
        nome_list[count] = novo_nome
    }
    
    # Fechar o arquivo de mapeamento após a leitura
    close(map_file)
}

# =============================================================================
# PROCESSAMENTO PRINCIPAL: Executado para cada linha do arquivo FASTA
# =============================================================================
{
    # Verificar se a linha atual é um cabeçalho
    # Cabeçalhos no formato FASTA começam com o caractere ">"
    if ($0 ~ /^>/) {
        # Variável de controle para indicar se encontrou correspondência
        encontrado = 0
        
        # Percorrer todos os termos de busca na ordem em que foram carregados
        # A ordem é importante: a primeira correspondência encontrada será usada
        for (i = 1; i <= count; i++) {
            # Buscar o termo de busca atual no cabeçalho
            # A função index() procura por uma substring literal
            # index(string, substring) retorna a posição onde substring aparece,
            # ou 0 se não for encontrada
            #
            # Exemplo: index(">EPI_ISL_12345|data", "EPI_ISL_12345") retorna 2
            # Exemplo: index(">hCoV-19/Brazil", "Brazil") retorna 9
            if (index($0, busca_list[i]) > 0) {
                # Encontrou correspondência!
                # Imprimir o novo cabeçalho (adicionando ">" no início)
                # O novo nome já deve conter todas as informações desejadas
                print ">" nome_list[i]
                
                # Marcar que encontrou e sair do loop
                encontrado = 1
                break
            }
        }
        
        # Se NENHUM termo de busca foi encontrado neste cabeçalho
        if (!encontrado) {
            # Manter o cabeçalho original inalterado
            print $0
        }
    } else {
        # Linha que NÃO é cabeçalho (sequência de nucleotídeos/aminoácidos)
        # Imprimir a sequência sem nenhuma modificação
        print $0
    }
}' "$2"

# =============================================================================
# FIM DO SCRIPT
# =============================================================================
# 
# COMO TESTAR:
# =============================================================================
# 1. Crie um arquivo de teste chamado "test_mapping.txt" com:
#    EPI_ISL_17460310	EPI_ISL_17460310_2018_SP
#    17460313	EPI_ISL_17460313_2018_RJ
#
# 2. Crie um arquivo FASTA de teste chamado "test_sequences.fasta" com:
#    >hChikV/Brazil/un-Fiocruz-00060/2018|EPI_ISL_17460310|2018-03-20
#    CCTGTGTACGTGGACATAGACGCTGA
#    >hChikV/Brazil/un-Fiocruz-00051/2018|EPI_ISL_17460313|2018-06-06
#    ATGGATCCTGTGTACGTGGACATAGA
#
# 3. Execute:
#    ./rename_fasta.sh test_mapping.txt test_sequences.fasta
#
# 4. Resultado esperado:
#    >EPI_ISL_17460310_2018_SP
#    CCTGTGTACGTGGACATAGACGCTGA
#    >EPI_ISL_17460313_2018_RJ
#    ATGGATCCTGTGTACGTGGACATAGA
#
# =============================================================================
# NOTAS PARA O REPOSITÓRIO:
# =============================================================================
# Este script faz parte do repositório do Laboratório de Genômica e Ecologia Viral
# (LAGEV) da Universidade Federal do Espírito Santo (UFES).
#
# Para citar este script em trabalhos acadêmicos:
#   Delatorre, E. (2026). rename_fasta.sh: Ferramenta para renomeação de cabeçalhos
#   de sequências FASTA. Laboratório de Genômica e Ecologia Viral (LAGEV) - UFES.
#   Disponível em: https://github.com/lagev-ufes
#
# Licença: MIT (permissiva para uso acadêmico e comercial)
# =============================================================================
