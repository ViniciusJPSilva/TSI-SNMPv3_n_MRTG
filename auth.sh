#!/bin/bash

# Tarefa do crontab para atualizar o MRTG
CRONTAB_TASK="* * * * * env LANG=C /usr/bin/mrtg /etc/mrtg/mrtg.cfg"

# Caminho do arquivo de configuração do MRTG
MRTG_CONFIG="/etc/mrtg/mrtg.cfg"

# Função para limpar a tela e sair
clean_exit() {
	clear
	exit 1
}

snmp_start() {
	# Verifica se zenity está instalado
	if command -v zenity &>/dev/null; then
		GUI="zenity"
	elif command -v dialog &>/dev/null; then
		GUI="dialog"
	else
		echo "Nem zenity nem dialog estão instalados. Instale um deles para continuar."
		exit 1
	fi

	while true; do
		# Solicita um endereço IP do usuário
		if [ "$GUI" = "zenity" ]; then
			SERVER_IP=$(zenity --entry --title="Entrada de IP" --text="Digite um endereço IP:")
		else
			SERVER_IP=$(dialog --inputbox "Digite um endereço IP:" 8 50 3>&1 1>&2 2>&3)
		fi

		# Se o usuário não digitou nada, exibe um erro e solicita novamente
		if [ -z "$SERVER_IP" ]; then
			[ "$GUI" = "zenity" ] && zenity --error --text="Nenhum IP informado. Tente novamente." ||
				dialog --msgbox "Nenhum IP informado. Tente novamente." 8 50
			continue
		fi

		# Valida o formato do IP
		if [[ ! "$SERVER_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
			[ "$GUI" = "zenity" ] && zenity --error --text="Endereço IP inválido! Tente novamente." ||
				dialog --msgbox "Endereço IP inválido! Tente novamente." 8 50
			continue
		fi

		# Se chegou até aqui, o IP é válido e sai do loop
		break
	done


	# Solicita o usuário SNMPv3
	if [ "$GUI" = "zenity" ]; then
		USER=$(zenity --entry --title="Usuário SNMPv3" --text="Digite o nome do usuário:")
	else
		USER=$(dialog --inputbox "Digite o nome do usuário:" 8 50 3>&1 1>&2 2>&3)
	fi

	if [ -z "$USER" ]; then
		[ "$GUI" = "zenity" ] && zenity --error --text="Usuário não informado. Saindo..." ||
			dialog --msgbox "Usuário não informado. Saindo..." 8 50
		clean_exit
	fi


	# Solicita a senha de autenticação (-A)
	if [ "$GUI" = "zenity" ]; then
		AUTHPASS=$(zenity --password --title="Senha de Autenticação" --text="Digite a senha de autenticação:")
	else
		AUTHPASS=$(dialog --passwordbox "Digite a senha de autenticação:" 8 50 3>&1 1>&2 2>&3)
	fi

	if [ -z "$AUTHPASS" ]; then
		[ "$GUI" = "zenity" ] && zenity --error --text="Senha de autenticação não informada. Saindo..." ||
			dialog --msgbox "Senha de autenticação não informada. Saindo..." 8 50
		clean_exit
	fi


	# Solicita o arquivo .txt contendo a chave de privacidade (-X)
	if [ "$GUI" = "zenity" ]; then
		KEYFILE=$(zenity --file-selection --title="Selecione o arquivo da chave:")
	else
		KEYFILE=$(dialog --title "Selecione o arquivo da chave:" --fselect "" 0 0 3>&1 1>&2 2>&3)
	fi

	if [ -z "$KEYFILE" ] || [ ! -f "$KEYFILE" ]; then
		[ "$GUI" = "zenity" ] && zenity --error --text="Arquivo inválido ou não encontrado. Saindo..." ||
			dialog --msgbox "Arquivo inválido ou não encontrado. Saindo..." 8 50
		clean_exit
	fi


	# Lê a chave do arquivo
	PRIVKEY=$(cat "$KEYFILE")
	if [ -z "$PRIVKEY" ]; then
		[ "$GUI" = "zenity" ] && zenity --error --text="O arquivo está vazio. Saindo..." ||
			dialog --msgbox "O arquivo está vazio. Saindo..." 8 50
		clean_exit
	fi

	clear

	# Exibe a mensagem de validação sem botões
	if [ "$GUI" = "zenity" ]; then
	    ( echo 50; sleep 1 ) | zenity --progress --title="Autenticação SNMPv3" --text="Validando autenticação..." --no-cancel --pulsate --auto-close &
	    ZENITY_PID=$!
	else
	    dialog --infobox "Validando autenticação..." 8 50
	fi
	
	# Executa a validação SNMPv3
	OID_TEST="1.3.6.1.2.1.1.1.0"
	SNMP_OUTPUT=$(snmpwalk -v3 -l authPriv -u "$USER" -a SHA -A "$AUTHPASS" -x AES -X "$PRIVKEY" -r 1 -t 1 "$SERVER_IP" "$OID_TEST" 2>&1)
	
	# Fecha a janela do zenity (caso ainda esteja aberta)
	if [ "$GUI" = "zenity" ]; then
	    wait $ZENITY_PID 2>/dev/null
	else
	    clear
	fi

	if echo "$SNMP_OUTPUT" | grep -Eqi "Error|error|Timeout|timeout|Authentication failure|incorrect|Unknown user|decryption error|usmStats"; then
		[ "$GUI" = "zenity" ] && zenity --error --text="Erro na autenticação SNMPv3! Verifique suas credenciais e tente novamente." ||
			dialog --msgbox "Erro na autenticação SNMPv3! Verifique suas credenciais e tente novamente." 8 50
		clean_exit
	else
		# Autenticação bem-sucedida, continue com o script
		[ "$GUI" = "zenity" ] && zenity --info --text="Autenticação SNMPv3 bem-sucedida! Finalizando as configurações..." ||
			dialog --msgbox "Autenticação SNMPv3 bem-sucedida! Finalizando as configurações..." 8 50
	fi

	
	# Criar diretório para o MRTG
	mkdir -p /var/www/html/mrtg

	# Gera o arquivo de configuração básico do MRTG
	cfgmaker --global 'WorkDir: /var/www/html/mrtg' --global 'Options[_]: growright,bits' \
	        --enablesnmpv3 --snmp-options=:::::3 \
	        --username=$USER --authprotocol=SHA --authpassword=$AUTHPASS \
	        --privprotocol=aes --privpassword=$PRIVKEY \
		--contextengineid=0x  --output $MRTG_CONFIG $SERVER_IP > /dev/null 2>&1

    # Adiciona configurações e monitoramentos extras ao mrtg.cfg
    cat <<EOF >> $MRTG_CONFIG

Interval: 60
Language: brazilian
LoadMIBs: /usr/share/snmp/mibs/UCD-SNMP-MIB.txt

### Memória livre
Target[freemem]: .1.3.6.1.4.1.2021.4.6.0&.1.3.6.1.4.1.2021.4.6.0:public@$SERVER_IP:::::3
SnmpOptions[freemem]: privprotocol=>'aes',authpassword=>'$AUTHPASS',username=>'$USER',privpassword=>'$PRIVKEY',authprotocol=>'sha'
MaxBytes[freemem]: 2048000
Step[freemem]: 60
kMG[freemem]: KB,MB
kilo[freemem]: 1024
Title[freemem]: Memória Livre
PageTop[freemem]: <h1>Memória RAM livre (sem SWAP)</h1>
YLegend[freemem]: Disponivel
ShortLegend[freemem]:
Options[freemem]: growright,gauge,nopercent
LegendI[freemem]: RAM livre:
LegendO[freemem]:
Legend1[freemem]: Memória RAM livre

### CPU
Target[cpu]:.1.3.6.1.4.1.2021.11.50.0&.1.3.6.1.4.1.2021.11.52.0:public@$SERVER_IP:::::3
SnmpOptions[cpu]: privprotocol=>'aes',authpassword=>'$AUTHPASS',username=>'$USER',privpassword=>'$PRIVKEY',authprotocol=>'sha'
MaxBytes[cpu]: 100
Title[cpu]: Uso da CPU
PageTop[cpu]: <H1>Uso da CPU (%)</H1>
ShortLegend[cpu]: %
YLegend[cpu]: Porcentagem (%)
Legend1[cpu]: Uso ativo da CPU do Usuário (%)
Legend2[cpu]: Uso ativo da CPU do Sistema (%)
Legend3[cpu]:
Legend4[cpu]:
LegendI[cpu]: CPU Ativa (Usuário)
LegendO[cpu]: CPU Ativa (Sistema)
Options[cpu]: growright,nopercent

### Disk
Target[disk]: .1.3.6.1.4.1.2021.9.1.9.1&.1.3.6.1.4.1.2021.9.1.9.2:public@$SERVER_IP:::::3
SnmpOptions[disk]: privprotocol=>'aes',authpassword=>'$AUTHPASS',username=>'$USER',privpassword=>'$PRIVKEY',authprotocol=>'sha'
MaxBytes[disk]: 100
Title[disk]: USO DE DISCO
PageTop[disk]: <H1>Uso do Disco / e /home (%)</H1>
Unscaled[disk]: ymwd
ShortLegend[disk]: %
YLegend[disk]: Uso do Disco (%)
Legend1[disk]: Disco raiz (/)
Legend2[disk]: Disco /home
Legend3[disk]:
Legend4[disk]:
LegendI[disk]: Disco raiz (/)
LegendO[disk]: Disco /home
Options[disk]: growright,gauge,nopercent

### Processos
Target[processes]: .1.3.6.1.2.1.25.1.6.0&.1.3.6.1.2.1.25.1.6.0:public@$SERVER_IP:::::3
SnmpOptions[processes]: privprotocol=>'aes',authpassword=>'$AUTHPASS',username=>'$USER',privpassword=>'$PRIVKEY',authprotocol=>'sha'
MaxBytes[processes]: 1000
Factor[processes]: 1
Title[processes]: PROCESSOS EM EXECUÇÃO
PageTop[processes]: <H1>Quantidade de Processos em Execução</H1>
Unscaled[processes]: ymwd
ShortLegend[processes]: Processos
YLegend[processes]: Nro de Processos
Legend1[processes]: Processos em Execução
Legend2[processes]:
Legend3[processes]:
Legend4[processes]:
LegendI[processes]: Em Execução
LegendO[processes]:
Options[processes]: growright,gauge,nopercent

EOF

    # Adiciona tarefa ao crontab
    (crontab -l 2>/dev/null; echo "$CRONTAB_TASK") | crontab -

    # Gera os gráficos iniciais
    env LANG=C /usr/bin/mrtg $MRTG_CONFIG > /dev/null 2>&1
    sleep 3;
    indexmaker $MRTG_CONFIG > /var/www/html/mrtg/index.html
    env LANG=C /usr/bin/mrtg $MRTG_CONFIG > /dev/null

    clear
}

snmp_stop() {
	rm -rf /var/www/html/mrtg
	rm -rf /etc/mrtg/mrtg.cfg
	(crontab -l 2>/dev/null | grep -Fxv "$CRONTAB_TASK") | crontab -

        # Autenticação bem-sucedida, continue com o script
        [ "$GUI" = "zenity" ] && zenity --info --text="Arquivos apagados!" ||
                dialog --msgbox "Arquivos apagados!" 8 50

	clean_exit
}

snmp_help() {
clear

cat <<EOF | more

NOME
    $(basename "$0") - Script para configuração e monitoramento SNMPv3 com MRTG

SINOPSE
    $(basename "$0") {start|stop|help}

DESCRIÇÃO
    Este script permite configurar e gerenciar o monitoramento de dispositivos via SNMPv3
    utilizando o MRTG. Durante a operação, o script realiza as seguintes tarefas:
      - start: Inicia um processo interativo para coletar os parâmetros necessários (IP,
               usuário, senha de autenticação e arquivo com chave de privacidade) e gera
               os arquivos de configuração do MRTG, além de agendar tarefas no crontab.
      - stop: Remove as configurações do MRTG, limpa os arquivos gerados e remove a tarefa
              agendada no crontab.
      - help: Exibe esta mensagem de ajuda, no estilo do comando "man <comando>" do Linux.

OPÇÕES
    start
        Inicia o processo de configuração SNMPv3. Durante este modo, o script:
          * Solicita o endereço IP do servidor.
          * Solicita o nome do usuário SNMPv3.
          * Solicita a senha de autenticação.
          * Solicita o arquivo contendo a chave de privacidade.
          * Valida as credenciais SNMPv3 e gera os arquivos de configuração para o MRTG.
          * Agenda uma tarefa no crontab para a atualização periódica do MRTG.
          * Gera gráficos iniciais e configura a interface web do MRTG.

    stop
        Encerra o monitoramento removendo:
          * O diretório e os arquivos de configuração do MRTG.
          * A tarefa agendada no crontab para a atualização do MRTG.

    help
        Exibe esta mensagem de ajuda com detalhes sobre o uso do script.

EXEMPLOS
    Para iniciar a configuração e o monitoramento:
        $(basename "$0") start

    Para interromper e limpar as configurações:
        $(basename "$0") stop

    Para exibir esta mensagem de ajuda:
        $(basename "$0") help

EOF
}

case $1 in
	start	) snmp_start ;;
	stop	) snmp_stop ;;
	help	) snmp_help ;;
	*	) echo -e "\n\tUse: $0 {start | stop | help}\n" ;;
esac

