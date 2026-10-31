# JOGO — notas para Claude / colaboradores
Godot 4.3, GDScript. Carreira de futebol + cidade aberta. Tudo original.
Autoloads: GameState (scripts/game_state.gd, save em user://jogo_save.json), CaptureService (dev).
Partida: match.gd + match_*.gd. Cidade: hub.gd + city_*.gd (estado extra em user://cidade.json).
Carreira: game_state.gd + career_*.gd + leagues.gd (12 ligas). Gráficos: props.gd, materials.gd, humanoid_builder.gd.
Novos arquivos: preferir preload (sem class_name). Testes headless: godot --headless --path . res://scenes/X.tscn --quit-after N
(ignore o ruído "mesh_get_surface_count" do modo headless).
Controles: ver README.md.
