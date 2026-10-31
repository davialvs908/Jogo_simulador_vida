# Pesquisa: projetos abertos e assets livres para o jogo (carreira de futebol + cidade aberta)

Data: 2026-10-30. Método: `git clone --depth 1` anônimo dos repositórios (licença lida em LICENSE/COPYING/README locais) e leitura de nomes de arquivos/funções/headers. Nenhum código foi copiado; nada em /jogo-godot foi tocado. Os clones ficaram só no scratchpad, fora do projeto.

## 0. Limites desta pesquisa (honestidade)

- No shell, só funcionam GitHub (git clone anônimo e raw.githubusercontent.com), PyPI e npm. O `gh api` e o WebFetch de github.com não funcionam para repositórios fora da sessão. O WebFetch só funcionou para github.com/rwengine/openrw. Os outros sites foram bloqueados: "URL not on allowlist".
- Todos os sites de assets (kenney.nl, quaternius.com, polyhaven.com, dl.polyhaven.org, ambientcg.com, opengameart.org, cdn.jsdelivr.net) retornam **HTTP 403 do proxy** no `curl -I`. **Nenhum download direto deles é alcançável pelo shell desta sessão.** O WebFetch também foi bloqueado para eles.
- Por isso, as licenças de Kenney, Quaternius, Poly Haven e ambientCG abaixo vêm do meu conhecimento prévio e **não foram verificadas nesta sessão**. As exceções são as marcadas "VERIFICADO", que li em repositórios, pacotes npm ou READMEs reais.
- A busca web (WebSearch) devolveu só títulos e URLs, sem conteúdo. Por isso não consegui avaliar a fundo projetos como FutbolSim e 2d-soccer-game além de licença e estrutura de pastas.
- As URLs diretas de download do Poly Haven e do ambientCG no item 3 são padrões conhecidos de memória. Não consegui testá-las.

## 1. Projetos abertos de mundo aberto

### OpenRW (reimplementação do motor de GTA III)
- URL: https://github.com/rwengine/openrw
- Licença: **GPL-3.0**. VERIFICADO: o arquivo COPYING é a GPL v3 e a página do GitHub confirma.
- Linguagem: C++ (CMake, Bullet para física, OpenAL para áudio, SFML/GLM).
- Observação: exige os dados originais do GTA III, que são comerciais e não são redistribuíveis. Como o projeto é GPL, copiar código contaminaria o jogo. Use só como referência de ideias.
- Organização (lida nas pastas):
  - `rwcore` (formatos e utilitários), `rwengine` (mundo, IA, objetos, script, áudio, dinâmica), `rwgame` (app e UI), `rwtools` e `rwviewer`.
  - Separar motor reutilizável do app é uma boa prática. No Godot equivale a `core/` (sem Node), `world/` e `game/`.
- Ideias de design aproveitáveis:
  - **TrafficDirector** (`ai/TrafficDirector.hpp`): um "diretor" central.
    - Gera pedestres e carros apenas perto da câmera, num raio.
    - Tem densidade por tipo (ped e carro) e limite máximo de população.
    - Despawna longe do jogador.
    - Esse padrão é o mais valioso: o custo é fixo, não depende do tamanho da cidade.
  - **AIGraph / AIGraphNode**: grafo de navegação separado por tipo (Vehicle e Pedestrian).
    - Cada nó tem posição, número de faixas esquerda e direita, flag "CrossesRoad", conexões e "disabled".
    - Serve para desligar áreas e para fazer carros seguirem faixas.
  - **CharacterController / DefaultAIController / PlayerController**: o mesmo "corpo" (CharacterObject) é guiado por controladores trocáveis, humano ou IA. Vale usar o mesmo padrão no jogador e no NPC.
  - **Objetos** (`GameObject`, `Vehicle`, `Character`, `Instance`, `Pickup`, `Projectile`): hierarquia pequena e uniforme, com tipo por enum.
  - **Missões por script**: uma VM de script (SCM, `ScriptMachine`) roda as missões como threads cooperativas. Em GDScript, o equivalente é missões como máquinas de estado ou corrotinas (`await`) declarativas em Resources.
  - **GameState** guarda hora e minuto do jogo e `gameTime`. O relógio do jogo fica num estado único, e a iluminação e os NPCs leem dele.
- Não verifiquei (não li o código a fundo): detalhes do ciclo dia/noite (timecycle), da polícia e da procura de estrelas.

