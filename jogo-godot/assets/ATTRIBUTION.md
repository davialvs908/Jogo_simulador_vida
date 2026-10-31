# Atribuicoes e licencas dos assets

## Conteudo 100% original (sem licenca externa)
Todo o visual em tempo de execucao e gerado em codigo, sem arquivos de terceiros:
- `scripts/humanoid_builder.gd` (jogadores/NPCs), `scripts/props.gd` (carros, predios, arvores, bancos, postes),
  `scripts/materials.gd` (texturas procedurais por ruido, materiais PBR, Environment/ceu).
- Texturas (asfalto, calcada, concreto, grama, casca, folhas, madeira, fachadas, trama de tecido) sao
  geradas na inicializacao via FastNoiseLite/Image — nenhum arquivo de imagem baixado.

## Modelos de amostra (somente referencia, nao usados pelo jogo em runtime)
| Arquivo | Fonte | Licenca |
|---|---|---|
| `characters/CesiumMan.glb`, `characters/CesiumMan_0.jpg` | KhronosGroup/glTF-Sample-Assets | CC-BY 4.0, (c) 2017 Cesium — https://creativecommons.org/licenses/by/4.0/ (atribuicao obrigatoria) |
| `characters/RiggedFigure.glb` | KhronosGroup/glTF-Sample-Assets | CC-BY 4.0, (c) 2017 Cesium — atribuicao obrigatoria |

## Avaliados e NAO incluidos
- KenneyNL/Starter-Kit-City-Builder (https://github.com/KenneyNL/Starter-Kit-City-Builder): alcancavel, modelos
  declarados CC0, mas estilo low-poly "brinquedo" destoa da meta realista e nao ha carros/pessoas. Nada baixado.
- Quaternius / repositorios Kenney maiores / texturas PBR (ambientCG, Poly Haven): hosts nao alcancaveis
  (API do GitHub restrita; codeload bloqueado).
