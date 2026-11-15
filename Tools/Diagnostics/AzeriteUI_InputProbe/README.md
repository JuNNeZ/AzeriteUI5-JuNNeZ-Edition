# Diagnóstico de alternância MnK/Gamepad no Forever

Este addon independente executa a primeira etapa do plano de alternância automática:
medir as restrições reais de `InputDeviceInterfaceStyle` e correlacionar os eventos
de entrada com o estilo aplicado. Ele não é carregado pelo AzeriteUI e não faz parte
dos pacotes de produção. Os resultados já orientaram o fluxo de confirmação em jogo,
descrito no [guia das barras de ação](../../../wiki/Action-Bars.md).

## Instalação

1. Copie esta pasta inteira, com o nome `AzeriteUI_InputProbe`, para
   `_forever_/Interface/AddOns/`. Se usar o ZIP, extraia sua pasta nesse destino.
2. Ative **AzeriteUI Input Probe (diagnostic)** na lista de addons e entre no jogo ou use `/reload`.
3. O painel do diagnóstico aparece ao carregar. Use **Start** para iniciar a coleta.
   **Stop** encerra a coleta e cancela um teste de timer ainda pendente.

O addon funciona independentemente do AzeriteUI. Para testar junto da integração atual,
entre no modo de controle aceitando o aviso Sim/Não exibido ao caminhar com o joystick.
Não há configuração manual de barras nativas no menu do AzeriteUI.

## Operação

O painel registra o estilo nativo, a CVar, dispositivos enumerados, estados de
atividade, sinais agregados de botões/analógicos, modificadores e eventos de mouse.
Esses sinais são contexto de diagnóstico: não identificam necessariamente a origem
física de uma entrada emulada. `unknown` significa que uma leitura não pôde ser
determinada; não significa ausência de controle.
O cabeçalho da sessão também informa quais eventos puderam ser registrados, para
distinguir um evento ausente no cliente de um evento que apenas não ocorreu.

**Start**, **Stop**, seleção de destino e coleta de eventos não alteram o estilo.
Somente os botões de teste abaixo podem escrever a CVar:

- **Test click**: uma tentativa diretamente no callback do clique.
- **Test timer**: agenda uma única tentativa aproximadamente um segundo depois,
  fora do callback original de entrada. Esse é o experimento para verificar o
  comportamento sem contexto de hardware.

Use **Select MnK** ou **Select Gamepad** para escolher o destino antes de testar. Se o destino já for o
estilo atual, a operação é um no-op e **não valida** a permissão de troca. Cada teste
pode provocar reload pelo próprio cliente. Faça esses testes fora de combate.
O probe recusa escritas em combate, inclusive se o combate começar enquanto o timer
estiver aguardando. Ele não tenta novamente nem reverte o estilo automaticamente.

Use **Prepare report**, clique no texto e pressione **Ctrl+A**, depois **Ctrl+C**,
para copiar o relatório. A coleta tem limite de registros; exporte
depois de cada cenário curto. A SavedVariable `AzeriteUI_InputProbeDB` guarda o
histórico e a intenção da escrita antes de chamar a API. `/reload` ou logout salva
normalmente os dados em disco; encerramento forçado/crash pode perder a sessão atual.
O contador de sessões ajuda a identificar reloads causados pela mudança de estilo.

## Roteiro manual

Os testes no WoW são executados pelo usuário. Os testes Lua locais não comprovam
permissões C-side, renderização, origem física de input ou ausência de taint.

### 1. Observação, sem escrita do probe

Comece com **Start**. Execute um cenário por vez e copie o relatório em seguida:

| Cenário | O que comparar |
| --- | --- |
| Login com zero, um e dois controles | Estilo inicial, inventário e ausência de solicitação de troca. |
| Conectar sem tocar no controle | Eventos de presença versus eventos de atividade. |
| Botão, gatilho e sticks de movimento/câmera | `GAME_PAD_ACTIVE_CHANGED`, sinais agregados e estilo nativo. |
| Controle parado com drift | Atividade espúria e variação analógica em repouso. |
| Stick mantido enquanto usa teclado | Ordem dos eventos e prioridade indicada pelo cliente. |
| Teclado, tecla de movimento e chat | Se o cliente informa retorno a MnK; texto digitado não integra o relatório. |
| Mouse físico: movimento, clique e roda | Diferença entre atividade e mudança efetiva de estilo. |
| Cursor, clique e modificadores emulados pelo controle | Se esses sinais se confundem com MnK físico. |
| Desconectar um de dois controles | Inventário restante; não interpretar como perda de todos os dispositivos. |
| Desconectar todos; reconectar USB/Bluetooth | Eventos, IDs novos, leituras desconhecidas e tempo de estabilização. |
| Repetir entradas durante combate | Observação funciona e não há pedido de escrita do probe. |