### Outros de referência (cidade e veículos)
- **OpenTTD**: https://github.com/OpenTTD/OpenTTD. **GPL-2.0** (README e COPYING.md verificados), C++. Útil para ideias de economia, calendário em ticks e grafos de transporte. O projeto tem partes de terceiros com outras licenças.
- **SuperTuxKart**: https://github.com/supertuxkart/stk-code. Código **GPL-3.0-or-later**. VERIFICADO no COPYING. Os dados (modelos, texturas, sons) têm mistura de licenças (CC-BY, CC-BY-SA etc.), então não copiar assets sem checar um a um.
- **Godot demo projects, `3d/truck_town`**: https://github.com/godotengine/godot-demo-projects. Código **MIT** (README e LICENSE.md verificados), GDScript.
  - Mostra `VehicleBody3D`, câmera de seguimento, céus dia/manhã/pôr do sol/noite (`sky_*.tres`) e velocímetro.
  - É compatível com o seu projeto e serve de base para um carro.
  - Atenção: os assets internos têm licenças próprias. Por exemplo, a árvore `town/tree` é **CC-BY-4.0** (exige crédito) e há `license.txt` por pasta. Os demos de `kinematic_character`, `navigation`, `ragdoll_physics` e `ik` também são úteis (não verifiquei cada asset).

## 2. Projetos abertos de futebol

### Google Research Football (gfootball)
- URL: https://github.com/google-research/football
- Licença do repositório: **Apache-2.0**. VERIFICADO no LICENSE.
- O motor em `third_party/gfootball_engine` tem LICENSE **Unlicense / domínio público**. VERIFICADO. O README diz que é uma versão muito modificada de BazkieBumpercar/GameplayFootball. A pasta `data/` (modelos, mídia) **não foi auditada**, então não presumir que os assets são livres.
- Linguagem: C++ (motor) e Python (ambiente RL, cenários, wrappers).
- Ideias aproveitáveis:
  - **Cenários (`gfootball/scenarios/*.py`)**: cada cenário é um pequeno script que define jogadores, posições, bola, dificuldade da IA e regras. Há academias de treino, como "empty_goal", "counterattack", "corner", "3_vs_1_with_keeper" e "run_pass_and_shoot". Isso é ótimo para o seu **modo treino** e para testar a IA em situações isoladas.
  - **Observação estruturada**: cada passo expõe posições, direções, dono da bola, estado de jogo (normal, kickoff, tiro de meta, escanteio, falta, pênalti etc.) e cartões. Use o mesmo vocabulário de estados de bola parada na sua máquina de estados.
  - **Conjunto de ações discreto** (`football_action_set.py`): ações como passe curto/longo/alto, chute, drible, corrida, deslizar. Mapear o controle para ações discretas desacopla o input da simulação, o que facilita replays e IA.
  - **Replay e dump**: grava a trajetória para repetir a partida. Útil para replay de gol e depuração.
  - **Determinismo**: o motor aceita semente (random seed), o que permite testes reproduzíveis.

### GameplayFootball (Bazkie) e fork vi3itor
- URLs: https://github.com/BazkieBumpercar/GameplayFootball e https://github.com/vi3itor/GameplayFootball
- Licença: **Unlicense / domínio público**. VERIFICADO no LICENSE do original e do fork.
- Linguagem: C++ (motor próprio Blunted2).
- O README do autor diz que o jogo está descontinuado, que a jogabilidade é boa e que a arquitetura é problemática. Ele recomenda usar o código como inspiração. O repositório não inclui os assets (ficam num tar externo; não verifiquei sua licença).
- Estrutura em `src/onthepitch` (lida em nomes de arquivos e funções):
  - `ball`: bola com predição de trajetória (`GetPredictionArray`), `Touch`, momentum e rotação.
  - `team` e `TeamAIController`: formação adaptada à situação, papéis dinâmicos (`CalculateDynamicRoles`), marcação (`CalculateManMarking`, qualidade de marcação), armadilha de impedimento, pressão do time, corrida ofensiva, saída do goleiro, preparação de bola parada e táticas.
  - `AIsupport/mentalimage`: **"imagem mental"** de cada jogador. A IA decide sobre uma visão com atraso e imperfeita do mundo, não sobre o estado real. Essa é a ideia mais valiosa para IA humana e justa.
  - `player/controller`, `humanoid`: separação de controlador (humano ou IA) e corpo animado.
  - `referee` e `officials`: árbitro como entidade.
  - `proceduralpitch`: gramado procedural.
- Como o código está em domínio público, o risco jurídico é baixo. Mesmo assim, o pedido foi só ideias, então não copiei nada.

