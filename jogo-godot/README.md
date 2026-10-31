# JOGO (Godot 4.3)

Carreira de futebol (estilo PES) + vida real em cidade aberta (estilo GTA). Tudo original, sem assets licenciados.
Abra a pasta no Godot 4.3+ e aperte F5 (`godot --path .`).

## Partida
WASD mover (relativo à câmera) · Shift correr · J passe (segure = lançamento) · K chute (segure = força) ·
sem bola: K carrinho, J desarme · Q/Tab trocar jogador · Esc encerra.
IA por função, goleiro com mergulho, faltas, cartões, escanteio, lateral, pênalti, impedimento simples, replay de gol, radar.

## Cidade
Trânsito com semáforos, pedestres, chuva/neblina, minimapa e GPS, missões, 7+ locais.
E interagir · F entrar/sair do carro · Esc menu. Casa → "Carreira, contrato e finanças".

## Movimento
A pé: aceleração e virada suaves. Carro: Espaço = freio; Espaço + virar em alta velocidade = derrapagem
(deslize lateral, carroceria inclina, rodas giram e esterçam).

## Procurado (polícia, sem violência)
Excesso de velocidade perto de viatura e batidas somam estrelas (até 5). Mais estrelas = mais viaturas, mais rápidas, que perseguem você.
Parado perto de uma viatura por ~2,5 s = abordagem (multa de $120 por estrela). Fora da vista por alguns segundos = estrelas caem.

## Carreira
12 ligas fictícias (8 clubes cada), campeonato + copa, elenco, contrato, propostas e transferências entre ligas,
patrocínios, investimentos, imprensa, lesões, Maya (namoro, moradia, casamento, filho), aposentadoria.

## Gráficos
Procedurais (scripts/props.gd, scripts/materials.gd, scripts/humanoid_builder.gd): pessoas, carros, prédios, céu, SSAO.
Não são modelos AAA. Para subir de nível, adicione modelos .glb de licença livre em assets/ e registre em assets/ATTRIBUTION.md.

## Dev
Ao criar script com `class_name`: `godot --headless --path . --import`.
Relatório de projetos abertos e licenças: ver research/ (se incluído).
