extends Node
## Señales globales desacopladas. Nadie guarda estado aquí.

## Se ha activado una bandera de historia o de evento.
signal flag_set(flag: StringName)
## Objeto recibido en la custodia (para avisos en pantalla).
signal item_received(item: ItemDef, amount: int)
## Documento nuevo en el expediente.
signal document_received(doc: DocumentDef)
## Texto breve en pantalla, sin caja (p. ej. "No cabe en la bandeja").
signal notice(text: String)
signal flashlight_toggled(on: bool)
## Carga de la linterna entre 0 y 1.
signal flashlight_charge_changed(ratio: float)
## Se ha usado un objeto desde la custodia o un bolsillo (vendas, pilas, pastillas…).
signal item_used(item: ItemDef)
## Se ha dejado un objeto en el suelo desde la custodia (el mundo lo coloca a los pies del jugador).
signal item_discarded(stack: ItemStack)
## Corriente del hospital restablecida o cortada.
signal power_changed(on: bool)
## Se ha guardado o cargado la partida.
signal game_saved
signal game_loaded
