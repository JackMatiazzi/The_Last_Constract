# The Last Contract

Jogo de ação 3D em terceira pessoa feito em Godot 4.7 para a Avaliação Grau 2 de Programação de Jogos.

Uma vila medieval foi tomada por mortos-vivos. Um Lorde contrata um aventureiro para limpá-la e
derrotar o Necromante responsável pela infestação. Cada tentativa tem uma vida só: ao morrer,
reviva com uma bênção (que os mortos-vivos também recebem) ou desista e enfrente a execução.

**Autores:** André Bartzen Araujo, Jackson Matiazzi e José Maciel Camargo.

## Entregas

| Data | Tema | O que entrou |
|---|---|---|
| 08/10 | Protótipo | Knight anda, corre, pula, empurra caixotes e barris e ataca um esqueleto de treino num mapa de teste |
| 15/10 | Primeiro nível (som 3D) | Vila medieval à noite, com sons posicionados nos personagens e trilha ambiente |
| 22/10 | Personagem jogável (máquinas de estados) | Aventureiro controlado por máquina de estados, estamina e mana, golpe rápido e pesado, inventário rápido, portal do Mage e co-op online para até 4 |

### Primeiro nível

A vila é montada com GridMap (chão, construções e objetos) e iluminada por tochas e pela lua. O Knight
começa na entrada sul, e três esqueletos de treino estão espalhados pelo caminho.

Os sons de jogo são `AudioStreamPlayer3D` presos ao personagem que os produz, então volume e
lado mudam conforme a distância e a posição em relação à câmera:

- passos, um a cada 1,7 m andados no chão, acompanhando o ritmo de andar ou correr;
- golpe da espada no momento do impacto;
- dano e morte (no esqueleto, ossos caindo).

Cada som usa um `AudioStreamRandomizer` com variação de tom e de arquivo, para não repetir igual.
A trilha ambiente toca no bus Music e os efeitos no bus SFX.

### Personagem jogável

O aventureiro é controlado por uma máquina de estados: cada estado (`Idle`, `Walk`, `Run`, `Air`,
`Action`, `Block`, `Dead`) é um nó filho de `StateMachine` e decide a animação e para onde passar.
Correr, o escudo e os golpes gastam estamina; o Mage paga os feitiços com mana. Clicar é o golpe
rápido; segurar é o pesado, que também quebra barris e caixotes. Em grupo, até quatro jogadores
entram pelo lobby (um hospeda pela porta 7777) e cada um controla o próprio aventureiro.

## Como jogar

| Ação | Teclado e mouse | Controle (layout Xbox) |
|---|---|---|
| Mover | W A S D | Analógico esquerdo |
| Correr | Segurar Espaço | Clicar no analógico esquerdo |
| Câmera | Mouse | Analógico direito |
| Atacar | Botão esquerdo | RT |
| Habilidade (escudo do Knight, segundo machado do Barbarian) | Botão direito | LT |
| Trocar habilidade (Mage: projétil ou portal) | Roda do mouse para cima | Direcional para cima |
| Trocar item | Roda do mouse para baixo | Direcional para baixo |
| Interagir (abrir baú, reviver aliado) | E | X |
| Beber o item selecionado | Segurar E | Segurar X |
| Placar (em grupo) | Segurar Tab | Segurar Back |
| Pausar | Esc | Menu (Start) |

**Objetivo:** limpe os grupos de esqueletos espalhados pela vila (a HUD mostra quantos faltam).
Quando o último cair, o Necromante surge na praça. Derrote-o para cumprir o contrato.

## Como rodar

1. Abra o projeto no Godot 4.7 (Forward+).
2. Rode a cena principal (F5): menu → seleção de aventureiro → entrada na missão → vila.
3. Em grupo: menu → Co-op. Quem hospeda clica no próprio endereço para copiar e manda aos outros,
   que entram por ele. Na rede da faculdade, usem o Radmin VPN; quem hospeda libera o jogo no
   firewall marcando também a rede Pública.

O mapa do protótipo continua em `scenes/levels/prototype.tscn`.

