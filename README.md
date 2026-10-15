# The Last Contract

Jogo 3D em terceira pessoa feito em Godot 4.7 para a disciplina de Programação de Jogos.

Grupo: André Bartzen Araujo, Jackson Matiazzi e José Maciel Camargo.

## Entregas

| Data | Tema | O que entrou |
|---|---|---|
| 08/10 | Protótipo | Knight anda, corre, pula, empurra caixotes e barris e ataca um esqueleto de treino num mapa de teste |
| 15/10 | Primeiro nível (som 3D) | Vila medieval à noite, com sons posicionados nos personagens e trilha ambiente |

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

## Controles

- WASD: mover
- W duas vezes: correr
- Espaço: pular
- Mouse: câmera
- Botão esquerdo: atacar
- Esc: soltar o mouse

Para rodar, abrir a pasta no Godot 4.7.2 e apertar F5. O mapa do protótipo continua em
`scenes/levels/prototype.tscn`.

## Testes e builds

Usamos o gdUnit4 (em `addons/`). Os testes ficam em `tests/` e rodam pela aba gdUnit do editor ou
automaticamente no GitHub Actions a cada push e pull request.

Também pelo GitHub Actions:

- **Build Linux**: exporta o jogo a cada push no `main` ou manualmente.
- **Build Windows**: manual, pela aba Actions.
- **Documento**: compila `docs/projeto.tex` quando algo em `docs/` muda.

Os arquivos gerados ficam nos artefatos de cada execução.

Cada entrega vira uma release: ao criar a tag `entrega-AAAA-MM-DD` no `main`, o workflow **Release da entrega**
publica o build de Linux e o PDF do documento na página de Releases.

## Como trabalhamos

- `main` recebe só as entregas: um merge de `desenvolvimento` por semana, com uma tag `entrega-AAAA-MM-DD`.
- `desenvolvimento` é onde o jogo cresce. Cada tarefa sai numa branch própria a partir dela e volta por pull request.
- Nada vai direto para `main` ou `desenvolvimento`: sempre por pull request com os testes passando.
- Todos usam o Godot 4.7.2. Outra versão regrava as cenas e gera diferenças falsas.
- Antes de mexer numa cena usada por todos (mapa, personagem base, `project.godot`), avisar no grupo.
- Subir junto os arquivos `.uid` e `.import` que o Godot cria.
- Mensagens de commit no formato `tipo: descrição` (`feat`, `fix`, `refactor`, `test`, `docs`, `ci`, `chore`).

## Créditos

Todos os recursos de terceiros são CC0.

- Modelos: KayKit Adventurers, KayKit Skeletons e KayKit Dungeon Pack (Kay Lousberg) e Medieval Village MegaKit (Quaternius).
- Efeitos sonoros: RPG Audio e Impact Sounds (Kenney).
- Trilha ambiente: Dark Cavern Ambient (Paul Wortmann).