### 99 Managers Futsal Edition (gerenciamento e carreira)
- URL: https://github.com/dulvui/99managers-futsal-edition. O README diz que o repositório principal **se mudou para o Codeberg** (https://codeberg.org/dulvui/99managers-futsal-edition).
- Licença: **AGPL-3.0-or-later**. VERIFICADO no LICENSE e no REUSE.toml.
  - Os assets têm licenças mistas: LICENSES/ contém CC0-1.0, CC-BY-3.0, CC-BY-SA-4.0 e OFL-1.1.
  - O README é CC0.
  - **AGPL é copyleft forte. Copiar código obriga a abrir o seu jogo inteiro.** Use só como referência de ideias.
- Linguagem: **GDScript, Godot 4.x**, ~248 arquivos .gd. É o projeto mais próximo da sua stack. Não executei o jogo, só li a estrutura.
- Arquitetura (lida nas pastas e nomes):
  - `src/resources/*`: dados do jogo como `Resource`: `calendar`, `competition` (league, cup, playoffs, table), `transfers` (buy_offer, loan_offer, contract_offer, offer_list), `team` (stadium), `person` (player com attributes: technical, mental, physical, goalkeeper; staff com roles: manager, scout, agent, medical, president), `formation`, `world` (continent, nation, free_agents), `save_states` (com checksums).
  - `Calendar` (Resource): `next_day()`, `is_market_active()`, `does_market_start_today()`, `is_season_finished()`. O calendário avança dia a dia, com **janela de transferências** calculada a partir da data.
  - `Offer`: estados PENDING, SUCCESS e DECLINED, timing IMMEDIATE ou NEXT_WINDOW, e `delay_days` para a resposta demorar dias. É um modelo simples e bom para transferências e contratos.
  - `generators/`: geração procedural do mundo (nomes, ligas, histórico, validador).
  - `match_engine/`: **simulação 2D da partida separada da apresentação**.
    - `MatchEngine` com `simulate()`, `simulate_match(fast)`, faltas, escanteios, laterais, intervalo, prorrogação e pênaltis.
    - `SimTeam` com máquina de estados de time (enter_field, start_position, kickoff, attack, defend, corner, free_kick).
    - `SimPlayer` com máquina de estados (attack, defend, chase_ball, control, dribble, receive, shoot, support).
    - Há um modo "fast" que simula sem desenhar, para os jogos da liga que o jogador não assiste.
  - Autoloads: `Const`, `Enum`, `Global`, `DataUtil`, `IdUtil`, `ThreadUtil`, `SoundUtil`.
- Ideia-chave: **dois níveis de simulação**. O jogo do usuário é 3D e jogável. Os demais jogos da liga são resolvidos por um simulador rápido, com os mesmos atributos dos jogadores.

### Dados abertos de calendário e ligas
- https://github.com/openfootball/football.json. Licença **CC0-1.0**. VERIFICADO no LICENSE.md. Contém JSON de temporadas de ligas reais, de 2010-11 em diante.
- Use só como referência de formato de calendário: rodadas, mandante e visitante, ida e volta. Não use nomes de clubes reais, pois você quer conteúdo original e há risco de marca.
- Calendário de pontos corridos: o algoritmo clássico de rodízio (método do círculo/Berger) gera ida e volta sem precisar de dados externos.

### Outros achados (não aprofundados)
- https://github.com/Dubium0/FutbolSim: futebol arcade em Unity (alunos), multiplayer P2P via Steamworks. Licença **GPL-3.0**. VERIFICADO no arquivo LICENSE. Não avaliei a qualidade do código.
- https://github.com/matinaghaei/2d-soccer-game: Unity 2D. Tem LICENSE, mas **não li o tipo**. Baixo valor para o seu caso.
- https://github.com/dulvui/ball2box: arremesso casual em Godot 3, **AGPL-3.0**. VERIFICADO. Pouca relevância.
- Artigo da Creative Bloq sobre "como fazer seu próprio jogo de futebol no Godot" apareceu na busca, mas não consegui abrir. Não avaliei.
- Não achei, nas buscas feitas, nenhum jogo de mundo aberto estilo GTA em Godot 4 com licença permissiva e qualidade utilizável. Aparecem OpenLiberty (FOSS-Supremacy) e demos pequenos, que **não verifiquei**.

## 3. Fontes de assets gratuitos (licença livre)

