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

Usamos o gdUnit4 (em `addons/`). Os testes ficam em `tests/` e rodam pela aba gdUnit do editor.

No GitHub Actions, a cada push e pull request:

- **Testes** (`test`): roda toda a suíte do gdUnit4.
- **Smoke** (`smoke`): abre a cena principal sem tela por 300 quadros e falha se aparecer qualquer erro no log.
- **Documento**: compila `docs/projeto.tex` quando algo em `docs/` muda.

Antes de uma entrega, o pull request para o `main` também roda o **Build Linux**, que confere se o jogo exporta.
O Dependabot abre um pull request por semana na `desenvolvimento` quando alguma action do CI tem versão nova.

### Release de cada entrega

Todo merge no `main` gera a release sozinho: o workflow **Release da entrega** cria a tag
`entrega-AAAA-MM-DD` (data de Brasília), exporta o jogo para Linux, compila o documento e publica os dois na
página de Releases. Um segundo merge no mesmo dia move a tag e atualiza a mesma release.

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

## Créditos

Todos os recursos de terceiros são CC0.

- Modelos: KayKit Adventurers, KayKit Skeletons e KayKit Dungeon Pack (Kay Lousberg) e Medieval Village MegaKit (Quaternius).
- Efeitos sonoros: RPG Audio e Impact Sounds (Kenney).
- Trilha ambiente: Dark Cavern Ambient (Paul Wortmann).
