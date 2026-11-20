# Lista de arte (personajes y vehículos)

> **Estado:** el arte de los 16 personajes y 6 vehículos ya existe (hoja `assets/art/roster_source.png`, recortada con
> `tools/crop_roster_art.gd` a `assets/art/characters|vehicles/<id>.png`) y las pistas salen de `assets/art/tracks_source.webp`
> (`tools/crop_track_art.gd`). Esta lista sirve para regenerar o ampliar el arte: cualquier PNG con ese nombre sustituye al actual.

Estilo de referencia: **la portada** (`TurboBros.jpg`): ilustración 2D tipo cómic/anime con contorno marcado y sombreado
tipo cel, personajes chibi-realistas con armaduras oxidadas y con púas, karts destartalados de chatarra con tubos,
metal desgastado y neones de peligro, paleta sucia y cálida (marrones, óxido, azul acero) con acentos brillantes
(naranja, amarillo, cian). Cada personaje va montado en su kart.

**Entrega sugerida** (el juego usa estos archivos si existen y, si no, muestra el modelo 3D):
- Personajes: `assets/art/characters/<id>.png`, 768×1024, fondo transparente, medio cuerpo / cuerpo entero, mirando 3/4 a la derecha.
- Vehículos: `assets/art/vehicles/<id>.png`, 1024×640, fondo transparente, vista 3/4 delantera, sin conductor.
- (Opcional) personaje + vehículo juntos: `assets/art/karts/<vehiculo>_<personaje>.png` — no hace falta; el juego los combina.

Prompt base para cualquier imagen: *"2D game character illustration, bold black outlines, cel shading, post-apocalyptic
junkyard kart racing style, rusty metal, spikes, hazard stripes, vibrant accent lighting, transparent background, same style as the TurboBros cover"*.

---

## Personajes (16)

### DranCr  (`drancr`)
- **Descripción en el juego:** El marrón de la armadura de púas: especialista en velocidad, nadie le gana en la recta, aunque arranca y gira con pereza.
- **Color principal:** #402414
- **Género:** masculino
  - extras: ["spikes", "pads"]
  - eye: #261A0D
  - hair: #331F14
  - head: "spiked_helmet"
  - outfit: #52331F
  - outfit2: #8C4C24
  - skin: #D9A680
  - species: "human"
  - weapon: "minigun"
- **Pareja (artillero por defecto):** clarstar

### Agnelopolus  (`agnelopolus`)
- **Descripción en el juego:** El rojo de casco integral y barba: especialista en aceleración, sale disparado de cada curva.
- **Color principal:** #E61A1A
- **Género:** masculino
  - extras: ["beard", "pads"]
  - eye: #1A1A1A
  - hair: #59331A
  - head: "full_helmet"
  - outfit: #BF1F1A
  - outfit2: #660D0D
  - skin: #D9A680
  - species: "human"
  - weapon: "cannon"
- **Pareja (artillero por defecto):** polewar

### Brasa  (`brasa`)
- **Descripción en el juego:** Dragona de cuernos, cola y alas pequeñas: arranca como una llamarada y pega fuerte.
- **Color principal:** #F26626
- **Género:** femenino
  - extras: ["horns", "tail", "wings"]
  - outfit: #BF401A
  - outfit2: #401F1A
  - skin: #E65926
  - species: "dragon"
  - weapon: "claws"

### ClarStar  (`clarstar`)
- **Descripción en el juego:** La de las coletas rosas que va con DranCr: reina del derrape, carga los mini turbos al instante.
- **Color principal:** #FF80BF
- **Género:** femenino
  - extras: ["flowers"]
  - eye: #9933CC
  - hair: #FF99CC
  - head: "twintails"
  - outfit: #FF8CBF
  - outfit2: #FFD9EB
  - skin: #FAD1C2
  - species: "human"
  - weapon: "cannon"
- **Pareja (artillero por defecto):** drancr

### EnD  (`end`)
- **Descripción en el juego:** El de la armadura azul y el rifle de rayos, el que va con FerChaos: el tanque del grupo, pesado, resistente y de golpe durísimo.
- **Color principal:** #2659F2
- **Género:** masculino
  - extras: ["pads"]
  - eye: #1A1A26
  - hair: #261A1A
  - head: "visor_helmet"
  - outfit: #264CB2
  - outfit2: #1A2666
  - skin: #CC9E80
  - species: "human"
  - weapon: "beam"
- **Pareja (artillero por defecto):** ferchaos

### FerChaos  (`ferchaos`)
- **Descripción en el juego:** La amarilla de casco dorado y trenzas: caos con ruedas, se maneja bien fuera del asfalto y usa los ítems a la velocidad del rayo.
- **Color principal:** #FFD91A
- **Género:** femenino
  - extras: ["pads"]
  - eye: #3380E6
  - hair: #FFE680
  - head: "braids"
  - outfit: #F2C733
  - outfit2: #BF8C1A
  - skin: #FADBB8
  - species: "human"
  - weapon: "blaster"
- **Pareja (artillero por defecto):** end

### Fungo  (`fungo`)
- **Descripción en el juego:** Hongo con sombrero de lunares: reparte los ítems con calma y se siente en casa en el barro.
- **Color principal:** #CC408C
- **Género:** otro/sin género
  - eye: #1A1A1A
  - outfit: #CC3380
  - outfit2: #995933
  - scale: 0.95
  - skin: #F2E0BF
  - species: "mushroom"
  - weapon: "staff"