Legenda de acesso pelo shell desta sessão: **403** = bloqueado pelo proxy, **OK** = baixei ou testei. Todas as licenças marcadas "memória" não foram verificadas aqui. Confirme a licença na página de cada asset antes de usar.

### Acessíveis pelo shell (VERIFICADO)
| Fonte | O que traz | Licença | Como baixar |
|---|---|---|---|
| Kenney Starter Kit City Builder | 31 itens, incluindo prédios pequenos, ruas (reta, curva, cruzamento, split, postes), calçada, árvores e garagem, em .glb. README: "Assets... are CC0". Código MIT. | CC0 (assets), MIT (código) | `git clone --depth 1 https://github.com/KenneyNL/Starter-Kit-City-Builder` (OK, ~4 MB) |
| Kenney Starter Kit Racing | Caminhões/veículos (.glb), motocicleta, peças de pista, sons. | CC0 + MIT | `git clone --depth 1 https://github.com/KenneyNL/Starter-Kit-Racing` (OK, ~4,7 MB) |
| Kenney Starter Kit 3D Platformer | Personagem e props 3D. Só olhei a licença (MIT) e o README. | CC0 + MIT | `git clone --depth 1 https://github.com/KenneyNL/Starter-Kit-3D-Platformer` (OK) |
| Godot demo `truck_town` | Cidade pequena, veículos, céus, sons. | Código MIT. Assets variados (CC-BY-4.0 na árvore), cada pasta com `license.txt` | `git clone` do godot-demo-projects (OK) |
| npm `@pmndrs/assets` 1.7.0 | Pequena seleção de HDRIs do Poly Haven em 512x512 (EXR, ~100-200 kb cada) e normal maps, codificados em base64 em módulos JS. Qualidade baixa para skybox principal. | **CC0-1.0** (campo `license` do npm; README cita Polyhaven) | `npm pack @pmndrs/assets@1.7.0` (OK; tarball HTTP 200) |
| Repositório KhronosGroup/glTF-Sample-Assets | Modelos de teste glTF. A API do GitHub bloqueou; o clone raso funcionou. **Licenças variam por modelo** (pasta LICENSES). Baixo valor para este jogo. | Mista | `git clone` (OK) |

Observação: o repositório `KenneyNL/Assets` não existe ou não é público (clone pediu senha). Não existe um espelho oficial completo de Kenney no GitHub que eu tenha achado. No npm há espelhos **não oficiais** de pacotes Kenney (ex.: `@anabis/kenney-space-kit-mirror`). Não confio neles; prefira o site oficial.

### Não acessíveis pelo shell (403), mas válidos para você baixar manualmente
| Fonte | Conteúdo útil | Licença (memória, NÃO verificada) | URL |
|---|---|---|---|
| Kenney | City Kit (Commercial, Suburban, Roads), Car Kit, Blocky Characters, Animated Characters, Furniture, Sports... | CC0 | https://kenney.nl/assets (ex.: https://kenney.nl/assets/car-kit, https://kenney.nl/assets/city-kit-commercial) |
| Quaternius | "Ultimate Modular Women/Men", Cars, Modular Streets, Buildings, personagens animados | CC0 (maioria dos packs gratuitos) | https://quaternius.com |
| Poly Haven | HDRIs, texturas PBR, modelos 3D (CC0). Possui API pública e URLs de CDN do tipo `dl.polyhaven.org/file/ph-assets/HDRIs/hdr/<res>/<nome>_<res>.hdr` (padrão de memória, não testado). | CC0 | https://polyhaven.com |
| ambientCG | Texturas PBR (asfalto, concreto, grama, tijolo etc.) com download por `https://ambientcg.com/get?file=<ID>_1K-JPG.zip` (padrão de memória, não testado) | CC0 | https://ambientcg.com |
| OpenGameArt | Mistura de CC0, CC-BY, CC-BY-SA e GPL. Filtrar por licença sempre | Mista | https://opengameart.org |
| Mixamo (Adobe) | Animações e personagens humanoides | **Não é CC0**: uso livre com conta Adobe, termos próprios. Não confirmei a política atual | https://www.mixamo.com |

Dica prática: como os sites são bloqueados aqui, peça para o usuário baixar os packs no próprio computador e colocar em `assets/third_party/<fonte>/`, com um arquivo `LICENSE.txt` por pasta e um `ASSETS.md` listando origem, data e licença. Prefira CC0 e evite CC-BY-SA e GPL em assets, porque obrigam a compartilhar derivados.

## 4. Mapa de ideias por tema

