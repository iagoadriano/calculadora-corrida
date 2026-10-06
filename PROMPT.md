# Prompt para evoluir o projeto

Copie o texto abaixo e cole em um assistente de IA com acesso ao repositório (Claude Code, por exemplo).
Ele descreve o sistema completo. A versão atual (`index.html`) já cobre a Fase 1.

---

Você vai evoluir o projeto **Calculadora de Corrida**, um sistema para motoristas de aplicativo em Araguaína (TO)
controlarem quanto realmente ganham por corrida. O código atual está em `index.html` (HTML, CSS e JS puros, sem build).
Leia esse arquivo e o `README.md` antes de mudar qualquer coisa.

## Contexto do usuário

- Motorista que roda na Maxim (taxa de 17%, categorias Econômica e Conforto), faz corridas avulsas (sem taxa) e pode usar
  Uber, 99 e inDrive.
- Carro: Hyundai Creta 2.0, média de 7,5 km/l. O preço do litro muda (hoje está em R$ 6,61).
- Usa principalmente o iPhone (Safari). Tudo precisa funcionar bem em uma tela de 375 a 430 px, com uma mão.
- Idioma: português do Brasil. Moeda: R$ com vírgula decimal. Datas: dd/mm/aaaa. Semana de segunda a domingo.

## Regras de cálculo (não mudar sem pedir)

```
taxa_app    = valor × taxa_pct / 100
combustivel = km_total ÷ consumo_km_l × preco_litro      (km_total = km até o passageiro + km da corrida)
liquido     = valor − taxa_app − combustivel − outras_taxas
R$/km       = liquido ÷ km_total
R$/hora     = soma(liquido) ÷ soma(minutos) × 60          (só corridas com minutos > 0)
```

- Corrida "Avulsa" tem taxa 0%. A "Maxim" usa a taxa configurada (padrão 17%).
- Cada corrida grava o preço do litro e o consumo do momento do registro. Os relatórios nunca recalculam com o preço atual.
- Valores monetários são arredondados para 2 casas só na gravação e na exibição.

## Formato do CSV (compatibilidade obrigatória)

Separador `;`, vírgula decimal, UTF-8 com BOM, cabeçalho nesta ordem:
`id;data;hora;origem;valor;taxa_pct;taxa_app;outras_taxas;outras_desc;km;minutos;preco_litro;consumo_km_l;combustivel;liquido;timestamp`

A importação precisa aceitar arquivos antigos e mesclar pelo `id`, sem duplicar.

## Fase 1: já existe no index.html

Calculadora em tempo real, registro de corridas no localStorage, relatórios de dia, semana e mês (totais, divisão por dia e
por origem, barra de composição), copiar resumo, exportar e importar CSV, apagar corrida com confirmação dentro da página,
tema claro e escuro.

## Fase 2: melhorias no app (sem servidor)

1. **Editar corrida** já registrada (hoje só dá para apagar).
2. **Registro rápido:** campo para colar o texto ou ler a tela "Pedido concluído" da Maxim. No mínimo, um modo com só três
   campos (valor, km e origem).
3. **Abastecimentos:** registrar litros, valor pago e hodômetro. Calcular o consumo real (km/l) entre dois tanques cheios e
   sugerir a atualização do consumo configurado.
4. **Custos fixos do mês:** parcela do carro, seguro, IPVA ÷ 12, manutenção por km. O relatório mensal mostra o lucro real
   depois desses custos.
5. **Metas:** meta diária e mensal de líquido, com uma barra de progresso no relatório do dia.
6. **Gráficos:** líquido por dia no mês (barras), R$/km por origem e os melhores horários (líquido médio por faixa de hora).
   SVG puro, sem bibliotecas.
7. **PWA:** `manifest.json`, ícones e `service-worker.js` para abrir offline e instalar na tela inicial.
8. **Lembrete de backup:** se o último export foi há mais de 7 dias, mostrar um aviso discreto.

## Fase 3: sistema completo (opcional, com servidor)

- Backend com Supabase (Postgres + autenticação por e-mail), com a tabela `corridas` espelhando as colunas do CSV mais `user_id`.
  Ative RLS para cada usuário ver só as próprias corridas.
- Sincronização offline-first: continua gravando no localStorage e envia quando houver conexão.
- Painel web com filtros por período e origem, e exportação em CSV e XLSX.
- Multiusuário, para que vários motoristas usem o mesmo link, cada um com a sua conta.

## Requisitos técnicos

- Manter tudo funcionando abrindo o `index.html` direto do arquivo, sem build. Se a Fase 3 precisar de build, use Vite e
  mantenha uma versão estática.
- Sem frameworks pesados. Se precisar, carregue só o necessário por CDN com versão fixada.
- Acessibilidade: rótulos em todos os campos, foco visível e contraste AA nos dois temas.
- Nunca usar `alert`, `confirm` ou `prompt`. Confirmações ficam dentro da página.
- Testes: crie `tests/calculo.test.js` (Node, sem dependências) cobrindo a fórmula, o arredondamento, a semana de segunda a
  domingo e a ida e volta do CSV (exportar → importar → mesmos dados).
- Commits pequenos e em português, um por funcionalidade. Atualize o `README.md` a cada fase.

## Entrega de cada etapa

Para cada funcionalidade: explique em 2 ou 3 linhas o que mudou, rode os testes e confirme que um CSV exportado pela versão
anterior continua importando sem erro.
