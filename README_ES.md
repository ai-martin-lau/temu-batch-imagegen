<p align="center">
  <a href="README.md">简体中文</a> · <a href="README_EN.md">English</a> · <a href="README_JA.md">日本語</a> · <a href="README_KO.md">한국어</a> · <a href="README_ES.md">Español</a>
</p>

# Generador por lotes de imágenes de producto para TEMU

Coloca un lote de entradas de producto en `input/` —cada producto puede ser **una sola imagen** o **una carpeta (varias fotos de referencia del mismo producto)— y esta herramienta genera N imágenes principales / sets de imágenes de e-commerce para cada uno, siguiendo su prompt creativo correspondiente, usando el **`image_gen` integrado de codex** (funciona con tu suscripción de codex, **sin API key**). Los resultados van a `output/`.

Ideal para: convertir un lote de fotos reales de producto en imágenes principales + sets para TEMU / e-commerce transfronterizo / tiendas online, cada una en el estilo que indiques.

---

## 1. Requisitos (una sola vez)

Solo necesitas el **CLI de codex, con sesión iniciada** (basta una suscripción de codex):

```bash
codex --version      # debe imprimir una versión
codex login          # inicia sesión si aún no lo hiciste
```

Sin Python, sin `OPENAI_API_KEY`, sin nada más que instalar.

---

## 2. Instalar en codex

Coloca toda la carpeta `temu-batch-imagegen/` en el directorio de skills de codex:

```bash
cp -R temu-batch-imagegen ~/.codex/skills/
```

> También puedes omitir el directorio de skills y simplemente hacer `cd` a esta carpeta para usarla (ver "Opción B").

---

## 3. Cómo usar

> Convención clave: **se procesa cada unidad en `input/` (imágenes sueltas + carpetas de imágenes). Nunca se te pregunta "cuál / qué prompt / cuántas"** —— las tres ya están predeterminadas (procesar todo, emparejar prompts por nombre, la cantidad sale del texto del prompt).

### Lo más fácil: doble clic en `批量出图.command` (para usuarios no técnicos)
Pon imágenes en `input/` y haz **doble clic en `批量出图.command`** —— abre una terminal, ejecuta el lote y abre la carpeta `output/` al terminar.
- Si `input/` está vacío, muestra un mensaje amable y abre la carpeta input; si codex no está instalado / sin sesión, da un error claro.
- En el primer doble clic, si macOS lo bloquea, haz **clic derecho → Abrir** una vez para confirmar.
- El requisito es el mismo: **codex instalado + con sesión iniciada**.

### Opción A: un solo comando (recomendado, usuarios de terminal)
1. Pon tus **entradas** en `input/`. Se pueden mezclar dos formas:
   - **Una sola imagen** (`dress.png`) = un producto, una foto de referencia;
   - **Una carpeta** (`jeans/`, con varias fotos del mismo producto) = el **set de imágenes** de un producto; todas las fotos dentro se pasan a la misma sesión como referencias multiángulo.
2. Prepara los prompts (`prompt/*.txt`, requisitos en lenguaje natural): el genérico se llama `默认.txt` ("predeterminado"); para personalizar un producto, crea un `.txt` **con el mismo nombre que la imagen o la carpeta**.
3. Ejecuta, dentro de esta carpeta:

```bash
bash batch.sh            # hasta 3 procesos en paralelo por defecto
MAX=5 bash batch.sh      # sube la concurrencia para ir más rápido (cuidado con los límites de codex)
```

- **Una imagen, un proceso**: cada imagen tiene su propia sesión de codex independiente, sin interferencias; 3 en paralelo por defecto, y **los fallos hacen fallback automático a reintento en serie**.
- **Emparejado automático de prompts**: cada unidad busca `prompt/<nombre>.txt` por su **nombre** (de imagen / carpeta); si no hay archivo con el mismo nombre usa `prompt/默认.txt`; si `prompt/` tiene un solo `.txt`, todas las unidades lo usan.
- **La cantidad de imágenes se escribe en el prompt** (p. ej. "salida 6 × 3:4 + 1 × 1000×1000"); para cambiar la cantidad, edita el texto del prompt —— el comando no cambia.
- Los resultados van a `output/batch-<timestamp>/<nombre-imagen>/01.png 02.png …`, los logs a `.logs/` de esa carpeta; el script ejecuta una autocomprobación de tamaño al final.

### Opción B: deja que codex lo ejecute (autónomo, sin preguntas)
Con las imágenes en `input/` y los prompts listos, inicia codex en esta carpeta y dile:
> Usa la skill temu-batch-imagegen para generar mis imágenes

codex **procesará cada unidad en `input/`** (imágenes sueltas + carpetas, sin preguntas), generando y escribiendo en `output/batch-<timestamp>/<nombre-unidad>/` con las mismas reglas.

> Un solo producto ejecuta igual `bash batch.sh` —— el script procesa solo ese, sin comando especial.

---

## 4. Estructura

```
temu-batch-imagegen/
├── README.md           # chino simplificado (predeterminado)
├── README_ES.md        # este archivo
├── SKILL.md            # flujo de ejecución de codex (codex lo lee)
├── 批量出图.command     # lanzador de doble clic (macOS, usuarios no técnicos)
├── batch.sh            # generador por lotes: una sesión por imagen, 3 en paralelo + fallback en serie
├── input/              # pon aquí [imágenes sueltas] o [carpetas de imágenes] (.png/.jpg/.webp, mezclables)
│   ├── dress.png       #   imagen suelta = un producto
│   └── jeans/          #   carpeta = set de imágenes de un producto (referencias multiángulo)
├── prompt/             # plantillas de prompt creativo (.txt; emparejadas por nombre, la genérica = 默认.txt)
│   └── 默认.txt
├── output/             # resultados: batch-<timestamp>/<nombre-unidad>/01.png 02.png …
└── example/            # muestra ejecutable (misma estructura que un proyecto real: input + prompt)
    ├── input/product.png
    └── prompt/默认.txt
```

---

## 5. Consejos para escribir prompts

- **Escribe en lenguaje natural**, como un brief —— detalla "producto / estilo / requisitos" (ver `prompt/默认.txt`, que es un brief real).
- ¿Quieres texto en otro idioma sobre la imagen (p. ej. argumentos de venta en japonés)? Simplemente dilo en el prompt, p. ej. "texto en japonés natural y refinado".
- **Indica cada requisito explícitamente**: lo que quieras —— tamaño, fidelidad de color, estilo, con o sin rostros, fondo, cómo tratar los logotipos de marca —— defínelo según tu producto y plataforma. La herramienta solo sigue el prompt y **no asume ninguna restricción por ti**.
- Para un set de N imágenes que sean **cada una distinta**, dilo en el prompt: "genera cada una de forma independiente, varía cada una (pose/escena/etc.)" para evitar "la misma imagen con texto distinto".

## 6. Notas

- **El texto en otro idioma sobre la imagen puede tener erratas**: los modelos de imagen a veces escriben mal el texto en otros idiomas. Revisa cada resultado; para los que no te gusten, pide a codex que **regenere solo ese**. Para texto que deba ser 100% exacto, genera primero imágenes limpias y superpón la copia con precisión después usando otra herramienta.
- Los archivos intermedios quedan en el directorio por defecto de codex `~/.codex/generated_images/`; los resultados finales están en `output/` de este proyecto.

---

*La generación usa el `image_gen` integrado de codex (tu suscripción), así que no hay API key que gestionar. Este repositorio es la versión para macOS.*