| Tema | Melhor referência | Ideia a aproveitar |
|---|---|---|
| IA de jogadores | GameplayFootball (domínio público) | Imagem mental com atraso e erro de percepção; papéis dinâmicos; pressão, marcação e armadilha de impedimento no nível do time |
| Física da bola | gfootball / GameplayFootball | Predição da trajetória da bola para a IA interceptar; tratar "toque" como evento com momentum; spin como rotação aplicada |
| Estados de bola parada | gfootball | Vocabulário: kickoff, tiro de meta, lateral, escanteio, falta, pênalti |
| Treino e testes de IA | gfootball | Cenários de academia pequenos e determinísticos, com semente |
| Calendário de temporada | 99Managers | `Calendar` com `next_day()`, janela de transferências e fim de temporada |
| Contratos e transferências | 99Managers | `Offer` com estados e timing (imediato ou próxima janela); resposta com atraso em dias |
| Simulação rápida da liga | 99Managers | Simulador separado e rápido para jogos que o jogador não assiste |
| Mundo procedural | 99Managers | Geradores de ligas, clubes, nomes e histórico, com validador |
| Tráfego e pedestres | OpenRW | `TrafficDirector`: spawn perto da câmera, densidade e limite; grafos separados para carro e pedestre |
| Missões | OpenRW | Missões como scripts cooperativos; em GDScript, `await` ou máquinas de estado em Resource |
| Ciclo dia/noite | OpenRW (hora no GameState), Godot truck_town (céus) | Relógio único do jogo; ambiente e NPCs leem a hora |
| Organização de código | OpenRW, 99Managers | Núcleo sem dependência de cena, mais camada de jogo; dados como Resource; autoloads pequenos |

## 5. Recomendações priorizadas (10 itens)

1. **Não copiar código de OpenRW (GPL-3), 99Managers (AGPL-3) nem FutbolSim (GPL-3).** Usar só ideias. Código de domínio público (GameplayFootball e o motor do gfootball) tem risco menor, mas mesmo assim reescreva do zero para manter o jogo 100% original. Registre isso num `LICENSES.md`.
2. **Adotar o padrão TrafficDirector**: um nó único que gera e remove carros e pedestres num raio em volta do jogador, com densidade e limite de população. É a decisão que mais protege o desempenho da cidade aberta.
3. **Separar simulação rápida da partida jogável.** Mesmos atributos de jogador para os dois. Os jogos da liga que o usuário não joga rodam no simulador rápido, como no 99Managers. É a base da carreira.
4. **Dar "imagem mental" à IA dos jogadores** (percepção com atraso e ruído, em vez de ler o estado real). Combine com papéis dinâmicos e pressão no nível do time, como no GameplayFootball. É o que faz a IA parecer humana.
5. **Modelar a máquina de estados do jogador e do time** com estados explícitos (chase_ball, control, receive, dribble, shoot, support, attack, defend) e estados de bola parada. Mantenha cada estado em um arquivo, como no 99Managers.
6. **Criar cenários de treino pequenos e determinísticos** (gol vazio, 3x1 com goleiro, escanteio, contra-ataque), com semente fixa. Servem como modo treino e como testes automáticos da IA e da física da bola.
7. **Fazer calendário e mercado como Resources**: `Calendar` com `next_day()`, janela de transferências, fim de temporada, e `Offer` com estados PENDING, SUCCESS e DECLINED, timing e atraso em dias. Gere o rodízio de rodadas por algoritmo próprio, sem usar clubes reais.
8. **Usar grafos de navegação separados** para carros (faixas por mão, nós de cruzamento) e pedestres (travessias, calçadas), com nós desativáveis. No Godot, combine com `NavigationRegion3D` para pedestres.
9. **Relógio único do jogo** (hora e minuto no estado global) que controla céu, iluminação, abertura de lojas e rotina dos NPCs. Use os `sky_*.tres` de `truck_town` (MIT) só como ponto de partida; faça o seu próprio.
10. **Assets: começar com Kenney (CC0)**, que você pode obter agora pelos Starter Kits no GitHub (City Builder para prédios e ruas; Racing para veículos). Depois peça ao usuário para baixar manualmente Quaternius (pessoas e carros), Poly Haven (HDRIs e texturas) e ambientCG (PBR de asfalto e paredes), já que o shell não alcança esses sites. Guarde licença e origem de cada pacote em `ASSETS.md`. Evite CC-BY-SA e GPL em assets e confira cada arquivo com CC-BY (ex.: a árvore do truck_town exige crédito).
