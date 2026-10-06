# Calculadora de Corrida

Calculadora de ganho líquido para motorista de aplicativo (Maxim, Uber, 99, inDrive e corridas avulsas).
Desconta a taxa do app, o combustível e outras taxas (pedágio, estacionamento, lavagem…), registra cada corrida
e gera relatórios do **dia**, da **semana** e do **mês**.

Tem dois motoristas cadastrados, **Iago Adriano** e **Otoniel Monteiro**. Cada um tem a configuração do próprio carro, e os relatórios podem ser filtrados por motorista ou mostrar os dois juntos.

Funciona direto no navegador do celular (Safari ou Chrome), sem login e sem servidor.

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

As corridas ficam salvas **no próprio navegador** (localStorage). Cada pessoa e cada aparelho tem o seu histórico.
Você perde o histórico se limpar os dados do navegador, usar o modo privado ou trocar de celular. Por isso, faça backup:

- **Exportar CSV:** escolha entre o histórico completo ou só o período aberto. No iPhone, o arquivo vai para o app *Arquivos*
  (pasta Downloads). Mova-o para a pasta [`backup/`](backup/).
- **Importar CSV:** restaura o histórico ou leva as corridas para outro aparelho. As corridas que já existem não são duplicadas
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
├── PROMPT.md         prompt detalhado para evoluir o projeto com IA
└── README.md
```
