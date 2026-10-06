# Calculadora de Corrida

Calculadora de ganho líquido para motorista de aplicativo (Maxim, Uber, 99, inDrive e corridas avulsas).
Desconta a taxa do app, o combustível e outras taxas (pedágio, estacionamento, lavagem…), registra cada corrida
e gera relatórios do **dia**, da **semana** e do **mês**.

Tem dois motoristas cadastrados, **Iago Adriano** e **Otoniel Monteiro**. Cada um tem a configuração do próprio carro, e os relatórios podem ser filtrados por motorista ou mostrar os dois juntos.

Funciona direto no navegador do celular (Safari ou Chrome). Os dados ficam num banco de dados compartilhado, com login por CPF e senha.

## Como usar

1. Abra o `index.html` no navegador, ou o link do GitHub Pages (veja abaixo).
2. Em **Carro**, configure o consumo (km/l), o preço do litro, a taxa da Maxim e a sua meta mínima de R$/km.
3. No topo, selecione o motorista na lista. A tela abre zerada e só mostra a calculadora e os relatórios depois dessa escolha. Para cada corrida, escolha a origem, preencha o valor, os km (até o passageiro + da corrida), o tempo e as outras taxas, se houver.
   Toque em **Registrar corrida**.
4. Em **Relatório**, alterne entre Dia / Semana / Mês e use as setas ‹ › para mudar o período.
   **Copiar resumo** copia o texto do relatório para você colar no WhatsApp.

### Fórmula

```
taxa do app  = valor × taxa%
combustível  = (km até o passageiro + km da corrida) ÷ consumo × preço do litro
líquido      = valor − taxa do app − combustível − outras taxas
R$/km        = líquido ÷ km rodados
R$/hora      = líquido ÷ minutos × 60
```

Cada corrida guarda o preço do litro e o consumo do momento em que foi registrada. Se você mudar o preço depois, o histórico não muda.

## Onde os dados ficam e o backup

As corridas ficam num **banco de dados no Supabase** (projeto `calculadora-corrida`, servidor em São Paulo), compartilhado entre os
motoristas. Cada motorista entra com **CPF e senha**.

- **Primeiro acesso:** o motorista toca em "Primeiro acesso", digita o código de convite que recebeu, o CPF e cria a senha.
  O convite só vale uma vez.
- **Quem vê o quê:** Iago Adriano é administrador e vê e lança para os dois. Otoniel Monteiro vê e lança só as próprias corridas
  (o banco garante isso, não só a tela).
- **Segurança:** o banco guarda só o hash (bcrypt) do CPF e da senha. Depois de 5 senhas erradas, o acesso fica bloqueado por
  15 minutos. A sessão dura 90 dias em cada celular, ou até tocar em "Sair".
- Cada corrida registrada vai direto para o banco, e o celular guarda uma cópia. Sem internet, a corrida fica no celular e é
  enviada sozinha quando a conexão volta.
- Estrutura do banco: [`supabase/schema.sql`](supabase/schema.sql) e depois [`supabase/login.sql`](supabase/login.sql).
- **Gerar um novo convite** (por exemplo, se alguém esquecer a senha), no SQL Editor:
  `update privado.motoristas set convite_hash = extensions.crypt('novo-convite', extensions.gen_salt('bf')), cpf_hash = null, senha_hash = null where nome = 'Otoniel Monteiro';`

O CSV continua servindo de backup:

- **Exportar CSV:** escolha entre o histórico completo ou só o período aberto. No iPhone, o arquivo vai para o app *Arquivos*
  (pasta Downloads). Mova-o para a pasta [`backup/`](backup/).
- **Importar CSV:** envia para o banco as corridas de um arquivo. As corridas que já existem não são duplicadas
  (a comparação é feita pela coluna `id`).

O CSV usa `;` como separador e vírgula decimal, então abre direto no Excel em português e no Google Planilhas.
A pasta `backup/` tem um exemplo: `corridas-2026-10-05.csv`.

| coluna | significado |
|---|---|
| id | identificador único da corrida |
| data / hora | quando foi registrada |
| motorista | Iago Adriano ou Otoniel Monteiro |
| origem | Maxim, Avulsa, Uber, 99, inDrive |
| valor | valor pago pela corrida (R$) |
| taxa_pct / taxa_app | taxa do aplicativo (% e R$) |
| outras_taxas / outras_desc | outros custos da corrida e a descrição |
| km / minutos | km rodados (busca + corrida) e o tempo |
| preco_litro / consumo_km_l | combustível no momento do registro |
| combustivel / liquido | custo do combustível e quanto sobrou |
| timestamp | data e hora em milissegundos (usado para ordenar) |

## Publicar no GitHub Pages

1. No repositório, abra **Settings → Pages**.
2. Em *Build and deployment*, escolha **Deploy from a branch**, a branch `main` e a pasta `/ (root)`.
3. Em cerca de um minuto, o app fica disponível em `https://<seu-usuario>.github.io/calculadora-corrida/`.
4. No iPhone, abra o link no Safari e toque em **Compartilhar → Adicionar à Tela de Início** para usar como um app.

## Estrutura

```
calculadora-corrida/
├── index.html        app completo (HTML + CSS + JS, sem dependências)
├── backup/           onde guardar os CSV exportados
│   └── corridas-2026-10-05.csv
├── supabase/schema.sql  estrutura do banco de dados
├── supabase/login.sql   login por CPF e senha
├── PROMPT.md         prompt detalhado para evoluir o projeto com IA
└── README.md
```