### Gloop  (`gloop`)
- **Descripción en el juego:** Slime verde y blandengue: se pega a cualquier terreno y rebota con gracia.
- **Color principal:** #80E64C
- **Género:** otro/sin género
  - eye: #0D1A0D
  - skin: #8CE64C
  - species: "slime"
  - weapon: "blaster"

### Grunk  (`grunk`)
- **Descripción en el juego:** Ogro verde de colmillos y garrote. Casi nadie lo mueve y casi nadie lo gira.
- **Color principal:** #59A640
- **Género:** masculino
  - extras: ["tusks"]
  - eye: #E6331A
  - outfit: #734C2E
  - outfit2: #4C331A
  - scale: 1.15
  - skin: #669E4C
  - species: "ogre"
  - weapon: "club"

### Huesos  (`huesos`)
- **Descripción en el juego:** Esqueleto pirata ligerísimo: corre como el viento aunque cualquier golpe lo desarma.
- **Color principal:** #EBE6CC
- **Género:** masculino
  - head: "pirate"
  - outfit: #B21A26
  - outfit2: #800D1A
  - skin: #EDE8D1
  - species: "skeleton"
  - weapon: "blaster"

### Kraki  (`kraki`)
- **Descripción en el juego:** Kraken azul de tentáculos: se escurre por las curvas y los derrapes largos.
- **Color principal:** #3373BF
- **Género:** femenino
  - extras: ["tentacles"]
  - eye: #0D0D1A
  - outfit: #264C99
  - outfit2: #E6E699
  - skin: #4080D9
  - species: "kraken"
  - weapon: "blaster"

### Ojón  (`ojon`)
- **Descripción en el juego:** Cíclope morado de un solo ojo y un cuerno: tranquilo, pesado y a gusto fuera del asfalto.
- **Color principal:** #8C4CB2
- **Género:** masculino
  - extras: ["single_horn"]
  - eye: #E6991A
  - outfit: #4C4073
  - outfit2: #E6D9B2
  - scale: 1.05
  - skin: #8C59B2
  - species: "cyclops"
  - weapon: "cannon"

### PoleWar  (`polewar`)
- **Descripción en el juego:** La de pelo morado y ametralladora giratoria, la que va con Agnelopolus: su golpe lanza a cualquiera a la cuneta.
- **Color principal:** #8C33CC
- **Género:** femenino
  - extras: []
  - eye: #8033B2
  - hair: #8C4CD9
  - head: "ponytail"
  - outfit: #8040BF
  - outfit2: #4C1F80
  - skin: #F2CCBF
  - species: "human"
  - weapon: "gatling"
- **Pareja (artillero por defecto):** agnelopolus

### Tornillo  (`tornillo`)
- **Descripción en el juego:** Robot de chatarra con visor verde: fiable y equilibrado, sin sorpresas.
- **Color principal:** #D98033
- **Género:** otro/sin género
  - outfit: #D98033
  - outfit2: #595C66
  - skin: #66FF99
  - species: "robot"
  - weapon: "minigun"

### Xyla  (`xyla`)
- **Descripción en el juego:** Insectoide de cuatro ojos y antenas: ágil de reflejos, derrapa como nadie.
- **Color principal:** #1AB299
- **Género:** femenino
  - extras: ["antennae", "mandibles", "extra_arms"]
  - eye: #1A1A1A
  - outfit: #266673
  - outfit2: #E6CC33
  - skin: #1A998C
  - species: "insect"
  - weapon: "blaster"

### Zorp  (`zorp`)
- **Descripción en el juego:** Alienígena gris de ojos enormes: manos rapidísimas con los ítems, poco peso y poco aguante.
- **Color principal:** #BFCCD9
- **Género:** femenino
  - outfit: #8099BF
  - outfit2: #4C5980
  - scale: 0.9
  - skin: #B8C7CC
  - species: "grey"
  - weapon: "blaster"

## Vehículos (6)

### Azulón  (`azulon`)
- **Descripción en el juego:** El equilibrado de la parrilla: sin puntos débiles.
- **Color de carrocería:** #3366D9
- **Estilo:** 

### Chatarrero  (`chatarrero`)
- **Descripción en el juego:** Pesado y blindado con chatarra, con púas y escapes. Aguanta los choques, le cuesta arrancar y girar.
- **Color de carrocería:** #73472E
- **Estilo:** scrap

### Cohete  (`cohete`)
- **Descripción en el juego:** Un cohete con ruedas: velocidad punta altísima; acelera y gira con pereza.
- **Color de carrocería:** #D93326
- **Estilo:** rocket

### Escorpión  (`escorpion`)
- **Descripción en el juego:** Con cola y pinzas: hecho para derrapar, carga los mini turbos enseguida.
- **Color de carrocería:** #8C33B2
- **Estilo:** scorpion

### Relámpago  (`relampago`)
- **Descripción en el juego:** Ligero y veloz, con aleta trasera. Se asusta fuera del asfalto y en los choques.
- **Color de carrocería:** #F2C726
- **Estilo:** sleek

### Tanque  (`tanque`)
- **Descripción en el juego:** Camión todoterreno de ruedas enormes: lento pero se come los baches.
- **Color de carrocería:** #4C6B40
- **Estilo:** truck

## Pistas
Los mapas de selección ya salen de tu imagen de 10 pistas (`assets/art/tracks/`), no hay que generarlos.