Altere o estilo pelo ajuste oficial da Blizzard e registre se houve reload. Isso
separa o comportamento nativo dos testes de escrita do addon. Verifique também se
a transição altera o layout do Edit Mode.

### 2. Contexto de escrita, fora de combate

1. Leia o estilo atual e selecione o destino oposto.
2. Clique **Test click** uma vez. Observe se o estilo mudou, se houve reload e se
   apareceram eventos `ADDON_ACTION_BLOCKED` ou `ADDON_ACTION_FORBIDDEN`.
3. Clique **Prepare report** após o resultado. Se houve reload, a sessão seguinte deve conter
   a reconciliação da solicitação anterior, sem nova tentativa automática.
4. Após o reload, clique **Start** e selecione novamente o destino oposto: o destino
   não é preservado entre sessões. Se o estilo atual for Gamepad, clique **Select MnK**
   e depois **Test timer** uma vez. Aguarde o resultado e exporte o relatório.
   `TEST_SKIPPED` com `reason=target` significa que não houve tentativa de escrita;
   é preciso selecionar o destino. Um bloqueio da API é um resultado válido do experimento.
5. Compare os dois contextos nas duas direções. Não conclua que timer é permitido
   apenas porque escrever o valor já aplicado não causou erro.

Uma confirmação do getter mostra que o estilo foi observado; sozinha, não prova
que a escrita veio do probe. Para isolar causalidade, faça a primeira rodada com
outros controladores de estilo inativos. Depois repita com GamePadReadySet presente
para observar coexistência; o probe registra sua presença, mas não muda o outro addon.

O recibo da última tentativa fica salvo mesmo após confirmação síncrona. Sua
reconciliação no próximo carregamento informa o estilo encontrado naquela sessão;
não prova, por si só, que a tentativa causou o reload. Registre também se o reload
foi espontâneo ou iniciado por você. Uma nova tentativa substitui esse recibo, mas
os eventos anteriores permanecem no histórico limitado.

### 3. Integração e encerramento

Com a compatibilidade nativa do AzeriteUI ativa, confira barras MnK/Gamepad, pet,
stance, veículo, ações extras e o binding próprio do item de missão. A troca de
estilo não deve devolver as barras ao AzeriteUI nem criar duplicatas.

Depois dos testes, use **Stop** e desative apenas **AzeriteUI Input Probe** na lista
de addons. O diagnóstico não restaura o estilo anterior: selecione a preferência
desejada pelos ajustes nativos. Preserve o relatório antes de remover seus dados.

## Como reportar

Envie o relatório copiado e estas observações para cada cenário relevante:

```text
Cenário e sequência de ações:
Controle/conexão: USB ou Bluetooth; um ou vários dispositivos
Estilo inicial -> destino:
Contexto: observação / ajuste nativo / Test click / Test timer
Houve reload? O contador de sessões aumentou?
Houve erro/bloqueio? Qual mensagem?
Comportamento de teclado, mouse e emulação:
GamePadReadySet estava ativo?
As barras e os bindings continuaram funcionando?
```

Não é necessário enviar a pasta WTF inteira. O relatório do probe e a mensagem
específica de erro são suficientes para avaliar esta etapa.

## Decisão para a implementação de produção

| Evidência no cliente | Próxima etapa |
| --- | --- |
| Troca sem reload e escrita por timer permitida | Implementar controlador automático, condicionado à validação dos sinais de uso. |
| Troca sem reload, mas somente entrada física permite escrever | Projetar aplicação no contexto permitido; timers apenas estabilizam a intenção. |
| Troca provoca reload | Tratar como mudança assistida de modo; não aplicar a cada entrada. |
| Modalidade ou origem de input permanece ambígua | Manter observação e resolver o detector antes de habilitar escrita automática. |

A liberação em combate é uma questão separada. Este diagnóstico não tenta escrever
em combate e não certifica que tal operação seja permitida ou apropriada.

## Resultado manual recebido em 15/11/2026