## Testes e builds

Usamos o gdUnit4 (em `addons/`). Os testes ficam em `tests/` e rodam pela aba gdUnit do editor.

No GitHub Actions, a cada push e pull request:

- **Testes** (`test`): roda toda a suíte do gdUnit4.
- **Smoke** (`smoke`): abre a cena principal sem tela por 300 quadros e falha se aparecer qualquer erro no log.
- **Ponta a ponta** (`e2e`): joga um contrato solo do menu até a segunda tentativa e uma partida em grupo
  com dois processos ligados pela rede local (`tests/e2e/run_e2e.sh`).
- **Documento**: compila `docs/projeto.tex` quando algo em `docs/` muda.

Antes de uma entrega, o pull request para o `main` também roda o **Build**, que exporta o jogo para Linux e Windows.
O Dependabot abre um pull request por semana na `desenvolvimento` quando alguma action do CI tem versão nova.

### Release de cada entrega

Todo merge no `main` que não mexa só no CI ou no README gera a release sozinho: o workflow **Release da entrega** cria a tag
`entrega-AAAA-MM-DD` (data de Brasília), exporta o jogo para Linux e Windows, compila o documento e publica
tudo na página de Releases. Um segundo merge no mesmo dia move a tag e atualiza a mesma release.

## Como trabalhamos

- Cada tarefa sai numa branch própria a partir da `desenvolvimento` e volta por pull request.
- Na `desenvolvimento`, o pull request precisa dos testes verdes e da aprovação dos outros dois integrantes.
  O Jackson pode fazer o merge dos próprios pull requests sem aprovação.
- A entrega da semana é um pull request da `desenvolvimento` para o `main`, e só o Jackson faz o merge.
- Ninguém faz push direto, force-push ou apaga `main`, `desenvolvimento` e `referencia`.
- `referencia` guarda o jogo completo de onde as partes de cada entrega são trazidas. Só o Jackson atualiza.
- Tags `entrega-*` são criadas pela release; ninguém cria nem apaga à mão.
- Todos usam o Godot 4.7.2. Outra versão regrava as cenas e gera diferenças falsas.
- Antes de mexer numa cena usada por todos (mapa, personagem base, `project.godot`), avisar no grupo.
- Subir junto os arquivos `.uid` e `.import` que o Godot cria.
- Mensagens de commit no formato `tipo: descrição` (`feat`, `fix`, `refactor`, `test`, `docs`, `ci`, `chore`).

## Estrutura

| Pasta | Conteúdo |
|---|---|
| `scenes/` | Cenas (`.tscn`): personagens, mapas em GridMap, cutscenes, interface, objetos |
| `scripts/` | Scripts (`.gd`), espelhando `scenes/` |
| `resources/` | Recursos: aventureiros, bênçãos, perfis de inimigo, sons, bibliotecas de peças, navmesh |
| `assets/` | Modelos 3D e áudio de terceiros (CC0) |
| `tests/` | Testes gdUnit4 |
| `docs/` | Documento do projeto (`docs/projeto.tex`) e GDD (`docs/gdd.tex`), em LaTeX |

## Créditos dos recursos (todos CC0)

- Modelos: [KayKit Adventurers](https://kaylousberg.itch.io/kaykit-adventurers), [KayKit Skeletons](https://kaylousberg.itch.io/kaykit-skeletons) e [KayKit Dungeon Pack](https://kaylousberg.itch.io/kaykit-dungeon-pack) (Kay Lousberg); [Medieval Village MegaKit](https://quaternius.itch.io/medieval-village-megakit) (Quaternius).
- Efeitos sonoros: [RPG Audio](https://kenney.nl/assets/rpg-audio), [Impact Sounds](https://kenney.nl/assets/impact-sounds) e [Interface Sounds](https://kenney.nl/assets/interface-sounds) (Kenney).
- Música: [Dark Cavern Ambient](https://opengameart.org/content/dark-cavern-ambient) (Paul Wortmann) e [Medieval fair [Loop]](https://opengameart.org/content/medieval-fair-loop) (Woli34).
