extends SceneTree
## Genera los documentos del prólogo en data/documents/ (textos [PROPUESTA], ver docs/lore/prologo.md).
## Uso: "$GODOT_BIN" --headless --path . -s tools/data/build_documents.gd

const DIR: String = "res://data/documents/"
const IMAGES: String = "res://assets/documents/"

const T: DocumentDef.Style = DocumentDef.Style.TYPED
const H: DocumentDef.Style = DocumentDef.Style.HANDWRITTEN
const F: DocumentDef.Style = DocumentDef.Style.FORM
const P: DocumentDef.Style = DocumentDef.Style.PHOTO


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var n: int = 0
	for d: Array in _docs():
		var doc: DocumentDef = DocumentDef.new()
		doc.id = StringName(d[0])
		doc.title = d[1]
		doc.kind = d[2]
		doc.style = d[3]
		doc.date_text = d[4]
		doc.body = d[5]
		doc.stamp = d[6] if d.size() > 6 else ""
		var image: String = IMAGES + d[0] + ".png"
		if ResourceLoader.exists(image):
			doc.image = load(image)
		ResourceSaver.save(doc, DIR + d[0] + ".tres")
		n += 1
	print("Documentos: %d" % n)
	quit()


func _docs() -> Array:
	var K: Dictionary = {
		"note": DocumentDef.Kind.NOTE, "record": DocumentDef.Kind.RECORD, "report": DocumentDef.Kind.REPORT,
		"photo": DocumentDef.Kind.PHOTO, "map": DocumentDef.Kind.MAP, "label": DocumentDef.Kind.LABEL,
	}
	return [
		["pulsera_09", "Pulsera de paciente", K.label, F, "",
			"HOSPITAL CLÍNICO SAN LÁZARO · PLANTA 3\n\nPACIENTE: [b]09[/b]\nNOMBRE: ███████████\nUNIDAD: VIGILIA\nCICLO: [b]IX[/b]\nALERGIAS: —\n\n[b]NO DESPERTAR SIN AUTORIZACIÓN DE DIRECCIÓN[/b]\n\nEl plástico está gastado por dentro, como si la hubieras llevado muchos años.",
			"IX"],
		["hoja_constantes", "Hoja de constantes · Hab. 09", K.record, F, "Ciclo IX",
			"Día 3.208 — TA 90/60 · FC 41 · Tª 35,1 · Sin sueño REM. Sin cambios.\nDía 3.209 — TA 90/60 · FC 40 · Sin sueño REM. Sin cambios.\nDía 3.210 — TA 88/58 · FC 40 · Sin sueño REM. Sin cambios.\nDía 3.211 — Sin cambios. [s]El paciente habla en vigilia.[/s]\nDía 3.212 — [b]ACTIVIDAD.[/b] Avisar a dirección. No entrar.\n\nLa última línea está escrita con otra letra, muy deprisa."],
		["nota_enfermera", "Nota para el turno de noche", K.note, H, "",
			"A quien haga la noche:\n\nNo dejes que el de la 09 se despierte solo. Si abre los ojos, llama a planta 0 y sal de la habitación.\nSi te habla, no le contestes.\nSi te pregunta qué día es, NO SE LO DIGAS.\n\nYa sé que da pena. A todos nos la dio la primera vez.\n\n— M."],
		["parte_turno", "Parte de incidencias · Turno de noche", K.report, T, "Sin fecha",
			"02:14  Ruidos en la 11 (vacía desde marzo). Se comprueba: nada.\n02:40  La cama de la 08 aparece separada de la pared. Nadie la ha movido.\n02:58  El monitor de la 09 marca actividad. Aviso a dirección.\n03:05  Dirección ordena desalojar la planta 3, salvo la 09.\n03:06  ¿Desalojar a quién? Aquí ya no queda nadie.\n03:07  [s]Me quedo.[/s]\n03:31  Se oyen pasos en el pasillo. Llevo veinte minutos sin moverme del control.\n\nEl resto del parte está en blanco."],
		["carta_sin_enviar", "Carta sin enviar", K.note, H, "",
			"Querida Elena:\n\nNo duermo desde el Desvelo. Aquí dicen que eso es bueno, que estoy en vigilia, que así es como se cura. Me ponen suero y me miran.\n\nPor las noches alguien camina descalzo por el pasillo. Las enfermeras dicen que es el de la nueve, pero el de la nueve no se levanta nunca.\n\nSi vienes a verme, no traigas flores. Aquí todo lo que está vivo dura poco.\n\nTu padre."],
		["foto_personal", "Fotografía del personal", K.photo, P, "",
			"Foto de grupo frente a la entrada del hospital. Catorce personas con bata. Alguien ha rayado una de las caras hasta romper el papel.\n\nAl dorso, a lápiz: [i]«Inauguración de la Unidad de Vigilia. Antes de todo.»[/i]"],
		["diario_paciente", "Diario de la habitación 10", K.note, H, "",
			"Día 412 sin dormir. Ya no cuento las horas, cuento las veces que pasan con la camilla.\n\nHoy han sacado a la 09 otra vez. Lo llevan abajo y lo vuelven a subir. Es la octava vez. Siempre vuelve con los puntos más arriba en la espalda.\n\nLa enfermera mayor dice que cuando llegue a nueve se acabará. No ha dicho qué."],
		["receta_09", "Pauta de tratamiento · Paciente 09", K.record, F, "",
			"PACIENTE: 09     UNIDAD: VIGILIA     CICLO: IX\n\nSEDACIÓN: [b]NINGUNA[/b]. Repito: NINGUNA.\nMantener en vigilia. Suero glucosado. Contención si fuera necesario.\nNo administrar analgesia antes de la recuperación: altera el material.\n\nFirma: Dr. ████████ (Dirección)",
			"VIGILIA IX"],
		["inventario_enfermeria", "Inventario de enfermería", K.report, T, "",
			"Vendas estériles ........ 12  (quedan 2)\nClorhexidina ............. 6   (queda 1)\nSedantes (restringido) ... 30  (FALTAN 29)\nCorreas de sujeción ...... 40  (quedan 0)\nBolsas para cadáveres .... 20  (quedan 20)\n\nNota: las bolsas no se han usado. No ha muerto nadie en planta desde el Desvelo. Eso no es una buena noticia."],
		["informe_quirurgico", "Informe quirúrgico", K.report, T, "Ciclo VIII",
			"PROCEDIMIENTO: Recolocación de puerto dorsal (T4-T5).\nANESTESIA: ninguna, según protocolo de vigilia.\n\nEl paciente permanece consciente durante toda la intervención. No grita. Pregunta dos veces qué hora es. No se le responde.\n\nSe recupera material: 3 ml. Aspecto: [s]luminoso[/s] [i]no procede describirlo[/i].\nSe cierra con sutura continua. Próxima recuperación: ciclo IX.\n\nObservación del cirujano: «Cada vez trae menos. O cada vez trae otra cosa.»"],
		["consentimiento", "Consentimiento informado", K.record, F, "",
			"Yo, ████████████, paciente de la Unidad de Vigilia, acepto someterme al procedimiento de recuperación y a sus repeticiones.\n\nFirma del paciente: ______________ (en blanco)\nFirma del tutor legal: [b]Dirección del Hospital Clínico San Lázaro[/b]\n\nEl papel tiene la marca de una mano que lo sujetó con fuerza.",
			"SIN FIRMA"],
		["registro_admisiones", "Libro de admisiones", K.record, T, "",
			"HAB. 09 — Ingreso ··· 14 de marzo [i](antes del Desvelo)[/i]\nHAB. 09 — Reingreso · ciclo II\nHAB. 09 — Reingreso · ciclo III\nHAB. 09 — Reingreso · ciclo IV\nHAB. 09 — Reingreso · ciclo V\nHAB. 09 — Reingreso · ciclo VI\nHAB. 09 — Reingreso · ciclo VII\nHAB. 09 — Reingreso · ciclo VIII\nHAB. 09 — Reingreso · ciclo IX\n\nNinguna alta. Todos los reingresos con el mismo nombre, tachado."],
		["plano_hospital", "Plano de evacuación · Planta 3", K.map, P, "",
			"Plano de evacuación pegado junto a recepción. «Usted está aquí», con una flecha.\n\nEl pasillo del ala de pacientes termina en el muro oeste, junto a la habitación 07. Al otro lado del muro no hay nada: es la fachada."],
		["expediente_09", "Expediente clínico · Habitación 09", K.record, T, "14 de marzo — antes del Desvelo",
			"INGRESO: 14 de marzo. [b]Antes del Desvelo.[/b]\nMOTIVO: [s]████████████████████[/s]\nDIAGNÓSTICO: Ninguno. Paciente sano.\n\nOBSERVACIONES DE INGRESO:\n«El paciente pidió que no lo despertáramos. Dijo que, si lo hacíamos, tendríamos que hacerlo nueve veces.»\n\nEVOLUCIÓN: Vigilia I · II · III · IV · V · VI · VII · VIII · IX\n\nDESTINO TRAS LA NOVENA VIGILIA: [b]Protocolo de recuperación.[/b]\nRESPONSABLE: Dirección.",
			"NO ARCHIVAR"],
		["expediente_11", "Expediente · Habitación 11", K.record, T, "Marzo",
			"PACIENTE: ████████\nESTADO: Fallecido en marzo. Cama vacía desde entonces.\n\nOBSERVACIONES POSTERIORES (otra letra):\n«La cama sigue caliente por las mañanas.»\n«Las sábanas aparecen revueltas.»\n«Hoy había una llave encima del colchón. No es de nadie.»"],
		["circular_9", "Circular interna nº 9", K.report, T, "Dirección",
			"ASUNTO: Protocolo de recuperación.\n\nCuando un paciente en vigilia recupere la consciencia por sí mismo, el personal abandonará la planta de inmediato y sin hablar con él.\n\nNo intenten contenerlo. No intenten ayudarle a salir.\n\n[b]El edificio se encarga.[/b]",
			"CONFIDENCIAL"],
		["diario_celador", "Libreta del celador", K.note, H, "",
			"Lo he medido dos veces con la cinta. El pasillo del ala de pacientes mide once metros más por dentro que por fuera.\n\nLos planos dicen que al oeste está la fachada. Yo he tocado la fachada desde la calle. Y sin embargo, cuando cortan la luz, se oye a alguien andar al otro lado del muro.\n\nDirección dice que no lo apunte. Lo apunto."],
		["etiqueta_morgue", "Etiqueta de identificación", K.label, F, "",
			"MORGUE · SAN LÁZARO\n\nN.º: [b]09[/b]\nFECHA: ██ de ███████\nCAUSA: [i]Fin de la vigilia.[/i]\nRECLAMADO POR: —\n\nEl cordel está cortado. Lo que llevaba la etiqueta ya no está en el cajón.",
			"09"],
		["manual_generador", "Instrucciones del generador de emergencia", K.report, T, "",
			"ARRANQUE MANUAL DEL GRUPO ELECTRÓGENO\n\n1. Comprobar el cuadro general (sala eléctrica). El fusible F1 debe estar colocado y las bornas apretadas.\n2. Comprobar la válvula de presión del generador. Sin válvula, el motor no arranca.\n3. Accionar la palanca de arranque y esperar a que se estabilice.\n\nEn caso de corte total, la megafonía se reactiva sola."],
		["nota_panel", "Nota en el cuadro eléctrico", K.note, H, "",
			"F1 fundido. Hay repuestos en el archivo de la 3.ª (caja de mantenimiento, estantería del fondo).\n\nLas bornas del cuadro están sueltas: hace falta un destornillador.\n\nY que nadie arranque el grupo sin avisar a dirección. Cuando vuelve la luz, vuelve todo."],
		["nota_lavanderia", "Etiqueta de un saco de ropa", K.note, H, "",
			"Sábanas de la 09: lavar aparte.\nNo mirar las manchas.\nNo preguntar por qué brillan."],
	]
