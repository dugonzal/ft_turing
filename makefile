NAME = ft_turing
BC = $(NAME).bc

OCAMLFIND = ocamlfind
PACKAGES = yojson

OPAM_EXEC = opam exec --
OCAMLC = ocamlc
OCAMLOPT = ocamlopt

# El compilador empareja un .ml con su .mli SOLO si estan en el mismo directorio:
# con el contrato en inc/ compila el modulo SIN contrato y sin avisar. De ahi
SRC = $(shell $(OPAM_EXEC) ocamldep -sort -I src -I inc src/*.ml)
OBJ = $(patsubst src/%.ml, obj/%.cmo, $(SRC))
OBJ_NATIVE = $(patsubst src/%.ml, obj/%.cmx, $(SRC))

OBJ_DIR = obj/

CMI = $(patsubst inc/%.mli,obj/%.cmi,$(wildcard inc/*.mli))

# `ocamldep -sort` de arriba da el ORDEN, no las dependencias: sin esto, tocar
# constant.ml no recompila print.cmo y el enlazado falla con "inconsistent
# assumptions over interface Constant". El mismo ocamldep SIN -sort emite reglas
# de make; se reescriben los src/ por obj/ y se incluyen.
ALL_SOURCES = $(wildcard src/*.ml) $(wildcard inc/*.mli)
DEPS_FILE = $(OBJ_DIR)ocamldep.mk

# make -j no sabe que un .cmo necesita el .cmi de otro: esto lo serializa.
.NOTPARALLEL:

.PHONY: all

all: $(NAME)

$(NAME): deps $(OBJ)
	$(OPAM_EXEC) $(OCAMLFIND) $(OCAMLC) $(DEBUG) -package $(PACKAGES) -linkpkg $(OBJ) -o $(NAME)
	@$(OPAM_EXEC) ocamlc -version > $(OBJ_DIR)/.ocaml-version 2>/dev/null || true

# La regla va DESPUES de `all` a proposito: la primera regla del fichero es el
# goal por defecto, y ese tiene que ser el ejecutable, no el fichero de deps.
$(DEPS_FILE): $(ALL_SOURCES)
	@mkdir -p $(@D)
	@$(OPAM_EXEC) ocamldep -I src -I inc $(wildcard src/*.ml) > $@.tmp 2>/dev/null \
	  && sed -i 's|src/|$(OBJ_DIR)|g' $@.tmp && mv $@.tmp $@ \
	  || { rm -f $@.tmp $@; echo "make: ocamldep no disponible aun: sin deps incrementales"; }

# Detecta si el compilador soporta -cmi-file (OCaml >= 5.0). En 4.14 no existe
# y hay que compilar sin el flag (el -I obj/ ya expone el .cmi).
CMI_FILE_SUPPORTED := $(shell $(OPAM_EXEC) ocamlc -help 2>&1 | grep -q "cmi-file" && echo yes || echo no)

obj/%.cmo: src/%.ml
	@mkdir -p $(@D)
	@if [ -f inc/$*.mli ]; then \
	  $(OPAM_EXEC) $(OCAMLFIND) $(OCAMLC) $(DEBUG) -package $(PACKAGES) -I $(OBJ_DIR) -c inc/$*.mli -o obj/$*.cmi && \
	  if [ "$(CMI_FILE_SUPPORTED)" = "yes" ]; then \
	    $(OPAM_EXEC) $(OCAMLFIND) $(OCAMLC) $(DEBUG) -package $(PACKAGES) -I $(OBJ_DIR) -cmi-file obj/$*.cmi -c $< -o $@; \
	  else \
	    $(OPAM_EXEC) $(OCAMLFIND) $(OCAMLC) $(DEBUG) -package $(PACKAGES) -I $(OBJ_DIR) -c $< -o $@; \
	  fi; \
	else \
	  $(OPAM_EXEC) $(OCAMLFIND) $(OCAMLC) $(DEBUG) -package $(PACKAGES) -I $(OBJ_DIR) -c $< -o $@; \
	fi

$(patsubst obj/%.cmi,obj/%.cmo,$(CMI)): obj/%.cmo: inc/%.mli

.PHONY: native
native: deps $(OBJ_NATIVE)
	$(OPAM_EXEC) $(OCAMLFIND) $(OCAMLOPT) -package $(PACKAGES) -linkpkg $(OBJ_NATIVE) -o $(NAME)

# El .cmi de un .mli lo produce la regla bytecode: sin compilarlo
obj/%.cmx: src/%.ml
	@mkdir -p $(@D)
	@if [ -f inc/$*.mli ]; then \
	  $(OPAM_EXEC) $(OCAMLFIND) $(OCAMLC) $(DEBUG) -package $(PACKAGES) -I $(OBJ_DIR) -c inc/$*.mli -o obj/$*.cmi && \
	  if [ "$(CMI_FILE_SUPPORTED)" = "yes" ]; then \
	    $(OPAM_EXEC) $(OCAMLFIND) $(OCAMLOPT) -package $(PACKAGES) -I $(OBJ_DIR) -cmi-file obj/$*.cmi -c $< -o $@; \
	  else \
	    $(OPAM_EXEC) $(OCAMLFIND) $(OCAMLOPT) -package $(PACKAGES) -I $(OBJ_DIR) -c $< -o $@; \
	  fi; \
	else \
	  $(OPAM_EXEC) $(OCAMLFIND) $(OCAMLOPT) -package $(PACKAGES) -I $(OBJ_DIR) -c $< -o $@; \
	fi

.PHONY: debug
debug: fclean
	$(MAKE) DEBUG=-g all
	$(OPAM_EXEC) $(OCAMLFIND) $(OCAMLC) -g -package $(PACKAGES) -linkpkg $(OBJ) -o $(BC)

.PHONY: deps
deps:
	@cur=$$($(OPAM_EXEC) ocamlc -version 2>/dev/null || echo none); \
	prev=$$(cat $(OBJ_DIR)/.ocaml-version 2>/dev/null || echo none); \
	if [ "$$cur" != "$$prev" ] && [ -d $(OBJ_DIR) ]; then \
	  echo "deps: OCaml $$prev -> $$cur: limpiando obj/ y binarios (stdlib ha cambiado)"; \
	  rm -rf $(OBJ_DIR) $(NAME) $(BC); \
	fi
	@if [ -d obj ] && ls obj/*.cm* >/dev/null 2>&1; then \
	  if ! $(OPAM_EXEC) ocamlobjinfo obj/*.cmo >/dev/null 2>&1; then \
	    echo "deps: obj/ con bytecode de otra version de OCaml -> limpiando obj/"; \
	    rm -rf obj; \
	  fi; \
	fi
	@if [ "$(MAKECMDGOALS)" = "native" ]; then \
		command -v ocamlopt >/dev/null 2>&1 || opam install ocaml --yes; \
	else \
		command -v ocamlc >/dev/null 2>&1 || opam install ocaml --yes; \
	fi
	@v=$$($(OPAM_EXEC) ocamlc -version | cut -d. -f1); \
	if [ "$$v" -lt 5 ]; then \
		if [ "$(CMI_FILE_SUPPORTED)" = "yes" ]; then \
		  echo "ocamlc $$v < 5.0 pero soporta -cmi-file: continuo"; \
		else \
		  echo "ocamlc $$v < 5.0 sin -cmi-file: compilo sin -cmi-file (via -I obj)"; \
		fi; \
	else \
		echo "deps: ocamlc $$v >= 5.0 ok"; \
	fi
	@$(OPAM_EXEC) ocamlfind query $(PACKAGES) >/dev/null 2>&1 || opam install $(OCAMLFIND) $(PACKAGES) --yes
	@$(OPAM_EXEC) ocamlfind query $(OCAMLFIND) >/dev/null 2>&1 || opam install $(OCAMLFIND) --yes

.PHONY: test
test: $(NAME)
	@./test/run.sh $(NAME)

.PHONY: clean
clean:
	$(RM) -r obj

.PHONY: fclean
fclean: clean
	$(RM) $(NAME) $(BC)

.PHONY: re
re: fclean
	$(MAKE) all

# Las dependencias van al FINAL: un -include antes de la primera regla cambiaria
# el goal por defecto de make (pasaria a ser el primer obj del fichero).
-include $(DEPS_FILE)