Build 70938, versão 1.60.1, TOC 16001. O usuário confirmou **um controle físico**
conectado e **reload espontâneo** depois de **Test click**, na direção MnK → Gamepad.
O GamePadReadySet não estava carregado. A sequência registrada foi:

1. Em `421977.692`, a escrita solicitou Gamepad (`1`). O setter retornou `true` e
   `CVAR_UPDATE` já mostrou `cvar=1`, mas o getter ainda retornava `style=0`.
2. O probe corretamente registrou `unconfirmed`, sem repetir a escrita. Não houve
   `INPUT_DEVICE_INTERFACE_TRANSITION` no trecho coletado, embora seu registro
   tivesse sido aceito.
3. A sessão seguinte começou em `421979.069`, com `style=1`, `cvar=1` e
   `recovered-match`: aproximadamente 1,38 segundo depois.
4. A tentativa posterior de timer foi ignorada com `reason=target`. Portanto, esse
   relatório **não testa** a permissão da escrita fora de um callback de hardware.

Outras observações do mesmo relatório:

- Um controle físico apareceu como dois IDs (`1` e `5`), com amostras mapeadas iguais.
  O ID `5` tinha estado raw desconhecido. A contagem de IDs não é contagem física;
  não se deve descartar ou escolher um ID apenas por essas leituras.
- `activeDeviceID=5` permaneceu durante amostras com enumeração vazia. Esse getter
  não substitui a enumeração como evidência de disponibilidade.
- `usingGamepad` e `usingMouse` ficaram verdadeiros simultaneamente. Eles não
  definem modalidades mutuamente exclusivas.
- Houve atividade Gamepad com estilo MnK e, após reload, estilo Gamepad com
  `usingGamepad=false`. Atividade e estilo precisam continuar separados.
- `maxStick` chegou a `1.14`. Isso não comprova drift nem erro de escala, pois não
  houve descrição de repouso; o diagnóstico preserva o valor sem limitar a `1`.

A conclusão dessa primeira rodada é o reload espontâneo na troca por clique.
A direção inversa e a caracterização de teclado/mouse físico versus emulado não
foram certificadas por esse trecho.

### Timer executado na sessão 3

Uma tentativa posterior válida foi solicitada em `422370.632` e executada em
`422371.632`, fora de combate, com MnK atual e Gamepad como destino:

- `ADDON_ACTION_BLOCKED` identificou `AzeriteUI_InputProbe`, com ação `UNKNOWN()`.
- Mesmo assim, a CVar passou de `0` para `1` e o setter retornou `true`.
- O estilo efetivo continuou `0` durante mais de cinco segundos de observação.
  Não houve nova sessão nesse intervalo. O resultado permaneceu `unconfirmed`.

Isso comprova uma ação bloqueada durante a tentativa por timer e uma preferência
alterada sem a troca efetiva. Não identifica qual operação interna foi bloqueada,
nem autoriza afirmar que toda escrita da CVar foi recusada. A preferência pendente
pode ser aplicada em um reload posterior; observe o destino antes de recarregar.

O caminho de implementação escolhido é sugerir mudanças automaticamente e exigir
uma ação explícita para aplicá-las, fora de combate. Eventos e timers não devem
escrever a CVar nem forçar reload. O estado aplicado continua vindo do getter
nativo; divergência entre CVar e getter deve aparecer como reload pendente.

## Evidências de API

Referência investigada: Forever 1.60.1.70938, snapshot
`bebcb6bf309cf41b41bd74f8ca651e6a105b2676` de Gethe/wow-ui-source:

- [GamePadDocumentation](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_APIDocumentationGenerated/GamePadDocumentation.lua): dispositivos, estados mapeados e eventos.
- [InputDocumentation](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_APIDocumentationGenerated/InputDocumentation.lua): atividade e transição síncrona de estilo.
- [CVarDocumentation](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_APIDocumentationGenerated/CVarDocumentation.lua): leitura e escrita de CVars; não comprova as restrições específicas da CVar de estilo.

O probe é uma implementação própria; nenhum código do GamePadReadySet foi copiado.

## Verificação offline

Na raiz do repositório, com Lua 5.1:

```sh
lua Tools/Harness/input_style_probe_harness.lua .
lua Tools/Harness/gamepadui_compat_harness.lua .
```

O primeiro executa o probe real contra APIs simuladas; o segundo protege a
responsabilidade das barras e a observação já existentes no AzeriteUI.
