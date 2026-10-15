# The Last Contract

Jogo de ação 3D em terceira pessoa feito em Godot 4.7 para a Avaliação Grau 2 de Programação de Jogos.

Uma vila medieval foi tomada por mortos-vivos. Um Lorde contrata um aventureiro para limpá-la e
derrotar o Necromante responsável pela infestação. Cada tentativa tem uma vida só: ao morrer,
reviva com uma bênção (que os mortos-vivos também recebem) ou desista e enfrente a execução.

**Autores:** André Bartzen Araujo, Jackson Matiazzi e José Maciel Camargo.

## Como jogar

| Ação | Teclado e mouse | Controle (layout Xbox) |
|---|---|---|
| Mover | W A S D | Analógico esquerdo |
| Correr | W duas vezes | Clicar no analógico esquerdo |
| Pular | Espaço | A |
| Câmera | Mouse | Analógico direito |
| Atacar | Botão esquerdo | RT |
| Habilidade (escudo do Knight, segundo machado do Barbarian) | Botão direito | LT |
| Interagir (abrir baú) | E | X |
| Pausar | Esc | Menu (Start) |

**Objetivo:** limpe os grupos de esqueletos espalhados pela vila (a HUD mostra quantos faltam).
Quando o último cair, o Necromante surge na praça. Derrote-o para cumprir o contrato.

## Como rodar

1. Abra o projeto no Godot 4.7 (Forward+).
2. Rode a cena principal (F5): menu → seleção de aventureiro → entrada na missão → vila.

## Builds

Os builds saem pelo GitHub Actions, na aba Actions do repositório:

- **Build Linux**: exporta o jogo para Linux a cada push no `main`, em cada tag `entrega-*` ou manualmente. O `.tar.gz` fica nos artefatos da execução.
- **GDD**: compila `docs/gdd.tex` sempre que algo em `docs/` muda. O PDF fica nos artefatos da execução.

Para exportar localmente pelo editor: Projeto > Exportar, preset "Linux" ou "Windows Desktop".

## Testes

Os testes automatizados usam o [gdUnit4](https://github.com/MikeSchulze/gdUnit4) (incluído em `addons/`).
No editor, rode pela aba gdUnit. No GitHub, eles rodam sozinhos a cada push e pull request.

## Estrutura

| Pasta | Conteúdo |
|---|---|
| `scenes/` | Cenas (`.tscn`): personagens, mapas em GridMap, cutscenes, interface, objetos |
| `scripts/` | Scripts (`.gd`), espelhando `scenes/` |
| `resources/` | Recursos: aventureiros, bênçãos, perfis de inimigo, sons, bibliotecas de peças, navmesh |
| `assets/` | Modelos 3D e áudio de terceiros (CC0) |
| `tests/` | Testes gdUnit4 |
| `docs/` | GDD em LaTeX (`docs/gdd.tex`; o PDF sai pelo GitHub Actions) |

## Créditos dos recursos (todos CC0)

- Modelos: [KayKit Adventurers](https://kaylousberg.itch.io/kaykit-adventurers), [KayKit Skeletons](https://kaylousberg.itch.io/kaykit-skeletons) e [KayKit Dungeon Pack](https://kaylousberg.itch.io/kaykit-dungeon-pack) (Kay Lousberg); [Medieval Village MegaKit](https://quaternius.itch.io/medieval-village-megakit) (Quaternius).
- Efeitos sonoros: [RPG Audio](https://kenney.nl/assets/rpg-audio), [Impact Sounds](https://kenney.nl/assets/impact-sounds) e [Interface Sounds](https://kenney.nl/assets/interface-sounds) (Kenney).
- Música: [Dark Cavern Ambient](https://opengameart.org/content/dark-cavern-ambient) (Paul Wortmann) e [Medieval fair [Loop]](https://opengameart.org/content/medieval-fair-loop) (Woli34).
