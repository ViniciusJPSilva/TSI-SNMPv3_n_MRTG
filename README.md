
# TSI-SNMPv3_n_MRTG

![image](https://github.com/user-attachments/assets/df1b2832-079e-46b6-a805-ca75cc17b4e8)


<div align="justify">
  Este repositório oferece um conjunto completo de scripts e procedimentos para a configuração e monitoramento de dispositivos via SNMPv3 em combinação com o MRTG (Multi Router Traffic Grapher). O processo inclui a instalação de pacotes necessários, a criação de usuários SNMPv3 com mecanismos de autenticação e privacidade, e a utilização de scripts automatizados para facilitar a configuração do monitoramento de tráfego de rede e outros recursos do sistema, como CPU, memória e espaço em disco.
</div>

<br><hr><br>

## Pré-requisitos

<div align="justify">
  Antes de iniciar a configuração e monitoramento com SNMPv3 e MRTG, é necessário ter um servidor web (Apache, Nginx, ou similar) configurado e em funcionamento no <strong>cliente</strong>. O diretório base onde os arquivos index serão gerados e acessados via navegador será em <strong>/var/www/html/mrtg</strong> . Certifique-se de que o servidor web esteja instalado e configurado corretamente para permitir o acesso aos gráficos gerados pelo MRTG.
<br><br>
Certifique-se de que o servidor web esteja instalado e configurado corretamente para permitir o acesso aos gráficos gerados pelo MRTG.
</div>

<br><hr><br>

## Procedimentos para Configuração e Monitoramento com SNMPv3 e MRTG

### Configuração do Agente (Servidor)

<br>

1. **Instalar Pacotes SNMP**

   Instale os pacotes necessários para o funcionamento do SNMP no servidor:

   ```bash
   dnf install net-snmp net-snmp-utils -y
   ```

<br>

2. **Criar Usuário SNMPv3**

   Para criar um usuário SNMPv3 configurado com autenticação (SHA) e privacidade (AES), execute o seguinte comando:

   ```bash
   net-snmp-create-v3-user -ro -A <SENHA> -a SHA -X <CHAVE> -x AES <USUARIO>
   ```

   Onde:
   - `<SENHA>`: Senha para o usuário, a qual será utilizada para a autenticação.
   - `<CHAVE>`: Chave simétrica para privacidade. Pode ser uma chave pré-gerada ou uma string simples que será utilizada como chave.
   - `<USUARIO>`: Nome do usuário SNMP a ser criado.

<br>

3. **Configurar Arquivo /etc/snmp/snmpd.conf**

   No arquivo de configuração `snmpd.conf`, adicione as seguintes entradas:

   - Para definir as views do SNMP:

     ```bash
     view    viewTest       included      .1
     ```

   - No final do arquivo, adicione a configuração de monitoramento de discos:

     ```bash
     disk / 1000000
     disk /home 600000
     ```

<br>

4. **Ativar e Iniciar o SNMP**

   Para garantir que o serviço SNMP seja habilitado e iniciado automaticamente, execute:

   ```bash
   systemctl enable snmp --now
   ```

<br><br>

### Configuração do Gerente (Cliente)

<br>

1. **Instalar Pacotes SNMP, MRTG e Dependências**

   Instale os pacotes necessários para habilitar o SNMP e configurar o MRTG para o monitoramento:

   ```bash
   dnf install epel-release -y
   dnf install net-snmp net-snmp-utils mrtg git -y
   dnf install perl-Net-SNMP -y
   dnf install perl-Crypt-Rijndael -y
   ```

<br>

2. **Ativar SNMP no Cliente**

   Para iniciar o SNMP no cliente e garantir que o serviço seja executado automaticamente, use:

   ```bash
   systemctl enable snmp --now
   ```

<br>

3. **Teste de Conexão SNMP**

   Realize um teste de consulta SNMP ao servidor, utilizando os parâmetros de autenticação e privacidade configurados:

   ```bash
   snmpwalk -u <USUARIO> -A <SENHA> -a SHA -X <CHAVE> -x AES -l authPriv <IP DO SERVER> -v3 .
   ```

<br>

4. **Gerar e Utilizar a CHAVE**

    Caso tenha optado por utilizar um texto simples como chave de privacidade, crie um arquivo contendo o valor da chave. Isso é necessário, pois o comando de configuração do MRTG requer que a chave seja fornecida através de um arquivo.

<br>

5. **Clonar o repositório**

    Para clonar o repositório e obter os arquivos necessários, execute:

    ```bash
    git clone https://github.com/ViniciusJPSilva/TSI-SNMPv3_n_MRTG
    cd TSI-SNMPv3_n_MRTG
    ```

<br>

6. **Utilização do Script de Configuração e Monitoramento**

    Primeiramente, dê as devidas permissões de execução para o script `auth.sh`:

    ```bash
    chmod +x auth.sh
    ```

   O script `auth.sh` é utilizado para configurar e gerenciar o monitoramento via SNMPv3 com MRTG. O script oferece três opções de operação:

   ```bash
   ./auth {start | stop | help}
   ```

   - `start`: Inicia o processo de configuração, coletando os parâmetros necessários (endereço IP do servidor, usuário, senha de autenticação e arquivo com chave de privacidade), gerando os arquivos de configuração do MRTG e agendando as tarefas no crontab.
   - `stop`: Remove as configurações do MRTG, limpa os arquivos gerados e cancela a tarefa agendada no crontab.
   - `help`: Exibe uma descrição detalhada sobre o funcionamento do comando, similar à saída do comando `man` do Linux.

<br><hr><br>

### Documentação MRTG

[Documentação MRTG](https://oss.oetiker.ch/mrtg/doc/)
